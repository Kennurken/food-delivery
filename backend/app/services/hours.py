"""Whether a kitchen is open by its schedule, and when it opens next.

The owner's switch (`Restaurant.is_open`) still wins: a venue switched off is
closed whatever its hours say. The schedule only closes a venue that is
switched on — which is the case that used to go wrong: an owner who forgot to
flip the switch at night kept receiving orders nobody would cook.

Everything here reads the venue's local wall clock. Stored datetimes are naive
UTC (see app.services.schedule), so they are shifted by the city's offset
before they are compared with "10:00".
"""

from __future__ import annotations

from collections.abc import Iterable
from dataclasses import dataclass
from datetime import UTC, date, datetime, time, timedelta, timezone

from app.models import OpeningHours, Restaurant
from app.services.schedule import as_naive_utc, utcnow

# Kazakhstan, one zone since 2024. Used when a venue has no city.
DEFAULT_OFFSET_MIN = 300


@dataclass(frozen=True)
class Stretch:
    weekday: int
    opens: time
    closes: time

    @property
    def overnight(self) -> bool:
        """Runs past midnight. Equal ends mean round the clock."""
        return self.closes <= self.opens


@dataclass(frozen=True)
class HoursStatus:
    has_schedule: bool
    open_now: bool
    # Next opening on the venue's clock, offset-aware; None when open now, or
    # when there is no schedule to say.
    opens_at: datetime | None


def offset_of(restaurant: Restaurant) -> timezone:
    city = getattr(restaurant, "city", None)
    minutes = city.utc_offset_min if city is not None and city.utc_offset_min is not None else DEFAULT_OFFSET_MIN
    return timezone(timedelta(minutes=minutes))


def local_time(restaurant: Restaurant, at_utc: datetime | None = None) -> datetime:
    """The venue's wall clock at a naive-UTC (or aware) instant, as naive local."""
    stamp = as_naive_utc(at_utc) if at_utc is not None else utcnow()
    return stamp.replace(tzinfo=UTC).astimezone(offset_of(restaurant)).replace(tzinfo=None)


def stretches(rows: Iterable[OpeningHours]) -> list[Stretch]:
    return [Stretch(r.weekday, r.opens, r.closes) for r in rows]


def is_open_at(schedule: list[Stretch], local: datetime) -> bool:
    """By the schedule alone. No schedule = no restriction."""
    if not schedule:
        return True
    today, now = local.weekday(), local.time()
    yesterday = (today - 1) % 7
    for s in schedule:
        if s.weekday == today:
            if s.overnight and now >= s.opens:
                return True
            if not s.overnight and s.opens <= now < s.closes:
                return True
        # Last night's stretch still running after midnight.
        if s.overnight and s.weekday == yesterday and now < s.closes:
            return True
    return False


def next_opening(schedule: list[Stretch], local: datetime) -> datetime | None:
    """First opening strictly after `local`, within the coming week."""
    best: datetime | None = None
    for days in range(8):
        day: date = local.date() + timedelta(days=days)
        for s in schedule:
            if s.weekday != day.weekday():
                continue
            start = datetime.combine(day, s.opens)
            if start > local and (best is None or start < best):
                best = start
    return best


def status_of(restaurant: Restaurant, at_utc: datetime | None = None) -> HoursStatus:
    schedule = stretches(restaurant.hours)
    local = local_time(restaurant, at_utc)
    if is_open_at(schedule, local):
        return HoursStatus(has_schedule=bool(schedule), open_now=True, opens_at=None)
    upcoming = next_opening(schedule, local)
    return HoursStatus(
        has_schedule=True,
        open_now=False,
        opens_at=upcoming.replace(tzinfo=offset_of(restaurant)) if upcoming else None,
    )


def open_at(restaurant: Restaurant, at_utc: datetime | None = None) -> bool:
    return is_open_at(stretches(restaurant.hours), local_time(restaurant, at_utc))
