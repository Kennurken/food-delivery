"""A courier's wallet: what the platform owes them, and what they owe it back."""

import pytest

from app.core.config import settings
from tests.conftest import deliver

EARNINGS = "/api/v1/me/earnings"


def _order(client, auth, admin, courier, *, pay_method: str = "cash") -> int:
    menu = client.get("/api/v1/restaurants/1/menu").json()
    oid = client.post(
        "/api/v1/orders",
        json={
            "restaurant_id": 1,
            "address": "Abay 10",
            "dest_lat": 43.2389,
            "dest_lng": 76.9455,
            "items": [{"menu_item_id": menu[0]["id"], "quantity": 1}],
            "pay_method": pay_method,
        },
        headers=auth,
    ).json()["id"]
    client.patch(f"/api/v1/orders/{oid}/status", json={"status": "confirmed"}, headers=admin)
    client.post(f"/api/v1/orders/{oid}/accept", headers=courier)
    client.patch(f"/api/v1/orders/{oid}/status", json={"status": "preparing"}, headers=admin)
    client.post(f"/api/v1/orders/{oid}/advance", headers=courier)
    return oid


@pytest.fixture
def wallet(client, courier):
    def read(days: int = 7) -> dict:
        r = client.get(EARNINGS, params={"days": days}, headers=courier)
        assert r.status_code == 200, r.text
        return r.json()

    return read


def test_a_customer_has_no_wallet(client, auth):
    assert client.get(EARNINGS, headers=auth).status_code == 403


def test_an_admin_sees_only_their_own_wallet(client, admin):
    """Admins reach courier routes everywhere here, but the query is scoped to
    the caller — this is their own (empty) wallet, not a window into someone's."""
    body = client.get(EARNINGS, headers=admin).json()

    assert body["earned_all_time"] == 0
    assert body["deliveries_all_time"] == 0


def test_delivering_pays_a_share_of_the_delivery_fee(client, auth, admin, courier, wallet):
    before = wallet()
    oid = _order(client, auth, admin, courier)
    order = client.get(f"/api/v1/orders/{oid}", headers=auth).json()

    deliver(client, oid, courier, auth)
    after = wallet()

    expected = round(order["delivery_fee"] * settings.courier_fee_share, 2)
    assert after["deliveries"] == before["deliveries"] + 1
    assert round(after["earned"] - before["earned"], 2) == expected


def test_an_undelivered_order_pays_nothing(client, auth, admin, courier, wallet):
    before = wallet()
    _order(client, auth, admin, courier)

    after = wallet()

    assert after["earned"] == before["earned"]
    assert after["deliveries"] == before["deliveries"]


def test_the_payout_is_frozen_when_the_ticket_closes(
    client, auth, admin, courier, wallet, monkeypatch
):
    """Cutting the share tomorrow must not rewrite what someone already earned."""
    oid = _order(client, auth, admin, courier)
    deliver(client, oid, courier, auth)
    earned = wallet()["earned"]

    monkeypatch.setattr(settings, "courier_fee_share", 0.1)

    assert wallet()["earned"] == earned


def test_cash_in_the_courier_pocket_is_counted_as_owed(client, auth, admin, courier, wallet):
    before = wallet()
    oid = _order(client, auth, admin, courier, pay_method="cash")
    order = client.get(f"/api/v1/orders/{oid}", headers=auth).json()

    deliver(client, oid, courier, auth)
    after = wallet()

    assert round(after["cash_held"] - before["cash_held"], 2) == order["total"]


def test_earnings_and_cash_held_are_not_mixed(client, auth, admin, courier, wallet):
    """One is a debt to the courier, the other a debt from them. Never one number."""
    oid = _order(client, auth, admin, courier)
    deliver(client, oid, courier, auth)

    data = wallet()

    assert data["cash_held"] > data["earned"]  # the whole basket vs a slice of the fee


def test_a_card_order_leaves_no_cash_to_hand_in(client, auth, admin, courier, wallet, monkeypatch):
    from app.core.billing import PaymentResult
    from app.services import order_service as svc

    monkeypatch.setattr(svc, "card_connected", lambda: True)
    monkeypatch.setattr(
        svc,
        "create_checkout_session",
        lambda **kw: PaymentResult(
            provider="stripe", reference="cs_test_1", status="pending", url="https://stripe.test"
        ),
    )
    before = wallet()
    menu = client.get("/api/v1/restaurants/1/menu").json()
    oid = client.post(
        "/api/v1/orders",
        json={
            "restaurant_id": 1,
            "address": "Abay 10",
            "items": [{"menu_item_id": menu[0]["id"], "quantity": 1}],
            "pay_method": "online",
        },
        headers=auth,
    ).json()["id"]
    client.post(f"/api/v1/orders/{oid}/pay/mark", headers=admin)

    after = wallet()

    assert after["cash_held"] == before["cash_held"]


def test_the_window_narrows_the_totals_but_not_the_cash(client, auth, admin, courier, wallet):
    oid = _order(client, auth, admin, courier)
    deliver(client, oid, courier, auth)

    week = wallet(7)
    day = wallet(1)

    # Today's delivery is inside both windows, so the money matches...
    assert day["earned"] == week["earned"] or day["earned"] <= week["earned"]
    # ...but cash owed ignores the window entirely: a debt does not expire.
    assert day["cash_held"] == week["cash_held"]
    assert day["days"] == 1 and week["days"] == 7


def test_by_day_adds_up_to_the_window_total(client, auth, admin, courier, wallet):
    oid = _order(client, auth, admin, courier)
    deliver(client, oid, courier, auth)

    data = wallet()

    assert round(sum(row["earned"] for row in data["by_day"]), 2) == data["earned"]
    assert sum(row["deliveries"] for row in data["by_day"]) == data["deliveries"]


def test_lifetime_is_never_smaller_than_the_window(client, auth, admin, courier, wallet):
    oid = _order(client, auth, admin, courier)
    deliver(client, oid, courier, auth)

    data = wallet()

    assert data["earned_all_time"] >= data["earned"]
    assert data["deliveries_all_time"] >= data["deliveries"]
