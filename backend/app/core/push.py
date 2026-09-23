"""Push notifications behind one provider — same idea as billing.

Google retired the legacy `fcm/send` endpoint, so this speaks FCM HTTP v1:
the service account signs a JWT, Google swaps it for an access token, and
each device gets its own request (v1 has no multicast).

Without FCM_CREDENTIALS_JSON this is a no-op. We still record device tokens
so credentials can start working later. Never report a send that did not
happen.
"""

from __future__ import annotations

import base64
import binascii
import json
import logging
import threading
import time
from functools import lru_cache

import httpx
from jose import jwt
from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.device import DeviceToken

log = logging.getLogger(__name__)

_SCOPE = "https://www.googleapis.com/auth/firebase.messaging"
_TOKEN_URI = "https://oauth2.googleapis.com/token"
_TIMEOUT = 6.0
# HTTP v1 dropped multicast, so a fan-out is one request per device. Cap it:
# a busy restaurant's ticket must not hold a worker thread for a minute.
_MAX_TOKENS = 100
# Google's access tokens last an hour. Renew early so a send never races expiry.
_EARLY_REFRESH = 300
# Errors that are about the token itself rather than the message we built.
# A bare INVALID_ARGUMENT is not on this list: it usually means *our* payload is
# wrong, and wiping every device over our own bug is worse than a retry.
_DEAD_TOKEN_CODES = frozenset({"UNREGISTERED", "SENDER_ID_MISMATCH"})

_lock = threading.Lock()
_access: tuple[str, float] | None = None  # (token, epoch seconds it expires)


def register_token(db: Session, user_id: int, token: str, platform: str) -> DeviceToken:
    token = token.strip()
    row = db.scalar(select(DeviceToken).where(DeviceToken.token == token))
    if row:
        row.user_id = user_id
        row.platform = platform
        db.commit()
        db.refresh(row)
        return row
    row = DeviceToken(user_id=user_id, token=token, platform=platform)
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def drop_token(db: Session, user_id: int, token: str) -> None:
    row = db.scalar(
        select(DeviceToken).where(DeviceToken.user_id == user_id, DeviceToken.token == token)
    )
    if row:
        db.delete(row)
        db.commit()


def fanout(
    db: Session,
    user_ids: set[int],
    *,
    title: str,
    body: str,
    data: dict[str, str] | None = None,
) -> int:
    if not user_ids:
        return 0
    tokens = list(
        db.scalars(select(DeviceToken.token).where(DeviceToken.user_id.in_(user_ids)))
    )
    sent, stale = _deliver(tokens, title=title, body=body, data=data or {})
    if stale:
        # The app was uninstalled or the token was reissued. Keeping it means
        # paying for a failed request on every future order.
        db.execute(delete(DeviceToken).where(DeviceToken.token.in_(stale)))
        db.commit()
    return sent


def send(tokens: list[str], *, title: str, body: str, data: dict[str, str]) -> int:
    """Fire at tokens the caller already holds. Dead ones are not pruned here."""
    return _deliver(tokens, title=title, body=body, data=data)[0]


def reset_credentials_cache() -> None:
    """Tests change settings at runtime; the parsed account lives per process."""
    global _access
    _credentials.cache_clear()
    with _lock:
        _access = None


@lru_cache(maxsize=1)
def _credentials() -> dict[str, str] | None:
    raw = (settings.fcm_credentials_json or "").strip()
    if not raw:
        return None
    if not raw.startswith("{"):
        # A private key is full of newlines, which dashboards mangle on paste.
        # Base64 survives the trip.
        try:
            raw = base64.b64decode(raw, validate=True).decode()
        except (binascii.Error, UnicodeDecodeError, ValueError):
            log.error("FCM_CREDENTIALS_JSON is neither JSON nor base64; push stays off")
            return None
    try:
        info = json.loads(raw)
    except json.JSONDecodeError:
        log.error("FCM_CREDENTIALS_JSON is not valid JSON; push stays off")
        return None
    if not isinstance(info, dict):
        log.error("FCM_CREDENTIALS_JSON is not a service account object; push stays off")
        return None
    missing = [key for key in ("client_email", "private_key") if not info.get(key)]
    if missing:
        log.error("FCM service account is missing %s; push stays off", ", ".join(missing))
        return None
    return info


