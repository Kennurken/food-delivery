"""Reading a venue's written reviews.

Shared by the API and the public site, so both show the same thing — and the
same rule about names: a review is public, so its author is a first name and
an initial, never the full name.
"""

from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import Order, User


def author_of(user: User | None) -> str:
    """"Алия К." — a first name and an initial. A review is public; a full name
    next to what someone ate and where is more than they agreed to show."""
    parts = (user.name if user else "").split()
    if not parts:
        return ""
    return parts[0] if len(parts) == 1 else f"{parts[0]} {parts[1][0]}."


def public_row(order: Order) -> dict:
    return {
        "order_id": order.id,
        "rating": order.rating,
        "text": order.review,
        "author": author_of(order.user),
        "at": order.reviewed_at.isoformat() if order.reviewed_at else None,
        "reply": order.review_reply,
    }


def recent(db: Session, restaurant_id: int, *, limit: int = 20, before: int | None = None) -> list[Order]:
    stmt = (
        select(Order)
        .where(Order.restaurant_id == restaurant_id, Order.review.is_not(None))
        .order_by(Order.id.desc())
        .limit(limit)
    )
    if before is not None:
        stmt = stmt.where(Order.id < before)
    return list(db.scalars(stmt))
