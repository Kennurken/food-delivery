"""Error reporting, switched on by SENTRY_DSN and otherwise absent.

Unhandled exceptions go to Sentry so a failure in a restaurant's kitchen is
found by us, not reported by them. Nothing personal is attached: no default
PII, and request bodies (which carry passwords and addresses) are not sent.
"""

from __future__ import annotations

import logging

from app.core.config import settings

log = logging.getLogger(__name__)


def init() -> bool:
    """Start reporting. Returns whether it is on."""
    dsn = (settings.sentry_dsn or "").strip()
    if not dsn:
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
    return True
