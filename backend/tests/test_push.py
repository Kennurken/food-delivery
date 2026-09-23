"""FCM HTTP v1 transport. No network: the token exchange and the send are faked,
but the JWT is signed with a real RSA key so the assertion path is exercised.
"""

import json
from collections.abc import Callable
from typing import ClassVar

import pytest
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa

from app.core import push
from app.core.config import settings
from app.db.session import SessionLocal
from app.models.device import DeviceToken


@pytest.fixture(scope="module")
def private_key() -> str:
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    return key.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    ).decode()


@pytest.fixture
def account(private_key: str) -> dict[str, str]:
    return {
        "type": "service_account",
        "project_id": "food-delivery-test",
        "client_email": "push@food-delivery-test.iam.gserviceaccount.com",
        "private_key": private_key,
    }


@pytest.fixture(autouse=True)
def _clean_cache():
    push.reset_credentials_cache()
    yield
    push.reset_credentials_cache()


class FakeResponse:
    def __init__(self, status_code: int, payload: object = None):
        self.status_code = status_code
        self._payload = payload
        self.text = json.dumps(payload) if payload is not None else ""

    def json(self) -> object:
        if self._payload is None:
            raise ValueError("no json")
        return self._payload


class FakeClient:
    """Stands in for httpx.Client and records every call."""

    calls: ClassVar[list[dict]] = []
    reply: ClassVar[Callable[..., "FakeResponse"]]

    def __init__(self, *_args, **_kwargs):
        pass

    def __enter__(self):
        return self

    def __exit__(self, *_exc):
        return False

    def post(self, url, **kwargs):
        FakeClient.calls.append({"url": url, **kwargs})
        return FakeClient.reply(url, **kwargs)


@pytest.fixture
def fake_http(monkeypatch):
    FakeClient.calls = []
    FakeClient.reply = lambda url, **kw: FakeResponse(200, {})
    monkeypatch.setattr(push.httpx, "Client", FakeClient)
    return FakeClient


def _token_grant(url, **_kw):
    return FakeResponse(200, {"access_token": "ya29.fake", "expires_in": 3600})


def test_no_credentials_sends_nothing(monkeypatch, fake_http):
    monkeypatch.setattr(settings, "fcm_credentials_json", "")
    push.reset_credentials_cache()

    assert push.send(["tok"], title="t", body="b", data={}) == 0
    assert fake_http.calls == []


def test_credentials_accept_raw_json(monkeypatch, account):
    monkeypatch.setattr(settings, "fcm_credentials_json", json.dumps(account))
    push.reset_credentials_cache()

    assert push._credentials()["client_email"] == account["client_email"]


def test_credentials_accept_base64(monkeypatch, account):
    import base64

    blob = base64.b64encode(json.dumps(account).encode()).decode()
    monkeypatch.setattr(settings, "fcm_credentials_json", blob)
    push.reset_credentials_cache()

    assert push._credentials()["project_id"] == "food-delivery-test"


def test_garbage_credentials_stay_off(monkeypatch):
    monkeypatch.setattr(settings, "fcm_credentials_json", "not-a-key")
    push.reset_credentials_cache()

    assert push._credentials() is None


def test_incomplete_account_stays_off(monkeypatch):
    monkeypatch.setattr(settings, "fcm_credentials_json", json.dumps({"project_id": "x"}))
    push.reset_credentials_cache()

    assert push._credentials() is None


def test_send_hits_v1_endpoint_with_bearer(monkeypatch, account, fake_http):
    monkeypatch.setattr(settings, "fcm_credentials_json", json.dumps(account))
    push.reset_credentials_cache()
    FakeClient.reply = lambda url, **kw: (
        _token_grant(url, **kw) if "oauth2" in url else FakeResponse(200, {"name": "ok"})
    )

    assert push.send(["a", "b"], title="Order #1", body="on the way", data={"order_id": 1}) == 2

    grant, first, second = fake_http.calls
    assert grant["url"] == "https://oauth2.googleapis.com/token"
    assert grant["data"]["grant_type"] == "urn:ietf:params:oauth:grant-type:jwt-bearer"
    assert grant["data"]["assertion"].count(".") == 2  # a signed JWT, not a placeholder
    assert first["url"] == (
        "https://fcm.googleapis.com/v1/projects/food-delivery-test/messages:send"
    )
    assert first["headers"]["Authorization"] == "Bearer ya29.fake"
    assert first["json"]["message"]["token"] == "a"
    assert second["json"]["message"]["token"] == "b"
    # v1 refuses non-string data values.
    assert first["json"]["message"]["data"] == {"order_id": "1"}


def test_access_token_is_reused(monkeypatch, account, fake_http):
    monkeypatch.setattr(settings, "fcm_credentials_json", json.dumps(account))
    push.reset_credentials_cache()
    FakeClient.reply = lambda url, **kw: (
        _token_grant(url, **kw) if "oauth2" in url else FakeResponse(200, {"name": "ok"})
    )

    push.send(["a"], title="t", body="b", data={})
    push.send(["b"], title="t", body="b", data={})

    grants = [c for c in fake_http.calls if "oauth2" in c["url"]]
    assert len(grants) == 1


def test_failed_token_grant_reports_zero(monkeypatch, account, fake_http):
    monkeypatch.setattr(settings, "fcm_credentials_json", json.dumps(account))
    push.reset_credentials_cache()
    FakeClient.reply = lambda url, **kw: FakeResponse(401, {"error": "invalid_grant"})

    assert push.send(["a"], title="t", body="b", data={}) == 0


def _unregistered() -> FakeResponse:
    return FakeResponse(
        404,
        {
            "error": {
                "status": "NOT_FOUND",
                "details": [{"errorCode": "UNREGISTERED"}],
            }
        },
    )


def test_fanout_prunes_dead_tokens(monkeypatch, client, account, fake_http):
    monkeypatch.setattr(settings, "fcm_credentials_json", json.dumps(account))
    push.reset_credentials_cache()
    FakeClient.reply = lambda url, **kw: (
        _token_grant(url, **kw)
        if "oauth2" in url
        else (
            _unregistered()
            if kw["json"]["message"]["token"] == "dead-token"
            else FakeResponse(200, {"name": "ok"})
        )
    )

    db = SessionLocal()
    try:
        push.register_token(db, 1, "live-token", "android")
        push.register_token(db, 1, "dead-token", "android")

        assert push.fanout(db, {1}, title="t", body="b", data={}) == 1

        left = {row.token for row in db.query(DeviceToken).filter(DeviceToken.user_id == 1)}
        assert "dead-token" not in left
        assert "live-token" in left

        push.drop_token(db, 1, "live-token")
    finally:
        db.close()


def test_our_own_bad_payload_keeps_tokens(monkeypatch, client, account, fake_http):
    """A bare INVALID_ARGUMENT is usually our bug. Do not wipe the user's devices."""
    monkeypatch.setattr(settings, "fcm_credentials_json", json.dumps(account))
    push.reset_credentials_cache()
    FakeClient.reply = lambda url, **kw: (
        _token_grant(url, **kw)
        if "oauth2" in url
        else FakeResponse(400, {"error": {"status": "INVALID_ARGUMENT"}})
    )

    db = SessionLocal()
    try:
        push.register_token(db, 1, "still-good", "ios")

        assert push.fanout(db, {1}, title="t", body="b", data={}) == 0
        assert db.query(DeviceToken).filter(DeviceToken.token == "still-good").count() == 1

        push.drop_token(db, 1, "still-good")
    finally:
        db.close()
