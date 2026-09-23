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
        by_day=[
            DayRow(day=str(d), deliveries=int(n or 0), earned=round(float(total or 0.0), 2))
            for d, n, total in rows
        ],
    )
