"""A venue's own numbers, and the people behind them."""

import pytest

from tests.conftest import deliver

STATS = "/api/v1/admin/restaurants/1/stats"
CUSTOMERS = "/api/v1/admin/restaurants/1/customers"


def _delivered_cash(client, auth, admin, courier) -> dict:
    menu = client.get("/api/v1/restaurants/1/menu").json()
    oid = client.post(
        "/api/v1/orders",
        json={
            "restaurant_id": 1,
            "address": "Abay 10",
            "dest_lat": 43.2389,
            "dest_lng": 76.9455,
            "items": [{"menu_item_id": menu[0]["id"], "quantity": 2}],
            "pay_method": "cash",
        },
        headers=auth,
    ).json()
    client.patch(f"/api/v1/orders/{oid['id']}/status", json={"status": "confirmed"}, headers=admin)
    client.post(f"/api/v1/orders/{oid['id']}/accept", headers=courier)
    client.patch(f"/api/v1/orders/{oid['id']}/status", json={"status": "preparing"}, headers=admin)
    client.post(f"/api/v1/orders/{oid['id']}/advance", headers=courier)
    return deliver(client, oid["id"], courier, auth)


@pytest.fixture
def stats(client, admin):
    def read(days: int = 30) -> dict:
        r = client.get(STATS, params={"days": days}, headers=admin)
        assert r.status_code == 200, r.text
        return r.json()

    return read


def test_a_customer_cannot_read_a_venues_numbers(client, auth, courier):
    assert client.get(STATS, headers=auth).status_code in (403, 404)
    assert client.get(STATS, headers=courier).status_code in (403, 404)


def test_a_delivered_order_shows_up_as_revenue(client, auth, admin, courier, stats):
    before = stats()

    order = _delivered_cash(client, auth, admin, courier)
    after = stats()

    assert after["orders"] == before["orders"] + 1
    assert round(after["revenue"] - before["revenue"], 2) == order["total"]


def test_an_open_ticket_is_not_revenue_yet(client, auth, admin, stats):
    """Counting a basket that has not been delivered would have an owner
    planning against money that may never arrive."""
    before = stats()
    menu = client.get("/api/v1/restaurants/1/menu").json()
    client.post(
        "/api/v1/orders",
        json={"restaurant_id": 1, "address": "Abay 10",
              "items": [{"menu_item_id": menu[0]["id"], "quantity": 1}], "pay_method": "cash"},
        headers=auth,
    )

    after = stats()

    assert after["orders"] == before["orders"] + 1
    assert after["revenue"] == before["revenue"]


def test_an_unpaid_card_order_is_never_counted(client, auth, admin, courier, stats, monkeypatch):
    """Stripe never confirmed it, so the money does not exist."""
    from app.core.billing import PaymentResult
    from app.services import order_service as svc

    monkeypatch.setattr(svc, "card_connected", lambda: True)
    monkeypatch.setattr(
        svc, "create_checkout_session",
        lambda **kw: PaymentResult(provider="stripe", reference="cs_test_x",
                                   status="pending", url="https://stripe.test"),
    )
    before = stats()
    menu = client.get("/api/v1/restaurants/1/menu").json()
    client.post(
        "/api/v1/orders",
        json={"restaurant_id": 1, "address": "Abay 10",
              "items": [{"menu_item_id": menu[0]["id"], "quantity": 1}], "pay_method": "online"},
        headers=auth,
    )

    after = stats()

    assert after["revenue"] == before["revenue"]


def test_the_average_check_ignores_baskets_that_earned_nothing(
    client, auth, admin, courier, stats
):
    _delivered_cash(client, auth, admin, courier)

    data = stats()

    assert data["average_check"] > 0
    assert data["average_check"] <= data["revenue"]


def test_top_dishes_count_what_was_actually_sold(client, auth, admin, courier, stats):
    _delivered_cash(client, auth, admin, courier)

    data = stats()

    assert data["top_dishes"]
    assert all(row["quantity"] > 0 for row in data["top_dishes"])


def test_the_daily_series_adds_up_to_the_total(client, auth, admin, courier, stats):
    _delivered_cash(client, auth, admin, courier)

    data = stats()

    assert round(sum(row["revenue"] for row in data["by_day"]), 2) == data["revenue"]
    assert sum(row["orders"] for row in data["by_day"]) == data["orders"]


def test_the_window_is_capped_by_the_plan_not_refused(client, admin):
    """A Basic owner asking for a year gets their week, not an error they can
    do nothing about."""
    body = client.get(STATS, params={"days": 365}, headers=admin).json()

    assert body["days"] <= body["window_limit"]
    assert body["days"] >= 1


def test_customers_list_who_actually_paid(client, auth, admin, courier):
    _delivered_cash(client, auth, admin, courier)

    body = client.get(CUSTOMERS, params={"days": 30}, headers=admin).json()

    assert body["customers"]
    top = body["customers"][0]
    assert top["orders"] >= 1
    assert top["spent"] > 0
    assert top["last_order_at"]


def test_customers_are_ranked_by_spend(client, auth, admin, courier):
    _delivered_cash(client, auth, admin, courier)

    rows = client.get(CUSTOMERS, headers=admin).json()["customers"]

    spends = [row["spent"] for row in rows]
    assert spends == sorted(spends, reverse=True)


def test_a_courier_cannot_read_the_customer_list(client, courier):
    assert client.get(CUSTOMERS, headers=courier).status_code in (403, 404)
