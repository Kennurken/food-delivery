"""Admin-only management endpoints. Order status changes live in orders.py (PATCH /status)."""

from fastapi import APIRouter, HTTPException, Request, status
from sqlalchemy import select

from app.api.deps import DB, AdminUser
from app.core import audit
from app.core.features import DEFAULT_PLAN, PLANS, entitlements
from app.models import MenuItem, ModifierGroup, ModifierOption, Promo, Restaurant
from app.schemas.admin import (
    MenuItemCreate,
    MenuItemUpdate,
    ModifierGroupIn,
    PromoCreate,
    PromoOut,
    PromoUpdate,
    RestaurantCreate,
    RestaurantUpdate,
)
from app.schemas.restaurant import MenuItemOut, RestaurantDetail, RestaurantOut
from app.services.restaurant_view import to_detail, to_out

router = APIRouter(prefix="/admin", tags=["admin"])

_BILLING = frozenset(
    {"trial", "active", "past_due", "grace_period", "suspended", "cancelled", "expired"}
)


def _restaurant_or_404(db, restaurant_id: int) -> Restaurant:
    r = db.get(Restaurant, restaurant_id)
    if not r:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Restaurant not found")
    return r


@router.post("/restaurants", response_model=RestaurantOut, status_code=status.HTTP_201_CREATED)
def create_restaurant(
    data: RestaurantCreate, db: DB, user: AdminUser, request: Request
) -> RestaurantOut:
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
    return to_out(db, r)


@router.get("/restaurants", response_model=list[RestaurantOut])
def all_restaurants(db: DB, _: AdminUser) -> list[RestaurantOut]:
    """Includes closed restaurants (public listing hides them)."""
    return [to_out(db, r) for r in db.scalars(select(Restaurant).order_by(Restaurant.name))]


@router.get("/restaurants/{restaurant_id}", response_model=RestaurantDetail)
def restaurant_detail(restaurant_id: int, db: DB, _: AdminUser) -> RestaurantDetail:
    return to_detail(db, _restaurant_or_404(db, restaurant_id))


@router.patch("/restaurants/{restaurant_id}", response_model=RestaurantOut)
def update_restaurant(
    restaurant_id: int, data: RestaurantUpdate, db: DB, user: AdminUser, request: Request
) -> RestaurantOut:
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
    return to_out(db, r)


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


@router.put("/menu/{item_id}/modifiers", response_model=MenuItemOut)
def replace_modifiers(item_id: int, data: list[ModifierGroupIn], db: DB, _: AdminUser) -> MenuItem:
    item = db.get(MenuItem, item_id)
    if not item:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Menu item not found")
    item.modifier_groups.clear()
    db.flush()
    for group in data:
        if group.min_select > group.max_select:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "min_select > max_select")
        g = ModifierGroup(
            menu_item_id=item.id,
            name=group.name,
            required=group.required,
            min_select=group.min_select,
            max_select=group.max_select,
        )
        g.options = [
            ModifierOption(
                name=opt.name,
                price_delta=opt.price_delta,
                is_default=opt.is_default,
                is_available=opt.is_available,
            )
            for opt in group.options
        ]
        item.modifier_groups.append(g)
    db.commit()
    db.refresh(item)
    return item


def _promo_code(raw: str) -> str:
    from app.services.promo import normalize_code

    code = normalize_code(raw)
    if len(code) < 3:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Promo code is too short")
    return code


def _validate_promo(kind: str, value: float) -> None:
    if kind == "percent" and not 1 <= value <= 90:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Percent must be 1–90")


def _require_promos(db, restaurant: Restaurant) -> None:
    if not entitlements(db, restaurant).enabled("promotions"):
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Promotions are not on this plan")


@router.get("/restaurants/{restaurant_id}/promos", response_model=list[PromoOut])
def list_promos(restaurant_id: int, db: DB, _: AdminUser) -> list[Promo]:
    _restaurant_or_404(db, restaurant_id)
    return list(db.scalars(select(Promo).where(Promo.restaurant_id == restaurant_id)))


@router.post(
    "/restaurants/{restaurant_id}/promos",
    response_model=PromoOut,
    status_code=status.HTTP_201_CREATED,
)
def create_promo(restaurant_id: int, data: PromoCreate, db: DB, _: AdminUser) -> Promo:
    restaurant = _restaurant_or_404(db, restaurant_id)
    _require_promos(db, restaurant)
    code = _promo_code(data.code)
    _validate_promo(data.kind, data.value)
    if db.scalar(select(Promo).where(Promo.restaurant_id == restaurant_id, Promo.code == code)):
        raise HTTPException(status.HTTP_409_CONFLICT, "Promo already exists")
    row = Promo(
        restaurant_id=restaurant_id,
        code=code,
        kind=data.kind,
        value=data.value,
        min_subtotal=data.min_subtotal,
        max_uses=data.max_uses,
        is_active=data.is_active,
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


@router.patch("/promos/{promo_id}", response_model=PromoOut)
def update_promo(promo_id: int, data: PromoUpdate, db: DB, _: AdminUser) -> Promo:
    row = db.get(Promo, promo_id)
    if not row:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Promo not found")
    _require_promos(db, row.restaurant)
    updates = data.model_dump(exclude_unset=True)
    kind = updates.get("kind", row.kind)
    value = updates.get("value", row.value)
    _validate_promo(kind, value)
    for k, v in updates.items():
        setattr(row, k, v)
    db.commit()
    db.refresh(row)
    return row


@router.delete("/promos/{promo_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_promo(promo_id: int, db: DB, _: AdminUser) -> None:
    row = db.get(Promo, promo_id)
    if not row:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Promo not found")
    _require_promos(db, row.restaurant)
    db.delete(row)
    db.commit()
