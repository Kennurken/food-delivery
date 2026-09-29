"""Per-delivery payout history for a courier."""

from app.core.config import settings
from tests.conftest import deliver

HISTORY = "/api/v1/me/earnings/history"


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


def test_customer_cannot_access_history(client, auth):
    assert client.get(HISTORY, headers=auth).status_code == 403


def test_history_returns_delivered_orders_newest_first(client, auth, admin, courier):
    oid1 = _order(client, auth, admin, courier)
    order1 = client.get(f"/api/v1/orders/{oid1}", headers=auth).json()
    deliver(client, oid1, courier, auth)

    oid2 = _order(client, auth, admin, courier)
    order2 = client.get(f"/api/v1/orders/{oid2}", headers=auth).json()
    deliver(client, oid2, courier, auth)

    r = client.get(HISTORY, headers=courier)
    assert r.status_code == 200
    data = r.json()

    items = data["items"]
    # Find our two orders (DB has other orders from earlier tests)
    our_items = [i for i in items if i["order_id"] in (oid1, oid2)]
    assert len(our_items) == 2
    assert our_items[0]["order_id"] == oid2
    assert our_items[1]["order_id"] == oid1
    assert our_items[0]["restaurant_name"] == "Bao Bar"
    assert our_items[1]["restaurant_name"] == "Bao Bar"
    share = settings.courier_fee_share
    assert our_items[0]["payout"] == round(order2["delivery_fee"] * share, 2)
    assert our_items[1]["payout"] == round(order1["delivery_fee"] * share, 2)


def test_cash_order_shows_cash_held(client, auth, admin, courier):
    oid = _order(client, auth, admin, courier, pay_method="cash")
    order = client.get(f"/api/v1/orders/{oid}", headers=auth).json()
    deliver(client, oid, courier, auth)

    r = client.get(HISTORY, headers=courier)
    data = r.json()
    item = next(i for i in data["items"] if i["order_id"] == oid)
    assert item["pay_method"] == "cash"
    assert item["cash_held"] == order["total"]


def test_paging_limit_1_then_next_before(client, auth, admin, courier):
    oid1 = _order(client, auth, admin, courier)
    deliver(client, oid1, courier, auth)

    oid2 = _order(client, auth, admin, courier)
    deliver(client, oid2, courier, auth)

    r1 = client.get(HISTORY, params={"limit": 1}, headers=courier)
    assert r1.status_code == 200
    page1 = r1.json()
    assert len(page1["items"]) == 1
    assert page1["items"][0]["order_id"] == oid2
    assert page1["next_before"] == oid2

    r2 = client.get(HISTORY, params={"limit": 1, "before": page1["next_before"]}, headers=courier)
    assert r2.status_code == 200
    page2 = r2.json()
    assert len(page2["items"]) == 1
    assert page2["items"][0]["order_id"] == oid1
    # next_before may not be None because DB has other orders from earlier tests
    # but ids must not repeat across pages
    assert page2["items"][0]["order_id"] != page1["items"][0]["order_id"]


def test_undelivered_order_not_in_history(client, auth, admin, courier):
    oid = _order(client, auth, admin, courier)
    # Do not deliver — leave at "on_the_way" (after advance)

    r = client.get(HISTORY, headers=courier)
    data = r.json()
    ids = [i["order_id"] for i in data["items"]]
    assert oid not in ids


def test_limit_bounds(client, courier):
    assert client.get(HISTORY, params={"limit": 0}, headers=courier).status_code == 422
    assert client.get(HISTORY, params={"limit": 51}, headers=courier).status_code == 422