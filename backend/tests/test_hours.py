"""Opening hours.

The bug this exists for: an owner who forgets to switch the venue off at night
keeps receiving orders nobody will cook. The schedule closes it; the switch
still wins; and a closed kitchen still takes orders for when it opens.
"""

import itertools
from datetime import UTC, datetime, time, timedelta

import pytest

from app.services.hours import Stretch, is_open_at, next_opening

MON, TUE, WED, THU, FRI, SAT, SUN = range(7)
_names = itertools.count(1)


def at(weekday: int, hh: int, mm: int = 0) -> datetime:
    """A local wall-clock moment on a given weekday (2026-09-28 is a Monday)."""
    monday = datetime(2026, 9, 28)  # noqa: DTZ001 — a venue wall clock, naive on purpose
    return monday + timedelta(days=weekday, hours=hh, minutes=mm)


def s(weekday: int, opens: str, closes: str) -> Stretch:
    return Stretch(weekday, time.fromisoformat(opens), time.fromisoformat(closes))


class TestTheClock:
    def test_no_schedule_means_no_restriction(self):
        assert is_open_at([], at(MON, 3))

    def test_a_plain_day(self):
        week = [s(MON, "10:00", "22:00")]

        assert is_open_at(week, at(MON, 12))
        assert not is_open_at(week, at(MON, 9, 59))
        # Closing time is the first minute it is closed.
        assert not is_open_at(week, at(MON, 22))
        assert not is_open_at(week, at(TUE, 12))

    def test_a_break_between_lunch_and_dinner(self):
        week = [s(WED, "11:00", "15:00"), s(WED, "17:00", "23:00")]

        assert is_open_at(week, at(WED, 14, 30))
        assert not is_open_at(week, at(WED, 16))
        assert is_open_at(week, at(WED, 18))

    def test_friday_night_runs_into_saturday(self):
        week = [s(FRI, "18:00", "02:00")]

        assert is_open_at(week, at(FRI, 23))
        assert is_open_at(week, at(SAT, 1, 30))
        assert not is_open_at(week, at(SAT, 2))
        assert not is_open_at(week, at(FRI, 1))  # Thursday night has no stretch

    def test_sunday_night_runs_into_monday(self):
        assert is_open_at([s(SUN, "20:00", "03:00")], at(MON, 1))

    def test_equal_ends_mean_round_the_clock(self):
        week = [s(TUE, "00:00", "00:00")]

        assert is_open_at(week, at(TUE, 0))
        assert is_open_at(week, at(TUE, 23, 59))

    def test_next_opening_is_later_today_when_before_opening(self):
        assert next_opening([s(MON, "10:00", "22:00")], at(MON, 8)) == at(MON, 10)

    def test_next_opening_skips_to_next_week_when_the_only_day_is_over(self):
        assert next_opening([s(MON, "10:00", "22:00")], at(MON, 23)) == at(MON, 10) + timedelta(days=7)

    def test_next_opening_takes_the_second_stretch_after_a_break(self):
        week = [s(WED, "11:00", "15:00"), s(WED, "17:00", "23:00")]

        assert next_opening(week, at(WED, 16)) == at(WED, 17)


# ------------------------------------------------------------------ the API


def _local_now() -> datetime:
    return datetime.now(UTC) + timedelta(hours=5)  # the seeded cities are UTC+5


@pytest.fixture
def venue(client, admin) -> dict:
    """A fresh venue with one dish, so a schedule never leaks into other tests."""
    r = client.post(
        "/api/v1/admin/restaurants",
        json={"name": f"Hours Cafe {next(_names)}", "cuisine": "Test"},
        headers=admin,
    )
    assert r.status_code == 201, r.text
    rid = r.json()["id"]
    dish = client.post(
        f"/api/v1/admin/restaurants/{rid}/menu",
        json={"name": "Plov", "price": 2000, "category": "Main"},
        headers=admin,
    )
    assert dish.status_code == 201, dish.text
    return {"id": rid, "dish": dish.json()["id"]}


def _set(client, admin, rid: int, week: list[dict]):
    return client.put(f"/api/v1/admin/restaurants/{rid}/hours", json=week, headers=admin)


def _order(client, auth, venue: dict, **extra):
    return client.post(
        "/api/v1/orders",
        json={
            "restaurant_id": venue["id"],
            "channel": "pickup",
            "items": [{"menu_item_id": venue["dish"], "quantity": 1}],
            **extra,
        },
        headers=auth,
    )


