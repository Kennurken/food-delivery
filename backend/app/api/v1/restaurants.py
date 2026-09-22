from fastapi import APIRouter, HTTPException, Query, status
from sqlalchemy import exists, or_, select

from app.api.deps import DB
from app.models import MenuItem, Restaurant
from app.schemas.admin import PromoQuote
from app.schemas.reservation import TableOut
from app.schemas.restaurant import MenuItemOut, RestaurantDetail, RestaurantOut
from app.services import reservation as reserve_service
from app.services.promo import quote as quote_promo
from app.services.restaurant_view import to_detail, to_out

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
) -> list[RestaurantOut]:
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
    return [to_out(db, r) for r in db.scalars(stmt.order_by(_order(sort), Restaurant.id))]


@router.get("/cuisines", response_model=list[str])
def list_cuisines(db: DB) -> list[str]:
    stmt = (
        select(Restaurant.cuisine)
        .where(Restaurant.is_open.is_(True))
        .distinct()
        .order_by(Restaurant.cuisine)
    )
    return list(db.scalars(stmt))


@router.get("/{restaurant_id}", response_model=RestaurantDetail)
def get_restaurant(restaurant_id: int, db: DB) -> RestaurantDetail:
    r = db.get(Restaurant, restaurant_id)
    if not r:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Restaurant not found")
    return to_detail(db, r)


@router.get("/{restaurant_id}/menu", response_model=list[MenuItemOut])
def get_menu(restaurant_id: int, db: DB) -> list[MenuItem]:
    if not db.get(Restaurant, restaurant_id):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Restaurant not found")
    return list(db.scalars(select(MenuItem).where(MenuItem.restaurant_id == restaurant_id)))


@router.get("/{restaurant_id}/promo", response_model=PromoQuote)
def preview_promo(
    restaurant_id: int,
    db: DB,
    code: str = Query(min_length=3, max_length=24),
    subtotal: float = Query(gt=0),
) -> PromoQuote:
    restaurant = db.get(Restaurant, restaurant_id)
    if not restaurant:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Restaurant not found")
    promo, discount = quote_promo(db, restaurant, code, subtotal)
    return PromoQuote(
        code=promo.code,
        kind=promo.kind,
        value=promo.value,
        min_subtotal=promo.min_subtotal,
        discount=discount,
    )


@router.get("/{restaurant_id}/tables", response_model=list[TableOut])
def list_tables(restaurant_id: int, db: DB) -> list[dict]:
    restaurant = db.get(Restaurant, restaurant_id)
    if not restaurant:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Restaurant not found")
    return reserve_service.list_tables(db, restaurant)
