from fastapi import APIRouter, HTTPException, Query, status
from sqlalchemy import exists, or_, select

from app.api.deps import DB
from app.models import MenuItem, Restaurant
from app.schemas.restaurant import MenuItemOut, RestaurantDetail, RestaurantOut

router = APIRouter(prefix="/restaurants", tags=["restaurants"])


def _order(sort: str):
    return {
        "rating": Restaurant.rating.desc(),
        "eta": Restaurant.delivery_time_min.asc(),
        "fee": Restaurant.delivery_fee.asc(),
    }[sort]


@router.get("", response_model=list[RestaurantOut])
def list_restaurants(
    db: DB,
    cuisine: str | None = None,
    q: str | None = Query(default=None, min_length=1),
    sort: str = Query(default="rating", pattern="^(rating|eta|fee)$"),
) -> list[Restaurant]:
    stmt = select(Restaurant).where(Restaurant.is_open.is_(True))
    if cuisine:
        stmt = stmt.where(Restaurant.cuisine == cuisine)
    if q:
        like = f"%{q}%"
        stmt = stmt.where(
            or_(
                Restaurant.name.ilike(like),
                Restaurant.cuisine.ilike(like),
                exists().where(MenuItem.restaurant_id == Restaurant.id, MenuItem.name.ilike(like)),
            )
        )
    return list(db.scalars(stmt.order_by(_order(sort), Restaurant.id)))


@router.get("/cuisines", response_model=list[str])
def list_cuisines(db: DB) -> list[str]:
    stmt = select(Restaurant.cuisine).where(Restaurant.is_open.is_(True)).distinct().order_by(Restaurant.cuisine)
    return list(db.scalars(stmt))


@router.get("/{restaurant_id}", response_model=RestaurantDetail)
def get_restaurant(restaurant_id: int, db: DB) -> Restaurant:
    r = db.get(Restaurant, restaurant_id)
    if not r:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Restaurant not found")
    return r


@router.get("/{restaurant_id}/menu", response_model=list[MenuItemOut])
def get_menu(restaurant_id: int, db: DB) -> list[MenuItem]:
    if not db.get(Restaurant, restaurant_id):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Restaurant not found")
    return list(db.scalars(select(MenuItem).where(MenuItem.restaurant_id == restaurant_id)))