def _tomorrow() -> int:
    return (_local_now().weekday() + 1) % 7


class TestSettingHours:
    def test_the_week_round_trips_as_wall_clock_times(self, client, admin, venue):
        week = [
            {"weekday": 0, "opens": "10:00", "closes": "22:00"},
            {"weekday": 4, "opens": "18:00", "closes": "02:00"},
        ]

        r = _set(client, admin, venue["id"], week)

        assert r.status_code == 200, r.text
        assert r.json() == [
            {"weekday": 0, "opens": "10:00", "closes": "22:00"},
            {"weekday": 4, "opens": "18:00", "closes": "02:00"},
        ]
        assert client.get(f"/api/v1/restaurants/{venue['id']}/hours").json() == r.json()
        assert client.get(f"/api/v1/restaurants/{venue['id']}").json()["hours"] == r.json()

    def test_a_diner_cannot_set_them(self, client, auth, venue):
        assert _set(client, auth, venue["id"], []).status_code == 403

    def test_a_bad_weekday_is_refused(self, client, admin, venue):
        r = _set(client, admin, venue["id"], [{"weekday": 7, "opens": "10:00", "closes": "11:00"}])

        assert r.status_code == 422


class TestClosedBySchedule:
    @pytest.fixture
    def closed_today(self, client, admin, venue) -> dict:
        """Open only tomorrow, 10:00–11:00: closed now, whatever the time is."""
        _set(client, admin, venue["id"], [{"weekday": _tomorrow(), "opens": "10:00", "closes": "11:00"}])
        return venue

    def test_the_card_says_closed_and_when_it_opens(self, client, closed_today):
        card = client.get(f"/api/v1/restaurants/{closed_today['id']}").json()

        assert card["open_now"] is False
        assert card["accepting_orders"] is False
        assert card["is_open"] is True  # the owner's switch is untouched
        opens = datetime.fromisoformat(card["opens_at"])
        assert opens.utcoffset() == timedelta(hours=5)
        assert (opens.hour, opens.minute) == (10, 0)
        assert opens.weekday() == _tomorrow()

    def test_an_order_for_now_is_refused_with_the_opening_time(self, client, auth, closed_today):
        r = _order(client, auth, closed_today)

        assert r.status_code == 409
        assert "closed now" in r.json()["detail"]
        assert "10:00" in r.json()["detail"]

    def test_an_order_for_when_it_opens_is_taken(self, client, auth, closed_today):
        local = (_local_now() + timedelta(days=1)).replace(hour=10, minute=30, second=0, microsecond=0)
        slot = local - timedelta(hours=5)  # back to UTC

        r = _order(client, auth, closed_today, scheduled_for=slot.replace(tzinfo=UTC).isoformat())

        assert r.status_code == 201, r.text

    def test_an_order_for_a_closed_hour_is_refused(self, client, auth, closed_today):
        local = (_local_now() + timedelta(days=1)).replace(hour=12, minute=0, second=0, microsecond=0)
        slot = local - timedelta(hours=5)

        r = _order(client, auth, closed_today, scheduled_for=slot.replace(tzinfo=UTC).isoformat())

        assert r.status_code == 400
        assert "closed at that time" in r.json()["detail"]

    def test_clearing_the_schedule_opens_it_again(self, client, admin, auth, closed_today):
        _set(client, admin, closed_today["id"], [])

        card = client.get(f"/api/v1/restaurants/{closed_today['id']}").json()
        assert card["open_now"] is True and card["opens_at"] is None
        assert _order(client, auth, closed_today).status_code == 201


class TestOpenBySchedule:
    def test_round_the_clock_today_is_open(self, client, admin, auth, venue):
        today = _local_now().weekday()
        _set(client, admin, venue["id"], [{"weekday": today, "opens": "00:00", "closes": "00:00"}])

        card = client.get(f"/api/v1/restaurants/{venue['id']}").json()

        assert card["open_now"] is True
        assert card["accepting_orders"] is True
        assert _order(client, auth, venue).status_code == 201

    def test_the_owners_switch_still_wins(self, client, admin, auth, venue):
        today = _local_now().weekday()
        _set(client, admin, venue["id"], [{"weekday": today, "opens": "00:00", "closes": "00:00"}])
        client.patch(f"/api/v1/admin/restaurants/{venue['id']}", json={"is_open": False}, headers=admin)

        assert client.get(f"/api/v1/restaurants/{venue['id']}").json()["accepting_orders"] is False
        assert _order(client, auth, venue).status_code == 404
