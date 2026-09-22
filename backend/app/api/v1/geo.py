from datetime import datetime

from fastapi import APIRouter, Query, Request
from pydantic import BaseModel, Field
from sqlalchemy import select

from app.api.deps import DB, CourierUser
from app.core.geo import lang_for, provider, valid_coord
from app.core.ratelimit import limiter
from app.models import Order, OrderStatus
from app.services import order_service

router = APIRouter(tags=["geo"])


class PlaceOut(BaseModel):
    lat: float
    lng: float
    line: str
    subtitle: str = ""


class RouteOut(BaseModel):
    distance_m: float
    duration_s: float
    points: list[PlaceOut]


class LocationPing(BaseModel):
    lat: float = Field(ge=-90, le=90)
    lng: float = Field(ge=-180, le=180)
    heading: float | None = Field(default=None, ge=0, le=360)


def _place(p) -> PlaceOut:
    return PlaceOut(lat=p.lat, lng=p.lng, line=p.line, subtitle=p.subtitle)


@router.get("/geo/search", response_model=list[PlaceOut])
@limiter.limit("40/minute")
def search_places(
    request: Request,
    q: str = Query(min_length=2, max_length=200),
    lat: float | None = None,
    lng: float | None = None,
    lang: str | None = None,
) -> list[PlaceOut]:
    near_lat, near_lng = (lat, lng) if valid_coord(lat, lng) else (None, None)
    hits = provider().search(q, lat=near_lat, lng=near_lng, lang=lang_for(lang))
    return [_place(p) for p in hits]


@router.get("/geo/reverse", response_model=PlaceOut | None)
@limiter.limit("60/minute")
def reverse_geocode(
    request: Request,
    lat: float = Query(ge=-90, le=90),
    lng: float = Query(ge=-180, le=180),
    lang: str | None = None,
) -> PlaceOut | None:
    hit = provider().reverse(lat, lng, lang=lang_for(lang))
    return None if hit is None else _place(hit)


@router.get("/geo/route", response_model=RouteOut)
@limiter.limit("30/minute")
def driving_route(
    request: Request,
    from_lat: float = Query(ge=-90, le=90),
    from_lng: float = Query(ge=-180, le=180),
    to_lat: float = Query(ge=-90, le=90),
    to_lng: float = Query(ge=-180, le=180),
) -> RouteOut:
    route = provider().route((from_lat, from_lng), (to_lat, to_lng))
    return RouteOut(
        distance_m=route.distance_m,
        duration_s=route.duration_s,
        points=[PlaceOut(lat=lat, lng=lng, line="") for lat, lng in route.points],
    )


@router.post("/courier/location", status_code=204)
@limiter.limit("90/minute")
def ping_location(request: Request, data: LocationPing, db: DB, courier: CourierUser) -> None:
    courier.last_lat = data.lat
    courier.last_lng = data.lng
    courier.last_heading = data.heading
    courier.last_seen_at = datetime.utcnow()  # noqa: DTZ003
    db.commit()
    active = list(
        db.scalars(
            select(Order).where(
                Order.courier_id == courier.id,
                Order.status.in_(
                    {OrderStatus.confirmed, OrderStatus.preparing, OrderStatus.on_the_way}
                ),
            )
        )
    )
    for order in active:
        order.courier = courier
        order_service.notify(db, order, cause="location")
