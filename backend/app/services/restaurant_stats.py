"""What a restaurant owner needs to see about their own venue.

Two rules shape everything here.

Money is only counted once it is real: a ticket counts when it was delivered
and either the cash was taken or the card actually cleared. An unpaid online
order that never came back from Stripe is not revenue, and showing it as such
would have an owner planning against a number that does not exist.

The window a plan can look back over is an entitlement, not an `if plan ==`.
Basic sees a week, Pro a quarter, Premium a year.

Everything aggregates in SQL. A busy venue must not turn a dashboard into
thousands of row loads.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta

from sqlalchemy import Float, case, func, select
from sqlalchemy.orm import Session

from app.core.features import Entitlements
from app.models.order import Order, OrderItem, OrderStatus
from app.models.restaurant import Restaurant
from app.models.user import User

# Delivered, and the money genuinely arrived. Cash is settled at the door, a
# card only when the processor said so.
EARNED = (Order.status == OrderStatus.delivered) & (
    (Order.pay_method != "online") | (Order.pay_status == "paid")
)

# How far back each tier may look. The dashboard is the same; the history is
# what the plan buys.
WINDOW_BY_FEATURE = (("analytics.advanced", 365), ("analytics.pro", 90), ("analytics.basic", 7))
DEFAULT_WINDOW = 7


def max_window(flags: Entitlements) -> int:
    for feature, days in WINDOW_BY_FEATURE:
        if feature in flags.features:
            return days
    return DEFAULT_WINDOW


@dataclass(frozen=True)
class DayRow:
    day: str
    orders: int
    revenue: float


@dataclass(frozen=True)
class DishRow:
    name: str
    quantity: int
    revenue: float


@dataclass(frozen=True)
class Stats:
    days: int
    window_limit: int
    orders: int
    revenue: float
    average_check: float
    cancelled: int
    cancel_rate: float
    by_day: list[DayRow]
    top_dishes: list[DishRow]
    by_channel: dict[str, int]
    by_pay_method: dict[str, int]


@dataclass(frozen=True)
class CustomerRow:
    user_id: int
    name: str
    phone: str | None
    orders: int
    spent: float
    last_order_at: datetime | None


def _since(days: int) -> datetime:
    return datetime.now() - timedelta(days=days)  # noqa: DTZ005 — rows are naive


def clamp_days(requested: int, flags: Entitlements) -> int:
    return max(1, min(requested, max_window(flags)))


def summary(db: Session, restaurant: Restaurant, *, days: int, flags: Entitlements) -> Stats:
    allowed = clamp_days(days, flags)
    since = _since(allowed)
    mine = (Order.restaurant_id == restaurant.id) & (Order.created_at >= since)

    totals = db.execute(
        select(
            func.count(Order.id),
            func.coalesce(func.sum(case((EARNED, Order.total), else_=0.0).cast(Float)), 0.0),
            func.coalesce(func.sum(case((EARNED, 1), else_=0)), 0),
            func.coalesce(
                func.sum(case((Order.status == OrderStatus.cancelled, 1), else_=0)), 0
            ),
        ).where(mine)
    ).one()
    placed = int(totals[0] or 0)
    revenue = round(float(totals[1] or 0.0), 2)
    earned_count = int(totals[2] or 0)
    cancelled = int(totals[3] or 0)

    day = func.date(Order.created_at)
    day_rows = db.execute(
        select(
            day,
            func.count(Order.id),
            func.coalesce(func.sum(case((EARNED, Order.total), else_=0.0).cast(Float)), 0.0),
        )
        .where(mine)
        .group_by(day)
        .order_by(day.desc())
    ).all()

    dish_rows = db.execute(
        select(
            OrderItem.name,
            func.coalesce(func.sum(OrderItem.quantity), 0),
            func.coalesce(func.sum(OrderItem.price * OrderItem.quantity).cast(Float), 0.0),
        )
        .join(Order, Order.id == OrderItem.order_id)
        .where(mine, EARNED)
        .group_by(OrderItem.name)
        .order_by(func.sum(OrderItem.quantity).desc())
        .limit(10)
    ).all()

    channels = db.execute(
        select(Order.channel, func.count(Order.id)).where(mine).group_by(Order.channel)
    ).all()
    methods = db.execute(
        select(Order.pay_method, func.count(Order.id)).where(mine).group_by(Order.pay_method)
    ).all()

    return Stats(
        days=allowed,
        window_limit=max_window(flags),
        orders=placed,
        revenue=revenue,
        # Per ticket that actually earned, not per ticket ever opened: dividing
        # by abandoned baskets would quietly understate every venue.
        average_check=round(revenue / earned_count, 2) if earned_count else 0.0,
        cancelled=cancelled,
        cancel_rate=round(cancelled / placed, 4) if placed else 0.0,
        by_day=[
            DayRow(day=str(d), orders=int(n or 0), revenue=round(float(total or 0.0), 2))
            for d, n, total in day_rows
        ],
        top_dishes=[
            DishRow(name=name, quantity=int(qty or 0), revenue=round(float(money or 0.0), 2))
            for name, qty, money in dish_rows
        ],
        by_channel={str(channel): int(count) for channel, count in channels},
        by_pay_method={str(method): int(count) for method, count in methods},
    )


def customers(
    db: Session, restaurant: Restaurant, *, days: int, flags: Entitlements, limit: int = 50
) -> list[CustomerRow]:
    """Who keeps coming back. Aggregated in SQL, and only over orders that
    earned — a cancelled basket is not a customer relationship."""
    allowed = clamp_days(days, flags)
    since = _since(allowed)
    rows = db.execute(
        select(
            User.id,
            User.name,
            User.phone,
            func.count(Order.id),
            func.coalesce(func.sum(Order.total).cast(Float), 0.0),
            func.max(Order.created_at),
        )
        .join(Order, Order.user_id == User.id)
        .where(Order.restaurant_id == restaurant.id, Order.created_at >= since, EARNED)
        .group_by(User.id, User.name, User.phone)
        .order_by(func.sum(Order.total).desc())
        .limit(limit)
    ).all()
    return [
        CustomerRow(
            user_id=int(uid),
            name=name,
            phone=phone,
            orders=int(count or 0),
            spent=round(float(spent or 0.0), 2),
            last_order_at=last,
        )
        for uid, name, phone, count, spent, last in rows
    ]
