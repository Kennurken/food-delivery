"""Admin-only management endpoints. Order status changes live in orders.py (PATCH /status)."""

from datetime import datetime

from fastapi import APIRouter, HTTPException, Query, Request, status
from pydantic import BaseModel, Field, model_validator
from sqlalchemy import select

from app.api.deps import DB, AdminUser, CurrentUser
from app.core import audit
from app.core.access import require_restaurant
from app.core.features import DEFAULT_PLAN, PLANS, entitlements
from app.models import (
    MenuItem,
    ModifierGroup,
    ModifierOption,
    Offer,
    Promo,
    Restaurant,
    UserRole,
)
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
from app.services import restaurant_stats as restaurant_stats_service
from app.services.restaurant_view import to_detail, to_out
from app.services.slugs import unique_slug

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
    # Without this the venue has no public page and never reaches the sitemap:
    # it would exist in the app and be invisible on the site.
    r.slug = unique_slug(db, Restaurant, r.name, skip_id=r.id)
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
def create_menu_item(
    restaurant_id: int, data: MenuItemCreate, db: DB, user: CurrentUser
) -> MenuItem:
    require_restaurant(db, user, restaurant_id, "menu.write")
    item = MenuItem(restaurant_id=restaurant_id, **data.model_dump())
    db.add(item)
    db.commit()
    db.refresh(item)
    return item


@router.patch("/menu/{item_id}", response_model=MenuItemOut)
def update_menu_item(
    item_id: int, data: MenuItemUpdate, db: DB, user: CurrentUser
) -> MenuItem:
    item = db.get(MenuItem, item_id)
    if not item:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Menu item not found")
    fields = data.model_dump(exclude_unset=True)
    # Stopping a dish is a shift action; changing its price or name is not.
    # Someone with only the former must not be able to smuggle the latter in.
    needed = "menu.availability" if set(fields) <= {"is_available"} else "menu.write"
    require_restaurant(db, user, item.restaurant_id, needed)
    for k, v in fields.items():
        setattr(item, k, v)
    db.commit()
    db.refresh(item)
    return item


