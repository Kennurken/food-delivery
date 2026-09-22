from sqlalchemy.orm import Session

from app.core.features import channels_of, entitlements
from app.models import Restaurant
from app.schemas.restaurant import RestaurantDetail, RestaurantOut


def to_out(db: Session, r: Restaurant) -> RestaurantOut:
    flags = entitlements(db, r)
    return RestaurantOut.model_validate(r).model_copy(
        update={"channels": channels_of(flags), "reservations": flags.enabled("reservations")}
    )


def to_detail(db: Session, r: Restaurant) -> RestaurantDetail:
    flags = entitlements(db, r)
    return RestaurantDetail.model_validate(r).model_copy(
        update={"channels": channels_of(flags), "reservations": flags.enabled("reservations")}
    )
