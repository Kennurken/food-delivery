"""A venue's bonus programme: earn on food that was delivered, spend at checkout.

Three rules carry the design:

- Earning waits for delivery. Bonuses granted at checkout would be granted for
  orders that are later cancelled, and clawing them back after the diner has
  spent them is a dispute, not a ledger entry.
- Earning is on food actually paid for: after the promo discount and after the
  bonuses spent on the same order. Paying with bonuses must not mint bonuses.
- Spending is capped at a share of the food, and in whole tenge. It never
  touches the delivery fee — that money is the courier's.
"""

from __future__ import annotations

import math

from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.features import entitlements
from app.models import LoyaltyEntry, Order, Restaurant, User

EARN, SPEND, REFUND = "earn", "spend", "refund"


def enabled(db: Session, restaurant: Restaurant) -> bool:
    """Whether this venue gives bonuses now: paid for, and switched on."""
    return (restaurant.loyalty_percent or 0) > 0 and entitlements(db, restaurant).enabled("loyalty")


def balance(db: Session, user_id: int, restaurant_id: int) -> float:
    total = db.scalar(
        select(func.coalesce(func.sum(LoyaltyEntry.amount), 0.0)).where(
            LoyaltyEntry.user_id == user_id, LoyaltyEntry.restaurant_id == restaurant_id
        )
    )
    return round(float(total or 0.0), 2)


def max_spend(restaurant: Restaurant, food: float, held: float) -> float:
    """The most bonuses this order may use, in whole tenge."""
    share = min(max(restaurant.loyalty_max_share or 0.0, 0.0), 1.0)
    return float(math.floor(max(0.0, min(held, food * share))))


def spend(db: Session, user: User, restaurant: Restaurant, food: float) -> float:
    """Take as much of the diner's balance as this order may use.

    Locks the diner's row first: two checkouts racing on one balance would
    otherwise both see it whole. (SQLite ignores the lock; Postgres honours it.)
    The ledger row is written by `record_spend` once the order has an id.
    """
    db.execute(select(User.id).where(User.id == user.id).with_for_update())
    return max_spend(restaurant, food, balance(db, user.id, restaurant.id))


def record_spend(db: Session, order: Order) -> None:
    if order.loyalty_spent > 0:
        _add(db, order, SPEND, -order.loyalty_spent)


def earn(db: Session, order: Order) -> float:
    """Credit a delivered order. Idempotent: a second call adds nothing."""
    restaurant = order.restaurant
    user = order.user
    if user is None or getattr(user, "is_guest", False):
        # A table guest has no account to come back to; bonuses would be
        # promised to nobody.
        return 0.0
    if not enabled(db, restaurant):
        return 0.0
    paid_food = max(0.0, (order.subtotal or 0.0) - (order.discount or 0.0) - (order.loyalty_spent or 0.0))
    amount = float(math.floor(paid_food * restaurant.loyalty_percent / 100))
    if amount <= 0:
        return 0.0
    return amount if _add(db, order, EARN, amount) else 0.0


def refund(db: Session, order: Order) -> None:
    """Give back what a cancelled order spent. Idempotent."""
    if order.loyalty_spent > 0:
        _add(db, order, REFUND, order.loyalty_spent)


def earned_on(db: Session, order_id: int) -> float:
    total = db.scalar(
        select(func.coalesce(func.sum(LoyaltyEntry.amount), 0.0)).where(
            LoyaltyEntry.order_id == order_id, LoyaltyEntry.kind == EARN
        )
    )
    return round(float(total or 0.0), 2)


def _add(db: Session, order: Order, kind: str, amount: float) -> bool:
    exists = db.scalar(
        select(LoyaltyEntry.id).where(LoyaltyEntry.order_id == order.id, LoyaltyEntry.kind == kind)
    )
    if exists:
        return False
    # The unique (order_id, kind) index is the real guard against a concurrent
    # retry; the check above only spares the common case an exception.
    try:
        with db.begin_nested():
            db.add(
                LoyaltyEntry(
                    user_id=order.user_id,
                    restaurant_id=order.restaurant_id,
                    order_id=order.id,
                    kind=kind,
                    amount=round(amount, 2),
                )
            )
    except IntegrityError:
        return False
    return True
