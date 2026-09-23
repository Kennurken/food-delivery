"""Proof of delivery: "delivered" must mean someone took the bag."""

from tests.conftest import deliver


def _ready_delivery(client, auth, admin, courier) -> int:
    menu = client.get("/api/v1/restaurants/1/menu").json()
    oid = client.post(
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
    ).json()["id"]
    client.patch(f"/api/v1/orders/{oid}/status", json={"status": "confirmed"}, headers=admin)
    client.post(f"/api/v1/orders/{oid}/accept", headers=courier)
    client.patch(f"/api/v1/orders/{oid}/status", json={"status": "preparing"}, headers=admin)
    client.post(f"/api/v1/orders/{oid}/advance", headers=courier)  # on_the_way
    return oid


def test_accepting_a_delivery_mints_a_code_for_the_customer(client, auth, admin, courier):
    oid = _ready_delivery(client, auth, admin, courier)
    body = client.get(f"/api/v1/orders/{oid}/handover", headers=auth)
    assert body.status_code == 200
    code = body.json()["code"]
    assert code and len(code) == 4 and code.isdigit()


def test_the_courier_cannot_read_the_code_they_must_be_told(client, auth, admin, courier):
    oid = _ready_delivery(client, auth, admin, courier)
    assert client.get(f"/api/v1/orders/{oid}/handover", headers=courier).status_code == 403


def test_the_code_never_rides_along_in_the_ticket(client, auth, admin, courier):
    oid = _ready_delivery(client, auth, admin, courier)
    ticket = client.get(f"/api/v1/orders/{oid}", headers=courier).json()
    assert "handover_code" not in ticket


def test_closing_without_the_code_is_refused(client, auth, admin, courier):
    oid = _ready_delivery(client, auth, admin, courier)
    r = client.post(f"/api/v1/orders/{oid}/advance", headers=courier)
    assert r.status_code == 400
    assert client.get(f"/api/v1/orders/{oid}", headers=auth).json()["status"] == "on_the_way"


def test_a_wrong_code_is_refused_and_leaves_the_order_open(client, auth, admin, courier):
    oid = _ready_delivery(client, auth, admin, courier)
    real = client.get(f"/api/v1/orders/{oid}/handover", headers=auth).json()["code"]
    wrong = "0000" if real != "0000" else "1111"
    r = client.post(f"/api/v1/orders/{oid}/advance", json={"code": wrong}, headers=courier)
    assert r.status_code == 400
    assert client.get(f"/api/v1/orders/{oid}", headers=auth).json()["status"] == "on_the_way"


def test_the_right_code_closes_it(client, auth, admin, courier):
    oid = _ready_delivery(client, auth, admin, courier)
    assert deliver(client, oid, courier, auth)["status"] == "delivered"


def test_a_pickup_ticket_needs_no_code(client, auth, admin):
    """Nobody rides anywhere; the counter hands it over."""
    menu = client.get("/api/v1/restaurants/1/menu").json()
    oid = client.post(
        "/api/v1/orders",
        json={
            "restaurant_id": 1,
            "channel": "pickup",
            "items": [{"menu_item_id": menu[0]["id"], "quantity": 1}],
            "pay_method": "cash",
        },
        headers=auth,
    ).json()["id"]
    assert client.get(f"/api/v1/orders/{oid}/handover", headers=auth).json()["code"] is None
