"""Opening hours: read by anyone, replaced whole by the venue's staff."""

from datetime import time

from fastapi import APIRouter, HTTPException, Request, status
from pydantic import BaseModel, Field

from app.api.deps import DB, CurrentUser
from app.core import audit
from app.core.access import require_restaurant
from app.models import OpeningHours, Restaurant
from app.schemas.restaurant import HoursOut

router = APIRouter(tags=["hours"])


class HoursIn(BaseModel):
    weekday: int = Field(ge=0, le=6)  # 0 = Monday
    opens: time
    # Not after `opens` means past midnight; equal means round the clock.
    closes: time


def _venue(db, restaurant_id: int) -> Restaurant:
    restaurant = db.get(Restaurant, restaurant_id)
    if restaurant is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Restaurant not found")
    return restaurant


@router.get("/restaurants/{restaurant_id}/hours", response_model=list[HoursOut])
def read_hours(restaurant_id: int, db: DB) -> list[HoursOut]:
    return [HoursOut.model_validate(h) for h in _venue(db, restaurant_id).hours]


@router.put("/admin/restaurants/{restaurant_id}/hours", response_model=list[HoursOut])
def replace_hours(
    restaurant_id: int,
    body: list[HoursIn],
    db: DB,
    user: CurrentUser,
    request: Request,
) -> list[HoursOut]:
    """The whole week at once. An empty list removes the schedule, and the
    venue is then open whenever its switch is on — as before schedules existed.

    Whole-week replacement rather than per-row edits: the owner edits a week in
    one form, and a half-applied week would open the kitchen at hours nobody
    chose.
    """
    restaurant = require_restaurant(db, user, restaurant_id, "restaurant.settings.write")
    if len(body) > 28:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "At most four stretches a day")
    restaurant.hours = [
        OpeningHours(weekday=row.weekday, opens=row.opens.replace(second=0, microsecond=0),
                     closes=row.closes.replace(second=0, microsecond=0))
        for row in body
    ]
    audit.record(
        db,
        actor_id=user.id,
        restaurant_id=restaurant.id,
        action="restaurant.hours",
        resource=f"restaurant:{restaurant.id}",
        payload={"stretches": len(body)},
        request_id=getattr(request.state, "request_id", None),
    )
    db.commit()
    db.refresh(restaurant)
    return [HoursOut.model_validate(h) for h in restaurant.hours]
