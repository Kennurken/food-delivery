"""A kitchen that is full should stop taking orders, not cook them late."""

import pytest


@pytest.fixture(autouse=True)
def _drain_after(client, admin):
    """Leave the shared restaurant uncapped and idle for the next test."""
    yield
    client.patch(
        "/api/v1/admin/restaurants/2",
        json={"max_active_orders": None},
        headers=admin,
    )
    for o in client.get("/api/v1/orders?restaurant_id=2", headers=admin).json():
        if o["status"] in {"pending", "confirmed", "preparing"}:
            client.patch(
                f"/api/v1/orders/{o['id']}/status",
                json={"status": "cancelled"},
                headers=admin,
            )


def _order(client, auth, restaurant_id: int = 1):
    menu = client.get(f"/api/v1/restaurants/{restaurant_id}/menu").json()
    return client.post(
        "/api/v1/orders",
        json={
            "restaurant_id": restaurant_id,
            "address": "Abay 10",
            "dest_lat": 43.2389,
            "dest_lng": 76.9455,
            "items": [{"menu_item_id": menu[0]["id"], "quantity": 1}],
            "pay_method": "cash",
        },
        headers=auth,
    )


def _set_cap(client, admin, cap: int | None):
    r = client.patch(
        "/api/v1/admin/restaurants/2",
        json={"max_active_orders": cap},
        headers=admin,
    )
    assert r.status_code == 200, r.text
    return r.json()


def test_no_cap_means_no_limit(client, auth, admin):
    _set_cap(client, admin, None)
    for _ in range(3):
        assert _order(client, auth, 2).status_code == 201


def test_a_full_kitchen_refuses_new_orders(client, auth, admin):
    _set_cap(client, admin, 1)
    assert _order(client, auth, 2).status_code == 201
    blocked = _order(client, auth, 2)
    assert blocked.status_code == 409
    assert "kitchen" in blocked.json()["detail"].lower()


def test_the_storefront_shows_a_busy_kitchen_as_not_accepting(client, auth, admin):
    _set_cap(client, admin, 1)
    assert _order(client, auth, 2).status_code == 201  # fills the one slot
    card = next(r for r in client.get("/api/v1/restaurants").json() if r["id"] == 2)
    assert card["kitchen_busy"] is True
    assert card["accepting_orders"] is False
    assert card["is_open"] is True  # the owner never closed it


def test_draining_the_queue_reopens_the_kitchen(client, auth, admin):
    _set_cap(client, admin, 1)
    oid = _order(client, auth, 2).json()["id"]
    assert _order(client, auth, 2).status_code == 409
    client.patch(
        f"/api/v1/orders/{oid}/status", json={"status": "cancelled"}, headers=admin
    )
    card = next(r for r in client.get("/api/v1/restaurants").json() if r["id"] == 2)
    assert card["accepting_orders"] is True
    assert _order(client, auth, 2).status_code == 201


def test_a_ticket_on_the_road_frees_the_stove(client, auth, admin, courier):
    """Once a courier is riding with it, the kitchen can start the next one."""
    _set_cap(client, admin, 1)
    oid = _order(client, auth, 2).json()["id"]
    assert _order(client, auth, 2).status_code == 409

    client.patch(f"/api/v1/orders/{oid}/status", json={"status": "confirmed"}, headers=admin)
    client.post(f"/api/v1/orders/{oid}/accept", headers=courier)
    client.patch(f"/api/v1/orders/{oid}/status", json={"status": "preparing"}, headers=admin)
    client.post(f"/api/v1/orders/{oid}/advance", headers=courier)  # on_the_way

    assert _order(client, auth, 2).status_code == 201
