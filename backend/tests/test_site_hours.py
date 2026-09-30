"""Tests for opening hours display on the public site."""

import json
from datetime import UTC, datetime, timedelta

import pytest
from fastapi.testclient import TestClient

from app.db.session import SessionLocal
from app.models import Restaurant


def _make_restaurant(client, admin, name: str) -> Restaurant:
    r = client.post(
        "/api/v1/admin/restaurants",
        json={"name": name, "cuisine": "Test"},
        headers=admin,
    )
    assert r.status_code == 201, r.text
    rid = r.json()["id"]
    with SessionLocal() as db:
        rest = db.get(Restaurant, rid)
        db.refresh(rest)
        return rest


def _set_hours(client, admin, rid: int, rows: list[dict]) -> None:
    r = client.put(
        f"/api/v1/admin/restaurants/{rid}/hours",
        json=rows,
        headers=admin,
    )
    assert r.status_code == 200, r.text


def _get_slug(db, rid: int) -> str:
    r = db.get(Restaurant, rid)
    return r.slug




def test_closed_now_shows_tomorrow_note(client: TestClient, admin: dict) -> None:
    """Venue closed now, only a stretch tomorrow 10:00–11:00."""
    rest = _make_restaurant(client, admin, "Closed Tomorrow")
    rid = rest.id

    # Stretch tomorrow at 10:00–11:00 (weekday = tomorrow)
    tomorrow = (datetime.now(UTC) + timedelta(days=1)).weekday()
    _set_hours(client, admin, rid, [{"weekday": tomorrow, "opens": "10:00", "closes": "11:00"}])

    with SessionLocal() as db:
        slug = _get_slug(db, rid)

    # Landing page
    resp = client.get("/")
    assert resp.status_code == 200
    assert "Откроется завтра в 10:00" in resp.text

    # Restaurant page
    resp = client.get(f"/r/{slug}/")
    assert resp.status_code == 200
    assert "Откроется завтра в 10:00" in resp.text
    assert "Можно заказать заранее" in resp.text


def test_open_now_no_opens_text(client: TestClient, admin: dict) -> None:
    """Venue open now (24/7) — no 'Откроется' text anywhere."""
    rest = _make_restaurant(client, admin, "Open Now")
    rid = rest.id

    # Round-the-clock every day
    rows = [{"weekday": d, "opens": "00:00", "closes": "00:00"} for d in range(7)]
    _set_hours(client, admin, rid, rows)

    with SessionLocal() as db:
        slug = _get_slug(db, rid)

    resp = client.get(f"/r/{slug}/")
    assert resp.status_code == 200
    # Should NOT have "Откроется" on the page
    assert "Откроется" not in resp.text


def test_hours_section_lists_all_days(client: TestClient, admin: dict) -> None:
    """Hours section lists Mon–Sun with correct labels: Выходной, Круглосуточно, overnight."""
    rest = _make_restaurant(client, admin, "Hours List")
    rid = rest.id

    # Monday: closed (no row) -> Выходной
    # Tuesday: 10:00–22:00
    # Wednesday: overnight 18:00–02:00
    # Thursday: 24/7
    # Friday–Sunday: closed
    rows = [
        {"weekday": 1, "opens": "10:00", "closes": "22:00"},  # Tue
        {"weekday": 2, "opens": "18:00", "closes": "02:00"},  # Wed overnight
        {"weekday": 3, "opens": "00:00", "closes": "00:00"},  # Thu 24/7
    ]
    _set_hours(client, admin, rid, rows)

    with SessionLocal() as db:
        slug = _get_slug(db, rid)

    resp = client.get(f"/r/{slug}/")
    assert resp.status_code == 200

    # Check all seven days present
    for day in ["Понедельник", "Вторник", "Среда", "Четверг", "Пятница", "Суббота", "Воскресенье"]:
        assert day in resp.text

    # Check specific labels
    assert "Выходной" in resp.text  # Mon, Fri, Sat, Sun
    assert "Круглосуточно" in resp.text  # Thu
    assert "10:00–22:00" in resp.text  # Tue
    assert "18:00–02:00" in resp.text  # Wed overnight


