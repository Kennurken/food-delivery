from sqlalchemy.orm import Session

from app.core.features import channels_of, entitlements
from app.models import Restaurant
from app.schemas.restaurant import RestaurantDetail, RestaurantOut
from app.services.kitchen_load import load_of


def _load_fields(db: Session, r: Restaurant) -> dict:
    busy = load_of(db, r).overloaded
    return {"kitchen_busy": busy, "accepting_orders": bool(r.is_open) and not busy}


def to_out(db: Session, r: Restaurant) -> RestaurantOut:
    flags = entitlements(db, r)
    return RestaurantOut.model_validate(r).model_copy(
        update={
            "channels": channels_of(flags),
            "reservations": flags.enabled("reservations"),
            **_load_fields(db, r),
        }
    )


def to_detail(db: Session, r: Restaurant) -> RestaurantDetail:
    flags = entitlements(db, r)
    return RestaurantDetail.model_validate(r).model_copy(
        update={
            "channels": channels_of(flags),
            "reservations": flags.enabled("reservations"),
            **_load_fields(db, r),
        }
    )
