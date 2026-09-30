"""What a courier is owed, and what they are holding.

Two different facts, deliberately kept apart. `earned` is the platform's debt to
the courier. `cash_held` is the courier's debt to the platform: on a cash order
the customer's money went into their pocket at the door. Adding them together
would produce a number that means nothing.

Everything aggregates in SQL — a courier with a thousand deliveries must not
turn this into a thousand row loads.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta

from sqlalchemy import Float, case, func, select
from sqlalchemy.orm import Session

from app.models.order import Order, OrderStatus
from app.models.restaurant import Restaurant
from app.models.user import User

# A delivered cash ticket whose money the courier took and has not handed in.
_HOLDING_CASH = (Order.pay_method == "cash") & (Order.pay_status == "collected")


@dataclass(frozen=True)
class DayRow:
    day: str
    deliveries: int
    earned: float


@dataclass(frozen=True)
class Earnings:
    days: int
    deliveries: int
    earned: float
    cash_held: float
    earned_all_time: float
    deliveries_all_time: int
    by_day: list[DayRow]
    # Average of what diners gave this courier, over every rated delivery.
    rating: float | None = None
    rated: int = 0


@dataclass(frozen=True)
class PayoutRow:
    order_id: int
    restaurant_name: str
    at: datetime  # Order.created_at
    payout: float  # frozen when the ticket closed, see settle_courier_payout
    pay_method: str
    # The ticket's total while it is cash the courier still holds, else 0.
    cash_held: float


def _delivered_by(courier_id: int):
    return (Order.courier_id == courier_id) & (Order.status == OrderStatus.delivered)


def summary(db: Session, courier: User, *, days: int = 7) -> Earnings:
    since = datetime.now() - timedelta(days=days)  # noqa: DTZ005 — rows are naive
    mine = _delivered_by(courier.id)

    window = db.execute(
        select(
            func.count(Order.id),
            func.coalesce(func.sum(Order.courier_payout), 0.0),
        ).where(mine, Order.created_at >= since)
    ).one()

    lifetime = db.execute(
        select(
            func.count(Order.id),
            func.coalesce(func.sum(Order.courier_payout), 0.0),
            # Cash is owed until it is handed in, however old the ticket is, so
            # this one ignores the window on purpose.
            func.coalesce(
                func.sum(case((_HOLDING_CASH, Order.total), else_=0.0).cast(Float)), 0.0
            ),
        ).where(mine)
    ).one()

    rated_avg, rated_n = db.execute(
        select(func.avg(Order.courier_rating), func.count(Order.courier_rating)).where(
            mine, Order.courier_rating.is_not(None)
        )
    ).one()

    day = func.date(Order.created_at)
    rows = db.execute(
        select(day, func.count(Order.id), func.coalesce(func.sum(Order.courier_payout), 0.0))
        .where(mine, Order.created_at >= since)
        .group_by(day)
        .order_by(day.desc())
    ).all()

    return Earnings(
        days=days,
        deliveries=int(window[0] or 0),
        earned=round(float(window[1] or 0.0), 2),
        cash_held=round(float(lifetime[2] or 0.0), 2),
        earned_all_time=round(float(lifetime[1] or 0.0), 2),
        deliveries_all_time=int(lifetime[0] or 0),
        rating=round(float(rated_avg), 2) if rated_avg is not None else None,
        rated=int(rated_n or 0),
        by_day=[
            DayRow(day=str(d), deliveries=int(n or 0), earned=round(float(total or 0.0), 2))
            for d, n, total in rows
        ],
    )


def history(
    db: Session, courier: User, *, limit: int = 20, before: int | None = None
) -> tuple[list[PayoutRow], int | None]:
    """Newest first. Keyset-paged on order id (`before` = the last id of the
    previous page), so a page is stable while new deliveries land."""
    mine = _delivered_by(courier.id)

    stmt = (
        select(
            Order.id,
            Order.created_at,
            Order.courier_payout,
            Order.pay_method,
            case((_HOLDING_CASH, Order.total), else_=0.0).cast(Float).label("cash_held"),
            Restaurant.name.label("restaurant_name"),
        )
        .join(Restaurant, Restaurant.id == Order.restaurant_id)
        .where(mine)
        .order_by(Order.id.desc())
        .limit(limit + 1)
    )
    if before is not None:
        stmt = stmt.where(Order.id < before)

    rows = db.execute(stmt).all()

    items: list[PayoutRow] = []
    for row in rows[:limit]:
        items.append(
            PayoutRow(
                order_id=row.id,
                restaurant_name=row.restaurant_name,
                at=row.created_at,
                payout=round(float(row.courier_payout or 0.0), 2),
                pay_method=row.pay_method,
                cash_held=round(float(row.cash_held or 0.0), 2),
            )
        )

    next_before = items[-1].order_id if len(rows) > limit else None
    return items, next_before