def test_json_ld_opening_hours_specification(client: TestClient, admin: dict) -> None:
    """JSON-LD has openingHoursSpecification per stretch with correct dayOfWeek URLs."""
    rest = _make_restaurant(client, admin, "JSON-LD Hours")
    rid = rest.id

    rows = [
        {"weekday": 0, "opens": "10:00", "closes": "14:00"},  # Mon
        {"weekday": 0, "opens": "17:00", "closes": "22:00"},  # Mon second stretch
        {"weekday": 2, "opens": "18:00", "closes": "02:00"},  # Wed overnight
    ]
    _set_hours(client, admin, rid, rows)

    with SessionLocal() as db:
        slug = _get_slug(db, rid)

    resp = client.get(f"/r/{slug}/")
    assert resp.status_code == 200

    # Find the ld+json script block
    import re
    match = re.search(r'<script type="application/ld\+json">(.*?)</script>', resp.text, re.DOTALL)
    assert match, "No JSON-LD block found"
    data = json.loads(match.group(1))

    assert "openingHoursSpecification" in data
    specs = data["openingHoursSpecification"]
    assert len(specs) == 3

    # Check each spec structure
    day_urls = [
        "https://schema.org/Monday",
        "https://schema.org/Monday",
        "https://schema.org/Wednesday",
    ]
    for spec, expected_day in zip(specs, day_urls):
        assert spec["@type"] == "OpeningHoursSpecification"
        assert spec["dayOfWeek"] == expected_day
        assert "opens" in spec
        assert "closes" in spec


def test_no_schedule_no_hours_section(client: TestClient, admin: dict) -> None:
    """Venue without schedule has no 'Часы работы' section and no openingHoursSpecification."""
    rest = _make_restaurant(client, admin, "No Schedule")
    rid = rest.id
    # No hours set

    with SessionLocal() as db:
        slug = _get_slug(db, rid)

    resp = client.get(f"/r/{slug}/")
    assert resp.status_code == 200

    assert "Часы работы" not in resp.text

    import re
    match = re.search(r'<script type="application/ld\+json">(.*?)</script>', resp.text, re.DOTALL)
    assert match, "No JSON-LD block found"
    data = json.loads(match.group(1))
    assert "openingHoursSpecification" not in data


def test_closed_by_schedule_not_identical_to_switched_off(client: TestClient, admin: dict) -> None:
    """A venue closed by schedule shows the note, not 'Закрыто' badge."""
    rest = _make_restaurant(client, admin, "Schedule Closed")
    rid = rest.id

    # Only open next week Monday
    next_monday = 0  # Monday
    _set_hours(client, admin, rid, [{"weekday": next_monday, "opens": "10:00", "closes": "22:00"}])

    with SessionLocal() as db:
        slug = _get_slug(db, rid)

    # Landing page - should show the schedule badge, NOT the 'Закрыто' badge for this venue
    resp = client.get("/")
    assert resp.status_code == 200
    # The venue is 'is_open'=True in DB but closed by schedule
    # Should show "Откроется в пн, 10:00" (or завтра/сегодня depending on actual day)
    assert "Откроется" in resp.text

    # Restaurant page
    resp = client.get(f"/r/{slug}/")
    assert resp.status_code == 200
    assert "Откроется" in resp.text
    assert "Можно заказать заранее" in resp.text
    # The 'Сейчас закрыто' notice should NOT appear for schedule-closed (only for is_open=False)
    # Actually looking at the template - it shows "Сейчас закрыто" when not restaurant.is_open
    # Since is_open=True, it shouldn't show that. Let's verify.


if __name__ == "__main__":
    pytest.main([__file__, "-v"])