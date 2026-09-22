"""Admin-only management endpoints. Order status changes live in orders.py (PATCH /status)."""

from fastapi import APIRouter, HTTPException, Request, status
from sqlalchemy import select

from app.api.deps import DB, AdminUser
from app.core import audit
from app.core.features import DEFAULT_PLAN, PLANS
from app.models import MenuItem, Restaurant
from app.schemas.admin import MenuItemCreate, MenuItemUpdate, RestaurantCreate, RestaurantUpdate
from app.schemas.restaurant import MenuItemOut, RestaurantDetail, RestaurantOut

router = APIRouter(prefix="/admin", tags=["admin"])

_BILLING = frozenset({"trial", "active", "past_due", "grace_period", "suspended", "cancelled", "expired"})


def _restaurant_or_404(db, restaurant_id: int) -> Restaurant:
    r = db.get(Restaurant, restaurant_id)
    if not r:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Restaurant not found")
    return r


@router.post("/restaurants", response_model=RestaurantOut, status_code=status.HTTP_201_CREATED)
def create_restaurant(data: RestaurantCreate, db: DB, user: AdminUser, request: Request) -> Restaurant:
    payload = data.model_dump()
    r = Restaurant(**payload, plan_code=DEFAULT_PLAN)
    db.add(r)
    db.flush()
    audit.record(
        db,
        actor_id=user.id,
        restaurant_id=r.id,
        action="restaurant.create",
        resource=f"restaurant:{r.id}",
        payload={"name": r.name},
        request_id=getattr(request.state, "request_id", None),
    )
    db.commit()
    db.refresh(r)
    return r


@router.get("/restaurants", response_model=list[RestaurantOut])
def all_restaurants(db: DB, _: AdminUser) -> list[Restaurant]:
    """Includes closed restaurants (public listing hides them)."""
    return list(db.scalars(select(Restaurant).order_by(Restaurant.name)))


@router.get("/restaurants/{restaurant_id}", response_model=RestaurantDetail)
def restaurant_detail(restaurant_id: int, db: DB, _: AdminUser) -> Restaurant:
    return _restaurant_or_404(db, restaurant_id)


@router.patch("/restaurants/{restaurant_id}", response_model=RestaurantOut)
def update_restaurant(
    restaurant_id: int, data: RestaurantUpdate, db: DB, user: AdminUser, request: Request
) -> Restaurant:
    r = _restaurant_or_404(db, restaurant_id)
    updates = data.model_dump(exclude_unset=True)
    if "plan_code" in updates:
        if updates["plan_code"] not in PLANS:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "Unknown plan")
        audit.record(
            db,
            actor_id=user.id,
            restaurant_id=r.id,
            action="subscription.change",
            resource=f"restaurant:{r.id}",
            payload={"from": r.plan_code, "to": updates["plan_code"]},
            request_id=getattr(request.state, "request_id", None),
        )
    if "billing_status" in updates and updates["billing_status"] not in _BILLING:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Unknown billing status")
    for k, v in updates.items():
        setattr(r, k, v)
    db.commit()
    db.refresh(r)
    return r


@router.post(
    "/restaurants/{restaurant_id}/menu",
    response_model=MenuItemOut,
    status_code=status.HTTP_201_CREATED,
)
def create_menu_item(restaurant_id: int, data: MenuItemCreate, db: DB, _: AdminUser) -> MenuItem:
    _restaurant_or_404(db, restaurant_id)
    item = MenuItem(restaurant_id=restaurant_id, **data.model_dump())
    db.add(item)
    db.commit()
    db.refresh(item)
    return item


@router.patch("/menu/{item_id}", response_model=MenuItemOut)
def update_menu_item(item_id: int, data: MenuItemUpdate, db: DB, _: AdminUser) -> MenuItem:
    item = db.get(MenuItem, item_id)
    if not item:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Menu item not found")
    for k, v in data.model_dump(exclude_unset=True).items():
        setattr(item, k, v)
    db.commit()
    db.refresh(item)
    return item


@router.delete("/menu/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_menu_item(item_id: int, db: DB, _: AdminUser) -> None:
    item = db.get(MenuItem, item_id)
    if not item:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Menu item not found")
    db.delete(item)
    db.commit()
