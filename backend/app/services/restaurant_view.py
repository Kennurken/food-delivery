from sqlalchemy.orm import Session

from app.core.features import channels_of, entitlements
from app.models import Restaurant
from app.schemas.restaurant import RestaurantDetail, RestaurantOut


def to_out(db: Session, r: Restaurant) -> RestaurantOut:
    return RestaurantOut.model_validate(r).model_copy(
        update={"channels": channels_of(entitlements(db, r))}
    )


def to_detail(db: Session, r: Restaurant) -> RestaurantDetail:
    return RestaurantDetail.model_validate(r).model_copy(
        update={"channels": channels_of(entitlements(db, r))}
    )
