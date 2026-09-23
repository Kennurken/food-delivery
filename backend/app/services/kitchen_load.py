"""How busy a kitchen is right now.

A restaurant that keeps taking orders it cannot cook produces late food and
refunds. The cap is the owner's number; pausing is derived from it, never
written back onto `is_open` — that switch belongs to the owner alone.
"""

from __future__ import annotations

from dataclasses import dataclass

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models import Order, OrderStatus, Restaurant

# Tickets the kitchen still owes food for. Once a courier is riding with it,
# the stove is free again.
COOKING = (OrderStatus.pending, OrderStatus.confirmed, OrderStatus.preparing)


@dataclass(frozen=True)
class KitchenLoad:
    active: int
    cap: int | None

    @property
    def overloaded(self) -> bool:
        return self.cap is not None and self.active >= self.cap

    @property
    def free_slots(self) -> int | None:
        return None if self.cap is None else max(0, self.cap - self.active)


def load_of(db: Session, restaurant: Restaurant) -> KitchenLoad:
    active = (
        db.scalar(
            select(func.count(Order.id)).where(
                Order.restaurant_id == restaurant.id,
                Order.status.in_(COOKING),
            )
        )
        or 0
    )
    cap = getattr(restaurant, "max_active_orders", None)
    return KitchenLoad(active=int(active), cap=int(cap) if cap else None)


def accepting(db: Session, restaurant: Restaurant) -> bool:
    """Open, and with room on the stove."""
    return bool(restaurant.is_open) and not load_of(db, restaurant).overloaded
