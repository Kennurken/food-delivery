"""Error reporting is opt-in: no DSN, no SDK, no traffic."""

from app.core import monitoring
from app.core.config import settings


def test_it_is_off_without_a_dsn(monkeypatch):
    monkeypatch.setattr(settings, "sentry_dsn", "")

    assert monitoring.init() is False


def test_it_starts_with_a_dsn_and_sends_no_personal_data(monkeypatch):
    seen = {}
    import sentry_sdk

    monkeypatch.setattr(sentry_sdk, "init", lambda **kw: seen.update(kw))
    monkeypatch.setattr(settings, "sentry_dsn", "https://key@example.ingest.sentry.io/1")

    assert monitoring.init() is True
    assert seen["send_default_pii"] is False
    assert seen["max_request_body_size"] == "never"
