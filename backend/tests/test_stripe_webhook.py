"""Stripe webhook. The signature is real — we sign the payload with the same
secret the app verifies against, so `stripe.Webhook.construct_event` does its
actual work instead of being stubbed out.
"""

import hashlib
import hmac
import json
import time

import pytest

from app.core.billing import PaymentResult
from app.core.config import settings
from app.services import order_service as svc

WEBHOOK = "/api/v1/billing/stripe/webhook"
SECRET = "whsec_test_only_never_a_real_secret"


@pytest.fixture
def card_order(client, auth, monkeypatch):
    """An online ticket sitting at pending/pending, as Stripe would leave it."""
    monkeypatch.setattr(svc, "card_connected", lambda: True)
    monkeypatch.setattr(
        svc,
        "create_checkout_session",
        lambda **kw: PaymentResult(
            provider="stripe",
            reference=f"cs_test_{kw['order_id']}",
            status="pending",
            url="https://checkout.stripe.com/c/pay/cs_test_1",
        ),
    )
    menu = client.get("/api/v1/restaurants/1/menu").json()
    r = client.post(
        "/api/v1/orders",
        json={
            "restaurant_id": 1,
            "address": "Abay 10",
            "pay_method": "online",
            "items": [{"menu_item_id": menu[0]["id"], "quantity": 1}],
        },
        headers=auth,
    )
    assert r.status_code == 201, r.text
    return r.json()


def _signed(event: dict) -> tuple[bytes, str]:
    """Same scheme Stripe uses: HMAC-SHA256 over `timestamp.payload`."""
    payload = json.dumps(event).encode()
    stamp = int(time.time())
    digest = hmac.new(
        SECRET.encode(), f"{stamp}.".encode() + payload, hashlib.sha256
    ).hexdigest()
    return payload, f"t={stamp},v1={digest}"


def _completed(order_id: int, *, payment_status: str = "paid") -> dict:
    return {
        "id": "evt_test_1",
        "type": "checkout.session.completed",
        "data": {
            "object": {
                "id": f"cs_test_{order_id}",
                "object": "checkout.session",
                "payment_status": payment_status,
                "client_reference_id": str(order_id),
                "metadata": {"order_id": str(order_id)},
            }
        },
    }


def _post(client, event: dict, *, signature: str | None = None):
    payload, signed = _signed(event)
    return client.post(
        WEBHOOK,
        content=payload,
        headers={
            "stripe-signature": signature if signature is not None else signed,
            "Content-Type": "application/json",
        },
    )


def test_webhook_is_closed_without_a_secret(client, monkeypatch):
    """No secret means anyone could mark anything paid. Refuse to listen."""
    monkeypatch.setattr(settings, "stripe_webhook_secret", "")

    r = _post(client, _completed(1))

    assert r.status_code == 503


def test_valid_signature_marks_the_order_paid(client, auth, card_order, monkeypatch):
    monkeypatch.setattr(settings, "stripe_webhook_secret", SECRET)
    oid = card_order["id"]

    r = _post(client, _completed(oid))

    assert r.status_code == 200, r.text
    assert r.json() == {"ok": True, "order_id": oid}
    order = client.get(f"/api/v1/orders/{oid}", headers=auth).json()
    assert order["pay_status"] == "paid"


def test_forged_signature_changes_nothing(client, auth, card_order, monkeypatch):
    monkeypatch.setattr(settings, "stripe_webhook_secret", SECRET)
    oid = card_order["id"]

    r = _post(client, _completed(oid), signature="t=1,v1=deadbeef")

    assert r.status_code == 400
    order = client.get(f"/api/v1/orders/{oid}", headers=auth).json()
    assert order["pay_status"] == "pending"


def test_missing_signature_changes_nothing(client, auth, card_order, monkeypatch):
    monkeypatch.setattr(settings, "stripe_webhook_secret", SECRET)
    oid = card_order["id"]

    r = _post(client, _completed(oid), signature="")

    assert r.status_code == 400
    order = client.get(f"/api/v1/orders/{oid}", headers=auth).json()
    assert order["pay_status"] == "pending"


def test_unpaid_session_does_not_mark_the_order_paid(client, auth, card_order, monkeypatch):
    """Checkout can complete while the money is still in flight."""
    monkeypatch.setattr(settings, "stripe_webhook_secret", SECRET)
    oid = card_order["id"]

    r = _post(client, _completed(oid, payment_status="unpaid"))

    assert r.status_code == 200
    assert r.json()["order_id"] is None
    order = client.get(f"/api/v1/orders/{oid}", headers=auth).json()
    assert order["pay_status"] == "pending"


def test_unrelated_event_is_ignored(client, auth, card_order, monkeypatch):
    monkeypatch.setattr(settings, "stripe_webhook_secret", SECRET)
    oid = card_order["id"]
    event = _completed(oid)
    event["type"] = "payment_intent.created"

    r = _post(client, event)

    assert r.status_code == 200
    assert r.json()["order_id"] is None
    order = client.get(f"/api/v1/orders/{oid}", headers=auth).json()
    assert order["pay_status"] == "pending"


def test_async_payment_succeeded_also_pays(client, auth, card_order, monkeypatch):
    """Bank redirects land here instead of checkout.session.completed."""
    monkeypatch.setattr(settings, "stripe_webhook_secret", SECRET)
    oid = card_order["id"]
    event = _completed(oid)
    event["type"] = "checkout.session.async_payment_succeeded"

    r = _post(client, event)

    assert r.status_code == 200
    order = client.get(f"/api/v1/orders/{oid}", headers=auth).json()
    assert order["pay_status"] == "paid"


def test_cash_order_is_never_flipped_by_a_webhook(client, auth, monkeypatch):
    """A cash ticket has no Stripe side. An event naming it must not settle it."""
    monkeypatch.setattr(settings, "stripe_webhook_secret", SECRET)
    menu = client.get("/api/v1/restaurants/1/menu").json()
    cash = client.post(
        "/api/v1/orders",
        json={
            "restaurant_id": 1,
            "address": "Abay 10",
            "pay_method": "cash",
            "items": [{"menu_item_id": menu[0]["id"], "quantity": 1}],
        },
        headers=auth,
    ).json()

    r = _post(client, _completed(cash["id"]))

    assert r.status_code == 200
    assert r.json()["order_id"] is None
    order = client.get(f"/api/v1/orders/{cash['id']}", headers=auth).json()
    assert order["pay_status"] == "unpaid"


def test_replaying_the_same_event_keeps_one_payment(client, auth, card_order, monkeypatch):
    """Stripe retries until it gets a 2xx. The second delivery must be harmless."""
    monkeypatch.setattr(settings, "stripe_webhook_secret", SECRET)
    oid = card_order["id"]

    first = _post(client, _completed(oid))
    second = _post(client, _completed(oid))

    assert first.status_code == 200
    assert second.status_code == 200
    order = client.get(f"/api/v1/orders/{oid}", headers=auth).json()
    assert order["pay_status"] == "paid"
