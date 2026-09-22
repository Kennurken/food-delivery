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
