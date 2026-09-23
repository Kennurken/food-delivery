"""The platform's own books."""

from tests.conftest import deliver

REVENUE = "/api/v1/platform/revenue"


def _delivered(client, auth, admin, courier) -> dict:
    menu = client.get("/api/v1/restaurants/1/menu").json()
    order = client.post(
        "/api/v1/orders",
        json={
            "restaurant_id": 1,
            "address": "Abay 10",
            "dest_lat": 43.2389,
            "dest_lng": 76.9455,
            "items": [{"menu_item_id": menu[0]["id"], "quantity": 1}],
            "pay_method": "cash",
        },
        headers=auth,
    ).json()
    client.patch(f"/api/v1/orders/{order['id']}/status", json={"status": "confirmed"},
                 headers=admin)
    client.post(f"/api/v1/orders/{order['id']}/accept", headers=courier)
    client.patch(f"/api/v1/orders/{order['id']}/status", json={"status": "preparing"},
                 headers=admin)
    client.post(f"/api/v1/orders/{order['id']}/advance", headers=courier)
    return deliver(client, order["id"], courier, auth)


def test_only_an_admin_sees_the_platform_books(client, auth, courier):
    assert client.get(REVENUE, headers=auth).status_code == 403
    assert client.get(REVENUE, headers=courier).status_code == 403


def test_a_delivered_order_adds_to_gross(client, auth, admin, courier):
    before = client.get(REVENUE, headers=admin).json()

    order = _delivered(client, auth, admin, courier)
    after = client.get(REVENUE, headers=admin).json()

    assert round(after["gross"] - before["gross"], 2) == order["total"]
    assert after["orders"] == before["orders"] + 1


def test_courier_payouts_are_reported_apart_from_gross(client, auth, admin, courier):
    """What the platform took and what it owes out are different facts."""
    before = client.get(REVENUE, headers=admin).json()

    _delivered(client, auth, admin, courier)
    after = client.get(REVENUE, headers=admin).json()

    assert after["courier_payouts"] > before["courier_payouts"]
    assert after["courier_payouts"] < after["gross"]


def test_an_open_ticket_is_not_money_yet(client, auth, admin):
    before = client.get(REVENUE, headers=admin).json()
    menu = client.get("/api/v1/restaurants/1/menu").json()
    client.post(
        "/api/v1/orders",
        json={"restaurant_id": 1, "address": "Abay 10",
              "items": [{"menu_item_id": menu[0]["id"], "quantity": 1}], "pay_method": "cash"},
        headers=auth,
    )

    after = client.get(REVENUE, headers=admin).json()

    assert after["gross"] == before["gross"]


def test_the_daily_series_adds_up(client, auth, admin, courier):
    _delivered(client, auth, admin, courier)

    body = client.get(REVENUE, headers=admin).json()

    assert round(sum(row["gross"] for row in body["by_day"]), 2) == body["gross"]


def test_every_venue_appears_in_the_plan_split_even_with_no_orders(client, admin):
    """A venue that sold nothing is still a venue on a plan — leaving it out
    would make the plan mix look better than it is."""
    body = client.get(REVENUE, headers=admin).json()
    counted = sum(row["restaurants"] for row in body["by_plan"])
    total = len(client.get("/api/v1/admin/restaurants", headers=admin).json())

    assert counted == total


def test_top_restaurants_are_ranked_by_money(client, auth, admin, courier):
    _delivered(client, auth, admin, courier)

    rows = client.get(REVENUE, headers=admin).json()["top_restaurants"]

    gross = [row["gross"] for row in rows]
    assert gross == sorted(gross, reverse=True)
