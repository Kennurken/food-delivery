from fastapi import APIRouter, HTTPException, status

from app.api.deps import DB, CurrentUser
from app.core.access import require_restaurant
from app.models import Restaurant
from app.models.reservation import Reservation
from app.schemas.reservation import ReservationCreate, ReservationOut, ReservationUpdate
from app.services import reservation as reserve

router = APIRouter(tags=["reservations"])


def _restaurant(db, restaurant_id: int) -> Restaurant:
    row = db.get(Restaurant, restaurant_id)
    if not row:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Restaurant not found")
    return row


@router.post("/reservations", response_model=ReservationOut, status_code=status.HTTP_201_CREATED)
def create_reservation(data: ReservationCreate, db: DB, user: CurrentUser) -> dict:
    restaurant = _restaurant(db, data.restaurant_id)
    row = reserve.create(db, restaurant, data, user=user)
    return reserve.to_out(row)


@router.get("/reservations", response_model=list[ReservationOut])
def my_reservations(db: DB, user: CurrentUser) -> list[dict]:
    return [reserve.to_out(r) for r in reserve.list_mine(db, user)]


@router.post("/reservations/{reservation_id}/cancel", response_model=ReservationOut)
def cancel_reservation(reservation_id: int, db: DB, user: CurrentUser) -> dict:
    return reserve.to_out(reserve.cancel(db, user, reservation_id))


@router.get(
    "/admin/restaurants/{restaurant_id}/reservations",
    response_model=list[ReservationOut],
)
def admin_list(restaurant_id: int, db: DB, user: CurrentUser) -> list[dict]:
    require_restaurant(db, user, restaurant_id, "orders.read")
    return [reserve.to_out(r) for r in reserve.list_for_restaurant(db, restaurant_id)]


@router.post(
    "/admin/restaurants/{restaurant_id}/reservations",
    response_model=ReservationOut,
    status_code=status.HTTP_201_CREATED,
)
def admin_create(restaurant_id: int, data: ReservationCreate, db: DB, user: CurrentUser) -> dict:
    require_restaurant(db, user, restaurant_id, "orders.manage")
    restaurant = _restaurant(db, restaurant_id)
    payload = data.model_copy(update={"restaurant_id": restaurant_id})
    row = reserve.create(db, restaurant, payload, user=None, status_value="confirmed")
    return reserve.to_out(row)


@router.patch("/admin/reservations/{reservation_id}", response_model=ReservationOut)
def admin_update(reservation_id: int, data: ReservationUpdate, db: DB, user: CurrentUser) -> dict:
    row = db.get(Reservation, reservation_id)
    if not row:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Reservation not found")
    require_restaurant(db, user, row.restaurant_id, "orders.manage")
    return reserve.to_out(
        reserve.update(db, row, status_value=data.status, table_object_id=data.table_object_id)
    )
