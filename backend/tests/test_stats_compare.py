"""This week against last week, measured the same way."""

import secrets
from datetime import datetime, timedelta

import pytest

from app.db.session import SessionLocal
from app.models import Order, OrderStatus


@pytest.fixture
def venue(client, admin) -> int:
    rid = client.post(
        "/api/v1/admin/restaurants",
        json={"name": f"Compare Cafe {secrets.token_hex(2)}", "cuisine": "Test"},
        headers=admin,
    ).json()["id"]
    client.patch(f"/api/v1/admin/restaurants/{rid}", json={"plan_code": "pro"}, headers=admin)
    return rid


def _put(rid: int, days_ago: float, total: float = 1000, **extra) -> None:
    """An order stamped `days_ago` in the past, on the same clock the stats use."""
    fields = {"status": OrderStatus.delivered, "pay_method": "cash", **extra}
    with SessionLocal() as db:
        db.add(
            Order(
                user_id=3,
                restaurant_id=rid,
                address="x",
                subtotal=total,
                delivery_fee=0,
                total=total,
                created_at=datetime.now() - timedelta(days=days_ago),  # noqa: DTZ005 — naive like the rows
                **fields,
            )
        )
        db.commit()


def _stats(client, admin, rid: int, days: int = 7) -> dict:
    r = client.get(f"/api/v1/admin/restaurants/{rid}/stats", params={"days": days}, headers=admin)
    assert r.status_code == 200, r.text
    return r.json()


def test_the_previous_window_holds_only_its_own_orders(client, admin, venue):
    for ago in (1, 2, 3, 4):
        _put(venue, ago)
    for ago in (8, 9):
        _put(venue, ago, total=500)
    _put(venue, 20)  # older than both windows

    body = _stats(client, admin, venue)

    assert body["orders"] == 4 and body["revenue"] == 4000
    assert body["previous"] == {"orders": 2, "revenue": 1000, "average_check": 500, "cancelled": 0}
    assert body["orders_change_pct"] == 100.0
    assert body["revenue_change_pct"] == 300.0


def test_a_drop_is_negative(client, admin, venue):
    _put(venue, 1)
    for ago in (8, 9, 10, 11):
        _put(venue, ago)

    body = _stats(client, admin, venue)

    assert body["orders_change_pct"] == -75.0


def test_an_empty_baseline_gives_no_percentage(client, admin, venue):
    _put(venue, 1)

    body = _stats(client, admin, venue)

    assert body["previous"]["orders"] == 0
    assert body["orders_change_pct"] is None
    assert body["revenue_change_pct"] is None


def test_unpaid_card_orders_are_not_revenue_last_week_either(client, admin, venue):
    _put(venue, 9, pay_method="online", pay_status="unpaid")
    _put(venue, 10, pay_method="online", pay_status="paid")

    prev = _stats(client, admin, venue)["previous"]

    assert prev["orders"] == 2
    assert prev["revenue"] == 1000


def test_cancellations_are_counted_in_their_own_window(client, admin, venue):
    _put(venue, 9, status=OrderStatus.cancelled)

    body = _stats(client, admin, venue)

    assert body["previous"]["cancelled"] == 1
    assert body["cancelled"] == 0


def test_a_plan_does_not_see_past_its_window(client, admin, venue):
    """Basic looks back a week; comparing a week needs two, so there is none."""
    client.patch(f"/api/v1/admin/restaurants/{venue}", json={"plan_code": "basic"}, headers=admin)
    _put(venue, 9)

    body = _stats(client, admin, venue)

    assert body["previous"] is None
    assert body["orders_change_pct"] is None and body["revenue_change_pct"] is None


def test_the_existing_numbers_do_not_move(client, admin, venue):
    _put(venue, 1, total=1200)
    _put(venue, 2, status=OrderStatus.cancelled)

    body = _stats(client, admin, venue)

    assert (body["orders"], body["revenue"], body["average_check"], body["cancelled"]) == (
        2,
        1200,
        1200,
        1,
    )
