"""Admin-only management endpoints. Order status changes live in orders.py (PATCH /status)."""

from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select

from app.api.deps import DB, AdminUser
from app.models import MenuItem, Restaurant
from app.schemas.admin import MenuItemCreate, MenuItemUpdate, RestaurantUpdate
from app.schemas.restaurant import MenuItemOut, RestaurantDetail, RestaurantOut

router = APIRouter(prefix="/admin", tags=["admin"])


def _restaurant_or_404(db, restaurant_id: int) -> Restaurant:
    r = db.get(Restaurant, restaurant_id)
    if not r:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Restaurant not found")
    return r


@router.get("/restaurants", response_model=list[RestaurantOut])
def all_restaurants(db: DB, _: AdminUser) -> list[Restaurant]:
    """Includes closed restaurants (public listing hides them)."""
    return list(db.scalars(select(Restaurant).order_by(Restaurant.name)))


@router.get("/restaurants/{restaurant_id}", response_model=RestaurantDetail)
def restaurant_detail(restaurant_id: int, db: DB, _: AdminUser) -> Restaurant:
    return _restaurant_or_404(db, restaurant_id)


@router.patch("/restaurants/{restaurant_id}", response_model=RestaurantOut)
def update_restaurant(restaurant_id: int, data: RestaurantUpdate, db: DB, _: AdminUser) -> Restaurant:
    r = _restaurant_or_404(db, restaurant_id)
    for k, v in data.model_dump(exclude_unset=True).items():
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
