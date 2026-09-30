"""Error reporting, switched on by SENTRY_DSN and otherwise absent.

Unhandled exceptions go to Sentry so a failure in a restaurant's kitchen is
found by us, not reported by them. Nothing personal is attached: no default
PII, and request bodies (which carry passwords and addresses) are not sent.
"""

from __future__ import annotations

import logging

from app.core.config import settings

log = logging.getLogger(__name__)

_on = False


def init() -> bool:
    """Start reporting. Returns whether it is on."""
    global _on
    dsn = (settings.sentry_dsn or "").strip()
    if not dsn:
        _on = False
        return False
    import sentry_sdk

    sentry_sdk.init(
        dsn=dsn,
        environment=settings.env,
        send_default_pii=False,
        max_request_body_size="never",
        traces_sample_rate=settings.sentry_traces_sample_rate,
    )
    log.info("error reporting on")
    _on = True
    return True


def enabled() -> bool:
    return _on


def send_test(actor_id: int) -> str | None:
    """Report a harmless exception the way a real one would be reported, and
    return its event id. No flush on purpose: the point is to see whether an
    ordinary error survives the serverless host freezing after the response.
    """
    if not _on:
        return None
    import sentry_sdk

    try:
        raise RuntimeError(f"Monitoring check from the platform panel (admin {actor_id})")
    except RuntimeError as exc:
        return sentry_sdk.capture_exception(exc)