def _project_id(info: dict[str, str]) -> str:
    return (info.get("project_id") or settings.firebase_project_id or "").strip()


def _access_token() -> str | None:
    global _access
    info = _credentials()
    if not info:
        return None
    with _lock:
        now = time.time()
        if _access and _access[1] - _EARLY_REFRESH > now:
            return _access[0]
        uri = info.get("token_uri") or _TOKEN_URI
        try:
            assertion = jwt.encode(
                {
                    "iss": info["client_email"],
                    "scope": _SCOPE,
                    "aud": uri,
                    "iat": int(now),
                    "exp": int(now) + 3600,
                },
                info["private_key"],
                algorithm="RS256",
            )
            with httpx.Client(timeout=_TIMEOUT) as client:
                res = client.post(
                    uri,
                    data={
                        "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
                        "assertion": assertion,
                    },
                )
        except Exception:
            log.exception("fcm token request failed")
            return None
        if res.status_code >= 400:
            log.warning("fcm token %s %s", res.status_code, res.text[:200])
            return None
        try:
            payload = res.json()
        except ValueError:
            log.warning("fcm token response was not json")
            return None
        token = payload.get("access_token")
        if not token:
            return None
        _access = (token, now + float(payload.get("expires_in") or 3600))
        return token


def _deliver(
    tokens: list[str], *, title: str, body: str, data: dict[str, str]
) -> tuple[int, list[str]]:
    """Send to each token. Returns (accepted, tokens Google says are gone)."""
    info = _credentials()
    if not info or not tokens:
        return 0, []
    project = _project_id(info)
    if not project:
        log.error("FCM service account has no project_id; push stays off")
        return 0, []
    access = _access_token()
    if not access:
        return 0, []
    url = f"https://fcm.googleapis.com/v1/projects/{project}/messages:send"
    headers = {"Authorization": f"Bearer {access}", "Content-Type": "application/json"}
    # v1 rejects non-string data values outright, so coerce before asking.
    fields = {key: str(value) for key, value in data.items()}
    sent = 0
    stale: list[str] = []
    try:
        with httpx.Client(timeout=_TIMEOUT) as client:
            for token in tokens[:_MAX_TOKENS]:
                res = client.post(
                    url,
                    headers=headers,
                    json={
                        "message": {
                            "token": token,
                            "notification": {"title": title, "body": body},
                            "data": fields,
                            "android": {"priority": "HIGH"},
                            "apns": {"headers": {"apns-priority": "10"}},
                        }
                    },
                )
                if res.status_code < 300:
                    sent += 1
                elif _token_is_gone(res):
                    stale.append(token)
                else:
                    # 200 chars cut the body off right before `details`, which is
                    # the only part that says what Google actually objected to.
                    log.warning("fcm %s %s", res.status_code, res.text[:600])
    except Exception:
        log.exception("fcm send failed")
    return sent, stale


def _token_is_gone(res: httpx.Response) -> bool:
    if res.status_code not in (400, 403, 404):
        return False
    try:
        error = res.json().get("error") or {}
    except ValueError:
        return False
    if error.get("status") == "NOT_FOUND":
        return True
    details = error.get("details") or []
    if any((item.get("errorCode") or "") in _DEAD_TOKEN_CODES for item in details):
        return True
    # A 400 is INVALID_ARGUMENT either way, so the status alone cannot tell a
    # rotten token from a payload bug of ours. Google does name the offending
    # field, though, and `message.token` means the token and nothing else.
    return any(
        violation.get("field") == "message.token"
        for item in details
        for violation in (item.get("fieldViolations") or [])
    )
