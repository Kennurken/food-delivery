"""When this order should leave the kitchen — not a fake ETA."""

from datetime import UTC, datetime, timedelta

from fastapi import HTTPException, status

MIN_LEAD = timedelta(minutes=30)
MAX_LEAD = timedelta(hours=48)


def as_naive_utc(value: datetime) -> datetime:
    if value.tzinfo is not None:
        return value.astimezone(UTC).replace(tzinfo=None)
    return value


def utcnow() -> datetime:
    return datetime.now(UTC).replace(tzinfo=None)


def parse_slot(value: datetime | None, *, now: datetime | None = None) -> datetime | None:
    if value is None:
        return None
    when = as_naive_utc(value)
    stamp = now or utcnow()
    if when < stamp + MIN_LEAD:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Pick a time at least 30 minutes from now")
    if when > stamp + MAX_LEAD:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Cannot schedule more than 48 hours ahead")
    return when.replace(second=0, microsecond=0)


def due_for_courier(scheduled_for: datetime | None, *, now: datetime | None = None) -> bool:
    """Couriers only see a scheduled drop-off once the slot is close."""
    if scheduled_for is None:
        return True
    stamp = now or utcnow()
    when = as_naive_utc(scheduled_for)
    return when <= stamp + timedelta(minutes=40)
