"""Error reporting is opt-in: no DSN, no SDK, no traffic."""

from app.core import monitoring
from app.core.config import settings


def test_it_is_off_without_a_dsn(monkeypatch):
    monkeypatch.setattr(settings, "sentry_dsn", "")

    assert monitoring.init() is False


def test_it_starts_with_a_dsn_and_sends_no_personal_data(monkeypatch):
    monkeypatch.setattr(monitoring, "_on", False)  # restored after, so nothing leaks
    seen = {}
    import sentry_sdk

    monkeypatch.setattr(sentry_sdk, "init", lambda **kw: seen.update(kw))
    monkeypatch.setattr(settings, "sentry_dsn", "https://key@example.ingest.sentry.io/1")

    assert monitoring.init() is True
    assert seen["send_default_pii"] is False
    assert seen["max_request_body_size"] == "never"


def test_the_overview_says_whether_reporting_is_on(client, admin):
    assert client.get("/api/v1/platform/overview", headers=admin).json()["error_reporting"] is False


def test_the_test_button_refuses_when_reporting_is_off(client, admin):
    r = client.post("/api/v1/platform/monitoring/test", headers=admin)

    assert r.status_code == 409


def test_only_the_platform_may_press_it(client, auth):
    assert client.post("/api/v1/platform/monitoring/test", headers=auth).status_code == 403


def test_the_test_error_goes_through_sentry(client, admin, monkeypatch):
    import sentry_sdk

    seen = []
    monkeypatch.setattr(monitoring, "_on", True)
    monkeypatch.setattr(sentry_sdk, "capture_exception", lambda exc: seen.append(exc) or "abc123")

    r = client.post("/api/v1/platform/monitoring/test", headers=admin)

    assert r.status_code == 202 and r.json() == {"event_id": "abc123"}
    assert isinstance(seen[0], RuntimeError)
