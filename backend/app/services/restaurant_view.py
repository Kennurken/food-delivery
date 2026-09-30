from sqlalchemy.orm import Session

from app.core.features import channels_of, entitlements
from app.models import Restaurant
from app.schemas.restaurant import RestaurantDetail, RestaurantOut
from app.services import hours as opening_hours
from app.services import loyalty
from app.services.kitchen_load import load_of


def _load_fields(db: Session, r: Restaurant) -> dict:
    busy = load_of(db, r).overloaded
    by_hours = opening_hours.status_of(r)
    return {
        "kitchen_busy": busy,
        "accepting_orders": bool(r.is_open) and not busy and by_hours.open_now,
        "open_now": by_hours.open_now,
        "opens_at": by_hours.opens_at,
        "loyalty_percent": r.loyalty_percent if loyalty.enabled(db, r) else 0,
    }


def to_out(db: Session, r: Restaurant) -> RestaurantOut:
    flags = entitlements(db, r)
    return RestaurantOut.model_validate(r).model_copy(
        update={
            "channels": _channels(r, flags),
            "reservations": flags.enabled("reservations"),
            **_load_fields(db, r),
            **_city_fields(r),
        }
    )


def to_detail(db: Session, r: Restaurant) -> RestaurantDetail:
    flags = entitlements(db, r)
    return RestaurantDetail.model_validate(r).model_copy(
        update={
            "channels": _channels(r, flags),
            "reservations": flags.enabled("reservations"),
            **_load_fields(db, r),
            **_city_fields(r),
        }
    )


def _channels(r: Restaurant, flags) -> list[str]:
    """What the plan allows, minus delivery for a venue with no couriers."""
    out = channels_of(flags)
    return out if r.offers_delivery else [c for c in out if c != "delivery"]


def _city_fields(r: Restaurant) -> dict:
    city = r.city
    return {
        "city_slug": city.slug if city else None,
        "city_name": city.name if city else None,
    }
