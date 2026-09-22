"""Push notifications behind one provider — same idea as billing.

Without FCM_SERVER_KEY this is a no-op. We still record device tokens so a
key can start working later. Never report a send that did not happen.
"""

from __future__ import annotations

import logging

import httpx
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.device import DeviceToken

log = logging.getLogger(__name__)


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
    return send(tokens, title=title, body=body, data=data or {})


def send(tokens: list[str], *, title: str, body: str, data: dict[str, str]) -> int:
    key = (settings.fcm_server_key or "").strip()
    if not key or not tokens:
        return 0
    try:
        with httpx.Client(timeout=8.0) as client:
            res = client.post(
                "https://fcm.googleapis.com/fcm/send",
                headers={"Authorization": f"key={key}", "Content-Type": "application/json"},
                json={
                    "registration_ids": tokens[:500],
                    "notification": {"title": title, "body": body},
                    "data": data,
                    "priority": "high",
                },
            )
        if res.status_code >= 400:
            log.warning("fcm %s %s", res.status_code, res.text[:200])
            return 0
        payload = res.json()
        return int(payload.get("success") or 0)
    except Exception:
        log.exception("fcm send failed")
        return 0
