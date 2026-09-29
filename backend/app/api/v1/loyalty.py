"""Bonus balances for diners, and the programme settings for a venue."""

from fastapi import APIRouter, HTTPException, Query, Request, status
from pydantic import BaseModel, Field
from sqlalchemy import func, select

from app.api.deps import DB, CurrentUser
from app.core import audit
from app.core.access import require_restaurant
from app.core.features import entitlements
from app.models import LoyaltyEntry, Restaurant
from app.services import loyalty

router = APIRouter(tags=["loyalty"])


class LoyaltySettings(BaseModel):
    # Share of paid food returned as bonuses. 30 % is already generous; more is
    # a typo, not a strategy.
    percent: float = Field(ge=0, le=30)
    max_share: float = Field(default=0.5, ge=0, le=1)


@router.get("/me/loyalty")
def my_balances(db: DB, user: CurrentUser) -> list[dict]:
    """Every venue where this diner holds bonuses."""
    rows = db.execute(
        select(LoyaltyEntry.restaurant_id, Restaurant.name, func.sum(LoyaltyEntry.amount))
        .join(Restaurant, Restaurant.id == LoyaltyEntry.restaurant_id)
        .where(LoyaltyEntry.user_id == user.id)
        .group_by(LoyaltyEntry.restaurant_id, Restaurant.name)
        .having(func.sum(LoyaltyEntry.amount) > 0)
        .order_by(Restaurant.name)
    ).all()
    return [
        {"restaurant_id": rid, "restaurant_name": name, "balance": round(float(total), 2)}
        for rid, name, total in rows
    ]


@router.get("/me/loyalty/{restaurant_id}")
def my_balance(
    restaurant_id: int,
    db: DB,
    user: CurrentUser,
    subtotal: float | None = Query(default=None, ge=0),
) -> dict:
    """What the cart needs: the balance, the rate, and — given the food total
    after any promo — how much of it this order could use."""
    restaurant = db.get(Restaurant, restaurant_id)
    if restaurant is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Restaurant not found")
    held = 0.0 if user.is_guest else loyalty.balance(db, user.id, restaurant.id)
    return {
        "balance": held,
        "percent": restaurant.loyalty_percent if loyalty.enabled(db, restaurant) else 0,
        "max_share": restaurant.loyalty_max_share,
        "usable": None if subtotal is None else loyalty.max_spend(restaurant, subtotal, held),
    }


@router.put("/admin/restaurants/{restaurant_id}/loyalty")
def set_programme(
    restaurant_id: int,
    body: LoyaltySettings,
    db: DB,
    user: CurrentUser,
    request: Request,
) -> dict:
    restaurant = require_restaurant(db, user, restaurant_id, "restaurant.settings.write")
    if body.percent > 0 and not entitlements(db, restaurant).enabled("loyalty"):
        # Switching it off is always allowed; switching it on is what Premium sells.
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Bonus programme is a Premium feature")
    restaurant.loyalty_percent = body.percent
    restaurant.loyalty_max_share = body.max_share
    audit.record(
        db,
        actor_id=user.id,
        restaurant_id=restaurant.id,
        action="restaurant.loyalty",
        resource=f"restaurant:{restaurant.id}",
        payload={"percent": body.percent, "max_share": body.max_share},
        request_id=getattr(request.state, "request_id", None),
    )
    db.commit()
    return {
        "percent": restaurant.loyalty_percent,
        "max_share": restaurant.loyalty_max_share,
        "active": loyalty.enabled(db, restaurant),
    }
