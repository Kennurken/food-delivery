"""A courier chooses when they take orders.

The rules: off the line means no new orders shown and none takeable; going off
while carrying one is refused; and a courier who predates shifts is on the
line until they choose otherwise.
"""

import pytest
from sqlalchemy import update

from app.db.session import SessionLocal
from app.models import Order, OrderStatus


@pytest.fixture(autouse=True)
def _clean_shift(client, courier):
    """The courier is shared by the whole session and earlier tests leave
    orders in their hands, which would rightly stop them going off the line.
    Start each test with none, and end it back on the line."""
    with SessionLocal() as db:
        db.execute(
            update(Order)
            .where(
                Order.courier_id.is_not(None),
                Order.status.in_(
                    (OrderStatus.confirmed, OrderStatus.preparing, OrderStatus.on_the_way)
                ),
            )
            .values(status=OrderStatus.cancelled)
        )
        db.commit()
    yield
    client.post("/api/v1/me/shift", json={"on": True}, headers=courier)


def _order(client, auth) -> int:
    menu = client.get("/api/v1/restaurants/1/menu").json()
    return client.post(
        "/api/v1/orders",
        json={
            "restaurant_id": 1,
            "address": "Abay 10",
            "dest_lat": 43.2389,
            "dest_lng": 76.9455,
            "items": [{"menu_item_id": menu[0]["id"], "quantity": 1}],
        },
        headers=auth,
    ).json()["id"]


def _confirm(client, admin, oid):
    client.patch(f"/api/v1/orders/{oid}/status", json={"status": "confirmed"}, headers=admin)


def test_a_courier_starts_on_the_line(client, courier):
    assert client.get("/api/v1/me/shift", headers=courier).json() == {"on_shift": True}
    assert client.get("/api/v1/auth/me", headers=courier).json()["on_shift"] is True


def test_only_couriers_have_a_shift(client, auth):
    assert client.get("/api/v1/me/shift", headers=auth).status_code == 403
    assert client.post("/api/v1/me/shift", json={"on": False}, headers=auth).status_code == 403


def test_off_the_line_no_orders_are_shown(client, auth, admin, courier):
    oid = _order(client, auth)
    _confirm(client, admin, oid)
    assert oid in [o["id"] for o in client.get("/api/v1/orders/available", headers=courier).json()]

    client.post("/api/v1/me/shift", json={"on": False}, headers=courier)

    assert client.get("/api/v1/orders/available", headers=courier).json() == []
    client.post("/api/v1/me/shift", json={"on": True}, headers=courier)
    assert oid in [o["id"] for o in client.get("/api/v1/orders/available", headers=courier).json()]


def test_off_the_line_an_order_cannot_be_taken(client, auth, admin, courier):
    oid = _order(client, auth)
    _confirm(client, admin, oid)
    client.post("/api/v1/me/shift", json={"on": False}, headers=courier)

    r = client.post(f"/api/v1/orders/{oid}/accept", headers=courier)

    assert r.status_code == 409
    assert "on the line" in r.json()["detail"]


def test_a_courier_carrying_an_order_cannot_go_off(client, auth, admin, courier):
    oid = _order(client, auth)
    _confirm(client, admin, oid)
    assert client.post(f"/api/v1/orders/{oid}/accept", headers=courier).status_code == 200

    r = client.post("/api/v1/me/shift", json={"on": False}, headers=courier)

    assert r.status_code == 409
    assert client.get("/api/v1/me/shift", headers=courier).json() == {"on_shift": True}
    client.patch(f"/api/v1/orders/{oid}/status", json={"status": "cancelled"}, headers=admin)


def test_the_platform_counts_couriers_online(client, admin, courier):
    client.post("/api/v1/courier/location", json={"lat": 43.2, "lng": 76.9}, headers=courier)
    online = client.get("/api/v1/platform/overview", headers=admin).json()["couriers_online"]
    assert online >= 1

    client.post("/api/v1/me/shift", json={"on": False}, headers=courier)

    assert client.get("/api/v1/platform/overview", headers=admin).json()["couriers_online"] == online - 1
