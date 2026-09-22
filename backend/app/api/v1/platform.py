"""Platform-level admin: overview, plans, staff, audit. No fake MRR."""

from datetime import datetime

from fastapi import APIRouter, HTTPException, Query, Request, status
from pydantic import BaseModel, EmailStr
from sqlalchemy import func, select

from app.api.deps import DB, AdminUser, CurrentUser
from app.core import audit
from app.core.access import require_restaurant, valid_staff_role
from app.core.features import entitlements, public_plans
from app.models import MenuItem, Order, Restaurant, User
from app.models.audit import AuditLog
from app.models.feature_flag import FeatureOverride
from app.models.floor_plan import Floor
from app.models.member import RestaurantMember

router = APIRouter(tags=["platform"])


class StaffAdd(BaseModel):
    email: EmailStr
    role: str = "manager"


class FeaturePatch(BaseModel):
    key: str
    enabled: bool


@router.get("/billing/plans")
def list_plans() -> list[dict]:
    return public_plans()


@router.get("/platform/overview")
def overview(db: DB, _: AdminUser) -> dict:
    restaurants = db.scalar(select(func.count()).select_from(Restaurant)) or 0
    open_n = db.scalar(select(func.count()).select_from(Restaurant).where(Restaurant.is_open.is_(True))) or 0
    today = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)  # noqa: DTZ005
    orders_today = db.scalar(select(func.count()).select_from(Order).where(Order.created_at >= today)) or 0
    plan_rows = db.execute(select(Restaurant.plan_code, func.count()).group_by(Restaurant.plan_code)).all()
    return {
        "restaurants": restaurants,
        "open": open_n,
        "orders_today": orders_today,
        "plans": {code: n for code, n in plan_rows},
        "billing": "unconfigured",
    }


@router.get("/admin/restaurants/{restaurant_id}/workspace")
def workspace(restaurant_id: int, db: DB, user: CurrentUser) -> dict:
    restaurant = require_restaurant(db, user, restaurant_id, "restaurant.settings.write")
    flags = entitlements(db, restaurant)
    has_menu = (
        db.scalar(select(func.count()).select_from(MenuItem).where(MenuItem.restaurant_id == restaurant_id)) or 0
    )
    has_floor = db.scalar(select(func.count()).select_from(Floor).where(Floor.restaurant_id == restaurant_id)) or 0
    staff_n = (
        db.scalar(
            select(func.count())
            .select_from(RestaurantMember)
            .where(RestaurantMember.restaurant_id == restaurant_id)
        )
        or 0
    )
    return {
        "plan": flags.plan_code,
        "billing_status": restaurant.billing_status,
        "features": sorted(flags.features),
        "limits": flags.limits,
        "setup": {
            "has_menu": has_menu > 0,
            "has_floor": has_floor > 0,
            "is_open": restaurant.is_open,
            "staff": staff_n,
        },
    }


@router.get("/admin/restaurants/{restaurant_id}/staff")
def list_staff(restaurant_id: int, db: DB, user: CurrentUser) -> list[dict]:
    require_restaurant(db, user, restaurant_id, "staff.read")
    rows = db.scalars(select(RestaurantMember).where(RestaurantMember.restaurant_id == restaurant_id))
    out = []
    for m in rows:
        u = db.get(User, m.user_id)
        if not u:
            continue
        out.append(
            {
                "user_id": u.id,
                "email": u.email,
                "name": u.name,
                "role": m.role,
                "is_active": m.is_active,
            }
        )
    return out


@router.post("/admin/restaurants/{restaurant_id}/staff", status_code=status.HTTP_201_CREATED)
def add_staff(restaurant_id: int, data: StaffAdd, db: DB, user: CurrentUser, request: Request) -> dict:
    restaurant = require_restaurant(db, user, restaurant_id, "staff.write")
    if not valid_staff_role(data.role):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Unknown staff role")
    cap = entitlements(db, restaurant).limit("staff.max")
    current = (
        db.scalar(
            select(func.count())
            .select_from(RestaurantMember)
            .where(RestaurantMember.restaurant_id == restaurant_id)
        )
        or 0
    )
    if cap is not None and current >= cap:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, f"Plan allows at most {cap} staff")
    person = db.scalar(select(User).where(User.email == data.email))
    if not person:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "User must register first")
    existing = db.scalar(
        select(RestaurantMember).where(
            RestaurantMember.user_id == person.id,
            RestaurantMember.restaurant_id == restaurant_id,
        )
    )
    if existing:
        existing.role = data.role
        existing.is_active = True
        member = existing
    else:
        member = RestaurantMember(user_id=person.id, restaurant_id=restaurant_id, role=data.role)
        db.add(member)
    audit.record(
        db,
        actor_id=user.id,
        restaurant_id=restaurant_id,
        action="staff.add",
        resource=f"user:{person.id}",
        payload={"role": data.role, "email": person.email},
        request_id=getattr(request.state, "request_id", None),
    )
    db.commit()
    return {"user_id": person.id, "email": person.email, "name": person.name, "role": member.role}


@router.delete("/admin/restaurants/{restaurant_id}/staff/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_staff(restaurant_id: int, user_id: int, db: DB, user: CurrentUser) -> None:
    require_restaurant(db, user, restaurant_id, "staff.write")
    member = db.scalar(
        select(RestaurantMember).where(
            RestaurantMember.user_id == user_id,
            RestaurantMember.restaurant_id == restaurant_id,
        )
    )
    if not member:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Not a member")
    db.delete(member)
    db.commit()


@router.put("/admin/restaurants/{restaurant_id}/features")
def set_feature(restaurant_id: int, data: FeaturePatch, db: DB, _: AdminUser) -> dict:
    """Platform-only: toggle a feature for one restaurant without changing its plan."""
    restaurant = db.get(Restaurant, restaurant_id)
    if not restaurant:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Restaurant not found")
    row = db.scalar(
        select(FeatureOverride).where(
            FeatureOverride.restaurant_id == restaurant_id,
            FeatureOverride.key == data.key,
        )
    )
    if row:
        row.enabled = data.enabled
    else:
        db.add(FeatureOverride(restaurant_id=restaurant_id, key=data.key, enabled=data.enabled))
    db.commit()
    flags = entitlements(db, restaurant)
    return {"key": data.key, "enabled": data.enabled, "features": sorted(flags.features)}


@router.get("/platform/audit")
def list_audit(
    db: DB,
    _: AdminUser,
    restaurant_id: int | None = None,
    limit: int = Query(default=50, ge=1, le=200),
) -> list[dict]:
    stmt = select(AuditLog).order_by(AuditLog.id.desc()).limit(limit)
    if restaurant_id is not None:
        stmt = stmt.where(AuditLog.restaurant_id == restaurant_id)
    rows = list(db.scalars(stmt))
    return [
        {
            "id": r.id,
            "actor_id": r.actor_id,
            "restaurant_id": r.restaurant_id,
            "action": r.action,
            "resource": r.resource,
            "payload": r.payload,
            "request_id": r.request_id,
            "created_at": r.created_at,
        }
        for r in rows
    ]
