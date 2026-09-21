from fastapi import APIRouter, HTTPException, Query, status
from sqlalchemy import select

from app.api.deps import DB
from app.models import MenuItem, Restaurant
from app.schemas.restaurant import MenuItemOut, RestaurantDetail, RestaurantOut

router = APIRouter(prefix="/restaurants", tags=["restaurants"])


@router.get("", response_model=list[RestaurantOut])
def list_restaurants(
    db: DB,
    cuisine: str | None = None,
    q: str | None = Query(default=None, min_length=1),
) -> list[Restaurant]:
    stmt = select(Restaurant).where(Restaurant.is_open.is_(True))
    if cuisine:
        stmt = stmt.where(Restaurant.cuisine == cuisine)
    if q:
        stmt = stmt.where(Restaurant.name.ilike(f"%{q}%"))
    return list(db.scalars(stmt.order_by(Restaurant.rating.desc())))


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
