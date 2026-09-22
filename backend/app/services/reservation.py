"""Book a table. Entitlement is `reservations`, not `if plan == pro`."""

from datetime import datetime, timedelta

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.features import entitlements
from app.models import Restaurant, User, UserRole
from app.models.floor_plan import Floor, FloorObject
from app.models.reservation import Reservation
from app.services.floor_plan import TABLE_KINDS
from app.services.schedule import as_naive_utc, utcnow

ACTIVE = ("requested", "confirmed", "seated")
MIN_LEAD = timedelta(minutes=30)
MAX_LEAD = timedelta(days=14)
DEFAULT_DURATION = 90


def _require_flag(db: Session, restaurant: Restaurant) -> None:
    if not entitlements(db, restaurant).enabled("reservations"):
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Reservations are not on this plan")


def parse_when(
    value: datetime, *, now: datetime | None = None, require_lead: bool = True
) -> datetime:
    when = as_naive_utc(value).replace(second=0, microsecond=0)
    stamp = now or utcnow()
    if require_lead and when < stamp + MIN_LEAD:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Pick a time at least 30 minutes from now")
    if not require_lead and when < stamp - timedelta(minutes=15):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Time is in the past")
    if when > stamp + MAX_LEAD:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Cannot book more than 14 days ahead")
    return when


def _end(row: Reservation) -> datetime:
    return row.starts_at + timedelta(minutes=row.duration_min)


def _overlaps(row: Reservation, start: datetime, end: datetime) -> bool:
    return row.starts_at < end and _end(row) > start


def _table(db: Session, restaurant_id: int, table_id: int | None) -> FloorObject | None:
    if table_id is None:
        return None
    obj = db.get(FloorObject, table_id)
    if obj is None or obj.kind not in TABLE_KINDS:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Unknown table")
    floor = db.get(Floor, obj.floor_id)
    if floor is None or floor.restaurant_id != restaurant_id:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Table is not in this restaurant")
    if obj.status == "disabled":
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Table is not bookable")
    return obj


def _conflict(
    db: Session, table_id: int, start: datetime, duration: int, *, skip_id: int | None = None
) -> bool:
    end = start + timedelta(minutes=duration)
    rows = db.scalars(
        select(Reservation).where(
            Reservation.table_object_id == table_id,
            Reservation.status.in_(ACTIVE),
        )
    )
    for row in rows:
        if skip_id is not None and row.id == skip_id:
            continue
        if _overlaps(row, start, end):
            return True
    return False


def _sync_table(obj: FloorObject | None, new_status: str) -> None:
    if obj is None:
        return
    if new_status == "confirmed" and obj.status == "available":
        obj.status = "reserved"
    elif new_status == "seated":
        obj.status = "occupied"
    elif new_status in {"cancelled", "no_show"} and obj.status == "reserved":
        obj.status = "available"


def to_out(row: Reservation) -> dict:
    table_name = None
    if row.table is not None:
        table_name = row.table.name or f"Table {row.table.id}"
    return {
        "id": row.id,
        "restaurant_id": row.restaurant_id,
        "restaurant_name": row.restaurant.name if row.restaurant else "",
        "user_id": row.user_id,
        "table_object_id": row.table_object_id,
        "table_name": table_name,
        "name": row.name,
        "phone": row.phone,
        "guests": row.guests,
        "starts_at": row.starts_at,
        "duration_min": row.duration_min,
        "status": row.status,
        "comment": row.comment,
        "created_at": row.created_at,
    }


def list_tables(db: Session, restaurant: Restaurant) -> list[dict]:
    _require_flag(db, restaurant)
    floors = list(db.scalars(select(Floor).where(Floor.restaurant_id == restaurant.id)))
    out: list[dict] = []
    for floor in floors:
        for obj in floor.objects:
            if obj.kind not in TABLE_KINDS or obj.status == "disabled":
                continue
            out.append(
                {
                    "id": obj.id,
                    "name": obj.name or f"Table {obj.id}",
                    "capacity": obj.capacity or obj.max_guests,
                    "status": obj.status,
                    "floor_name": floor.name,
                    "kind": obj.kind,
                }
            )
    return out


def create(
    db: Session,
    restaurant: Restaurant,
    data,
    *,
    user: User | None,
    status_value: str = "requested",
) -> Reservation:
    _require_flag(db, restaurant)
    start = parse_when(data.starts_at, require_lead=user is not None)
    duration = data.duration_min or DEFAULT_DURATION
    table = _table(db, restaurant.id, data.table_object_id)
    if table is not None and _conflict(db, table.id, start, duration):
        raise HTTPException(status.HTTP_409_CONFLICT, "That table is already booked")
    cap = (table.capacity or table.max_guests) if table is not None else None
    if cap is not None and data.guests > cap:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, f"Table seats at most {cap}")
    if table is not None and status_value == "requested":
        status_value = "confirmed"
    row = Reservation(
        restaurant_id=restaurant.id,
        user_id=user.id if user else None,
        table_object_id=table.id if table else None,
        name=data.name,
        phone=data.phone,
        guests=data.guests,
        starts_at=start,
        duration_min=duration,
        status=status_value,
        comment=data.comment,
        created_at=utcnow(),
    )
    db.add(row)
    _sync_table(table, status_value)
    db.commit()
    db.refresh(row)
    return row


def list_mine(db: Session, user: User) -> list[Reservation]:
    return list(
        db.scalars(
            select(Reservation)
            .where(Reservation.user_id == user.id)
            .order_by(Reservation.starts_at.desc(), Reservation.id.desc())
        )
    )


def list_for_restaurant(db: Session, restaurant_id: int) -> list[Reservation]:
    return list(
        db.scalars(
            select(Reservation)
            .where(Reservation.restaurant_id == restaurant_id)
            .order_by(Reservation.starts_at, Reservation.id)
        )
    )


def get_visible(db: Session, user: User, reservation_id: int) -> Reservation:
    row = db.get(Reservation, reservation_id)
    if not row:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Reservation not found")
    if user.role == UserRole.admin or row.user_id == user.id:
        return row
    raise HTTPException(status.HTTP_404_NOT_FOUND, "Reservation not found")


def cancel(db: Session, user: User, reservation_id: int) -> Reservation:
    row = get_visible(db, user, reservation_id)
    if row.status in {"seated", "cancelled", "no_show"}:
        raise HTTPException(status.HTTP_409_CONFLICT, "Reservation cannot be cancelled")
    if row.user_id != user.id and user.role != UserRole.admin:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Only the guest can cancel")
    row.status = "cancelled"
    _sync_table(row.table, "cancelled")
    db.commit()
    db.refresh(row)
    return row


def update(
    db: Session, row: Reservation, *, status_value: str | None, table_object_id: int | None
) -> Reservation:
    table = row.table
    if status_value:
        if status_value not in {"requested", "confirmed", "seated", "cancelled", "no_show"}:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "Unknown status")
        row.status = status_value
    if table_object_id is not None:
        table = _table(db, row.restaurant_id, table_object_id)
        if table is not None and _conflict(
            db, table.id, row.starts_at, row.duration_min, skip_id=row.id
        ):
            raise HTTPException(status.HTTP_409_CONFLICT, "That table is already booked")
        row.table_object_id = table.id if table else None
    _sync_table(table, row.status)
    db.commit()
    db.refresh(row)
    return row
