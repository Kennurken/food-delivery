"""Append-only admin actions. Caller owns the commit."""

from sqlalchemy.orm import Session

from app.models.audit import AuditLog


def record(
    db: Session,
    *,
    actor_id: int | None,
    restaurant_id: int | None,
    action: str,
    resource: str,
    payload: dict | None = None,
    request_id: str | None = None,
) -> None:
    db.add(
        AuditLog(
            actor_id=actor_id,
            restaurant_id=restaurant_id,
            action=action,
            resource=resource,
            payload=payload or {},
            request_id=request_id,
        )
    )