@router.delete("/menu/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_menu_item(item_id: int, db: DB, user: CurrentUser) -> None:
    item = db.get(MenuItem, item_id)
    if not item:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Menu item not found")
    require_restaurant(db, user, item.restaurant_id, "menu.write")
    db.delete(item)
    db.commit()


@router.put("/menu/{item_id}/modifiers", response_model=MenuItemOut)
def replace_modifiers(
    item_id: int, data: list[ModifierGroupIn], db: DB, user: CurrentUser
) -> MenuItem:
    item = db.get(MenuItem, item_id)
    if not item:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Menu item not found")
    require_restaurant(db, user, item.restaurant_id, "menu.write")
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


@router.get("/restaurants/{restaurant_id}/stats")
def restaurant_stats(
    restaurant_id: int, db: DB, user: CurrentUser, days: int = Query(30, ge=1, le=365)
) -> dict:
    """Own-venue numbers. The requested window is clamped to what the plan buys
    rather than refused — a Basic owner asking for a year gets their week, not
    an error they can do nothing about."""
    restaurant = require_restaurant(db, user, restaurant_id, "analytics.read")
    flags = entitlements(db, restaurant)
    data = restaurant_stats_service.summary(db, restaurant, days=days, flags=flags)
    return {
        "days": data.days,
        "window_limit": data.window_limit,
        "orders": data.orders,
        "revenue": data.revenue,
        "average_check": data.average_check,
        "cancelled": data.cancelled,
        "cancel_rate": data.cancel_rate,
        "by_day": [
            {"day": row.day, "orders": row.orders, "revenue": row.revenue} for row in data.by_day
        ],
        "top_dishes": [
            {"name": row.name, "quantity": row.quantity, "revenue": row.revenue}
            for row in data.top_dishes
        ],
        "by_channel": data.by_channel,
        "by_pay_method": data.by_pay_method,
    }


@router.get("/restaurants/{restaurant_id}/customers")
def restaurant_customers(
    restaurant_id: int, db: DB, user: CurrentUser, days: int = Query(90, ge=1, le=365)
) -> dict:
    restaurant = require_restaurant(db, user, restaurant_id, "analytics.read")
    flags = entitlements(db, restaurant)
    rows = restaurant_stats_service.customers(db, restaurant, days=days, flags=flags)
    return {
        "days": restaurant_stats_service.clamp_days(days, flags),
        "customers": [
            {
                "user_id": row.user_id,
                "name": row.name,
                "phone": row.phone,
                "orders": row.orders,
                "spent": row.spent,
                "last_order_at": row.last_order_at.isoformat() if row.last_order_at else None,
            }
            for row in rows
        ],
    }


class StopListIn(BaseModel):
    item_ids: list[int] = Field(min_length=1, max_length=200)
    available: bool


@router.get("/restaurants/{restaurant_id}/stop-list", response_model=list[MenuItemOut])
def stop_list(restaurant_id: int, db: DB, user: CurrentUser) -> list[MenuItem]:
    """Everything currently off sale. A shift starts by looking at this."""
    require_restaurant(db, user, restaurant_id, "menu.read")
    return list(
        db.scalars(
            select(MenuItem)
            .where(MenuItem.restaurant_id == restaurant_id, MenuItem.is_available.is_(False))
            .order_by(MenuItem.category, MenuItem.name)
        )
    )


@router.post("/restaurants/{restaurant_id}/stop-list", response_model=list[MenuItemOut])
def set_availability(
    restaurant_id: int, data: StopListIn, db: DB, user: CurrentUser
) -> list[MenuItem]:
    """Stop or restore several dishes at once.

    Bringing a menu back one dish at a time at the start of every shift is how
    a dish stays off by accident for a week.
    """
    require_restaurant(db, user, restaurant_id, "menu.availability")
    items = list(
        db.scalars(
            select(MenuItem).where(
                MenuItem.id.in_(data.item_ids),
                # Scoped to this restaurant: an id from someone else's menu is
                # simply not found here, never silently flipped.
                MenuItem.restaurant_id == restaurant_id,
            )
        )
    )
    for item in items:
        item.is_available = data.available
    db.commit()
    for item in items:
        db.refresh(item)
    return items


class OfferIn(BaseModel):
    title: str = Field(min_length=1, max_length=160)
    subtitle: str = Field(default="", max_length=300)
    body: str = ""
    image_url: str | None = Field(default=None, max_length=500)
    promo_code: str | None = Field(default=None, max_length=24)
    starts_at: datetime | None = None
    ends_at: datetime | None = None
    is_active: bool = True
    sort_order: int = 0

    @model_validator(mode="after")
    def _period(self) -> "OfferIn":
        if self.starts_at and self.ends_at and self.ends_at < self.starts_at:
            raise ValueError("A campaign cannot end before it starts")
        return self


class OfferPatch(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=160)
    subtitle: str | None = Field(default=None, max_length=300)
    body: str | None = None
    image_url: str | None = Field(default=None, max_length=500)
    promo_code: str | None = Field(default=None, max_length=24)
    starts_at: datetime | None = None
    ends_at: datetime | None = None
    is_active: bool | None = None
    sort_order: int | None = None


def _offer_out(offer: Offer) -> dict:
    return {
        "id": offer.id,
        "restaurant_id": offer.restaurant_id,
        "slug": offer.slug,
        "title": offer.title,
        "subtitle": offer.subtitle,
        "body": offer.body,
        "image_url": offer.image_url,
        "promo_code": offer.promo_code,
        "starts_at": offer.starts_at.isoformat() if offer.starts_at else None,
        "ends_at": offer.ends_at.isoformat() if offer.ends_at else None,
        "is_active": offer.is_active,
        "sort_order": offer.sort_order,
        "url": f"/actions/{offer.slug}",
    }


@router.get("/restaurants/{restaurant_id}/offers")
def list_offers(restaurant_id: int, db: DB, user: CurrentUser) -> list[dict]:
    """Every campaign of this venue, running or not — this is the editor."""
    require_restaurant(db, user, restaurant_id, "menu.read")
    rows = db.scalars(
        select(Offer)
        .where(Offer.restaurant_id == restaurant_id)
        .order_by(Offer.sort_order.desc(), Offer.id.desc())
    )
    return [_offer_out(o) for o in rows]


@router.post(
    "/restaurants/{restaurant_id}/offers", status_code=status.HTTP_201_CREATED
)
def create_offer(
    restaurant_id: int, data: OfferIn, db: DB, user: CurrentUser
) -> dict:
    require_restaurant(db, user, restaurant_id, "menu.write")
    fields = data.model_dump()
    # Before the insert, not after: the column is NOT NULL, so a slug assigned
    # post-flush never reaches the row. Assigned once and never rewritten by a
    # later retitling — it is what search engines and shared links hold on to.
    offer = Offer(
        restaurant_id=restaurant_id,
        slug=unique_slug(db, Offer, fields["title"]),
        **fields,
    )
    db.add(offer)
    db.commit()
    db.refresh(offer)
    return _offer_out(offer)


@router.patch("/offers/{offer_id}")
def update_offer(offer_id: int, data: OfferPatch, db: DB, user: CurrentUser) -> dict:
    offer = db.get(Offer, offer_id)
    if offer is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Offer not found")
    if offer.restaurant_id is not None:
        require_restaurant(db, user, offer.restaurant_id, "menu.write")
    elif user.role != UserRole.admin:
        # A platform-wide campaign belongs to nobody's venue.
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Platform campaign")
    fields = data.model_dump(exclude_unset=True)
    starts = fields.get("starts_at", offer.starts_at)
    ends = fields.get("ends_at", offer.ends_at)
    if starts and ends and ends < starts:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST, "A campaign cannot end before it starts"
        )
    for key, value in fields.items():
        setattr(offer, key, value)
    db.commit()
    db.refresh(offer)
    return _offer_out(offer)


@router.delete("/offers/{offer_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_offer(offer_id: int, db: DB, user: CurrentUser) -> None:
    offer = db.get(Offer, offer_id)
    if offer is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Offer not found")
    if offer.restaurant_id is not None:
        require_restaurant(db, user, offer.restaurant_id, "menu.write")
    elif user.role != UserRole.admin:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Platform campaign")
    db.delete(offer)
    db.commit()
