"""Platform-admin view of the tenants: who runs each restaurant and how it trades.

Every number here is aggregated in SQL. A directory that issues a query per
restaurant looks fine on a seeded laptop and falls over on the real list.
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

from sqlalchemy import Select, case, func, select
from sqlalchemy.orm import Session

from app.models import Order, OrderStatus, Restaurant, User
from app.models.member import RestaurantMember

# Money only counts once the ticket is done and the money actually moved.
_EARNED = (Order.status == OrderStatus.delivered) & (
    (Order.pay_method != "online") | (Order.pay_status == "paid")
)


def _window_start(days: int) -> datetime:
    return datetime.now(UTC).replace(tzinfo=None) - timedelta(days=days)


def _order_stats(days: int) -> Select:
    since = _window_start(days)
    return select(
        Order.restaurant_id.label("restaurant_id"),
        func.count(Order.id).label("orders_total"),
        func.sum(case((Order.created_at >= since, 1), else_=0)).label("orders_window"),
        func.sum(case((_EARNED, Order.total), else_=0.0)).label("revenue_total"),
        func.sum(
            case(((_EARNED) & (Order.created_at >= since), Order.total), else_=0.0)
        ).label("revenue_window"),
        func.max(Order.created_at).label("last_order_at"),
    ).group_by(Order.restaurant_id)


def _owner_rows(db: Session, restaurant_ids: list[int]) -> dict[int, dict]:
    """First active owner per restaurant; falls back to the earliest staff member."""
    if not restaurant_ids:
        return {}
    stmt = (
        select(RestaurantMember.restaurant_id, RestaurantMember.role, User)
        .join(User, User.id == RestaurantMember.user_id)
        .where(
            RestaurantMember.restaurant_id.in_(restaurant_ids),
            RestaurantMember.is_active.is_(True),
        )
        .order_by(
            RestaurantMember.restaurant_id,
            case((RestaurantMember.role == "owner", 0), else_=1),
            RestaurantMember.id,
        )
    )
    out: dict[int, dict] = {}
    for restaurant_id, role, user in db.execute(stmt).all():
        if restaurant_id in out:
            continue
        out[restaurant_id] = {
            "id": user.id,
            "name": user.name,
            "email": user.email,
            "phone": user.phone,
            "role": role,
        }
    return out


def _staff_counts(db: Session, restaurant_ids: list[int]) -> dict[int, int]:
    if not restaurant_ids:
        return {}
    rows = db.execute(
        select(RestaurantMember.restaurant_id, func.count(RestaurantMember.id))
        .where(
            RestaurantMember.restaurant_id.in_(restaurant_ids),
            RestaurantMember.is_active.is_(True),
        )
        .group_by(RestaurantMember.restaurant_id)
    ).all()
    return {rid: n for rid, n in rows}


def directory(db: Session, *, days: int = 30, query: str | None = None) -> list[dict]:
    stats = _order_stats(days).subquery()
    stmt = (
        select(Restaurant, stats)
        .outerjoin(stats, stats.c.restaurant_id == Restaurant.id)
        .order_by(Restaurant.name)
    )
    if query:
        stmt = stmt.where(Restaurant.name.ilike(f"%{query.strip()}%"))

    rows = db.execute(stmt).all()
    restaurants = [row[0] for row in rows]
    ids = [r.id for r in restaurants]
    owners = _owner_rows(db, ids)
    staff = _staff_counts(db, ids)

    out: list[dict] = []
    for row in rows:
        r: Restaurant = row[0]
        m = row._mapping
        out.append(
            {
                "id": r.id,
                "name": r.name,
                "cuisine": r.cuisine,
                "image_url": r.image_url,
                "is_open": r.is_open,
                "plan_code": r.plan_code,
                "billing_status": r.billing_status,
                "rating": r.rating,
                "rating_count": r.rating_count,
                "owner": owners.get(r.id),
                "staff_count": staff.get(r.id, 0),
                "orders_total": int(m.get("orders_total") or 0),
                "orders_window": int(m.get("orders_window") or 0),
                "revenue_total": round(float(m.get("revenue_total") or 0.0), 2),
                "revenue_window": round(float(m.get("revenue_window") or 0.0), 2),
                "last_order_at": m.get("last_order_at"),
                "window_days": days,
            }
        )
    return out


def detail(db: Session, restaurant_id: int, *, days: int = 30) -> dict | None:
    rows = [r for r in directory(db, days=days) if r["id"] == restaurant_id]
    if not rows:
        return None
    card = rows[0]

    staff_stmt = (
        select(RestaurantMember, User)
        .join(User, User.id == RestaurantMember.user_id)
        .where(RestaurantMember.restaurant_id == restaurant_id)
        .order_by(
            case((RestaurantMember.role == "owner", 0), else_=1),
            RestaurantMember.id,
        )
    )
    card["staff"] = [
        {
            "id": user.id,
            "name": user.name,
            "email": user.email,
            "phone": user.phone,
            "role": member.role,
            "is_active": member.is_active,
            "since": member.created_at,
        }
        for member, user in db.execute(staff_stmt).all()
    ]

    recent = db.scalars(
        select(Order)
        .where(Order.restaurant_id == restaurant_id)
        .order_by(Order.created_at.desc(), Order.id.desc())
        .limit(10)
    ).all()
    card["recent_orders"] = [
        {
            "id": o.id,
            "status": o.status.value,
            "channel": o.channel,
            "total": o.total,
            "pay_method": o.pay_method,
            "pay_status": o.pay_status,
            "created_at": o.created_at,
        }
        for o in recent
    ]
    return card


def revenue(db: Session, *, days: int = 30) -> dict:
    """Platform-wide money: what the venues turned over, what the couriers were
    paid out of it, and how it splits by plan.

    `gross` is what customers paid on tickets that actually earned. `payouts` is
    what the platform owes couriers against those same tickets. The difference
    is not profit — commission is not modelled yet — so it is deliberately not
    called that.
    """
    since = _window_start(days)
    window = (Order.created_at >= since) & _EARNED

    totals = db.execute(
        select(
            func.coalesce(func.sum(Order.total), 0.0),
            func.coalesce(func.sum(Order.courier_payout), 0.0),
            func.count(Order.id),
        ).where(window)
    ).one()

    day = func.date(Order.created_at)
    by_day = db.execute(
        select(day, func.count(Order.id), func.coalesce(func.sum(Order.total), 0.0))
        .where(window)
        .group_by(day)
        .order_by(day.desc())
    ).all()

    by_plan = db.execute(
        select(
            Restaurant.plan_code,
            func.count(func.distinct(Restaurant.id)),
            func.coalesce(func.sum(Order.total), 0.0),
        )
        .select_from(Restaurant)
        .join(Order, Order.restaurant_id == Restaurant.id, isouter=True)
        .where((Order.id.is_(None)) | window)
        .group_by(Restaurant.plan_code)
    ).all()

    top = db.execute(
        select(
            Restaurant.id,
            Restaurant.name,
            func.count(Order.id),
            func.coalesce(func.sum(Order.total), 0.0),
        )
        .join(Order, Order.restaurant_id == Restaurant.id)
        .where(window)
        .group_by(Restaurant.id, Restaurant.name)
        .order_by(func.sum(Order.total).desc())
        .limit(10)
    ).all()

    return {
        "days": days,
        "orders": int(totals[2] or 0),
        "gross": round(float(totals[0] or 0.0), 2),
        "courier_payouts": round(float(totals[1] or 0.0), 2),
        "by_day": [
            {"day": str(d), "orders": int(n or 0), "gross": round(float(money or 0.0), 2)}
            for d, n, money in by_day
        ],
        "by_plan": [
            {
                "plan_code": code,
                "restaurants": int(count or 0),
                "gross": round(float(money or 0.0), 2),
            }
            for code, count, money in by_plan
        ],
        "top_restaurants": [
            {
                "id": int(rid),
                "name": name,
                "orders": int(count or 0),
                "gross": round(float(money or 0.0), 2),
            }
            for rid, name, count, money in top
        ],
    }
