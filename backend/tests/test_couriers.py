"""A restaurant's own couriers.

A courier hired by a venue sees and takes that venue's deliveries only. A
courier nobody hired stays on the shared pool and sees everything, as before.
"""

import itertools

import pytest

_n = itertools.count(1)
VENUE, OTHER = 1, 2


def _order(client, auth, admin, venue_id: int) -> int:
    menu = client.get(f"/api/v1/restaurants/{venue_id}/menu").json()
    r = client.post(
        "/api/v1/orders",
        json={
            "restaurant_id": venue_id,
            "address": "Abay 10",
            "dest_lat": 43.2389,
            "dest_lng": 76.9455,
            "items": [{"menu_item_id": menu[0]["id"], "quantity": 1}],
            "pay_method": "cash",
        },
        headers=auth,
    )
    assert r.status_code == 201, r.text
    oid = r.json()["id"]
    client.patch(f"/api/v1/orders/{oid}/status", json={"status": "confirmed"}, headers=admin)
    return oid


def _register(client) -> tuple[dict, str]:
    email = f"rider{next(_n)}@own.kz"
    r = client.post(
        "/api/v1/auth/register", json={"email": email, "name": "Rider", "password": "secret12"}
    )
    assert r.status_code in (200, 201), r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}, email


def _hire(client, admin, email: str, venue_id: int = VENUE):
    return client.post(
        f"/api/v1/admin/restaurants/{venue_id}/staff",
        json={"email": email, "role": "delivery_courier"},
        headers=admin,
    )


def _ids(client, headers) -> list[int]:
    return [o["id"] for o in client.get("/api/v1/orders/available", headers=headers).json()]


@pytest.fixture
def rider(client, admin):
    headers, email = _register(client)
    assert _hire(client, admin, email).status_code == 201
    # A hire is a guest promoted to courier; the token still says who they are.
    me = client.get("/api/v1/auth/me", headers=headers).json()
    assert me["role"] == "courier"
    client.post("/api/v1/me/shift", json={"on": True}, headers=headers)
    return {"headers": headers, "email": email, "id": me["id"]}


def test_a_hired_courier_sees_only_their_venue(client, auth, admin, rider):
    mine = _order(client, auth, admin, VENUE)
    theirs = _order(client, auth, admin, OTHER)

    seen = _ids(client, rider["headers"])

    assert mine in seen
    assert theirs not in seen


def test_a_hired_courier_cannot_take_another_venues_order(client, auth, admin, rider):
    theirs = _order(client, auth, admin, OTHER)

    r = client.post(f"/api/v1/orders/{theirs}/accept", headers=rider["headers"])

    assert r.status_code == 403


def test_a_hired_courier_can_take_their_own(client, auth, admin, rider):
    mine = _order(client, auth, admin, VENUE)

    r = client.post(f"/api/v1/orders/{mine}/accept", headers=rider["headers"])

    assert r.status_code == 200 and r.json()["courier"]["id"] == rider["id"]


def test_the_shared_pool_courier_still_sees_everything(client, auth, admin, courier, rider):
    mine = _order(client, auth, admin, VENUE)
    theirs = _order(client, auth, admin, OTHER)
    client.post("/api/v1/me/shift", json={"on": True}, headers=courier)

    seen = _ids(client, courier)

    assert mine in seen and theirs in seen


def test_a_guest_cannot_be_a_courier_by_asking(client, auth):
    assert client.get("/api/v1/orders/available", headers=auth).status_code == 403


def test_letting_a_courier_go_takes_the_role_back(client, auth, admin, rider):
    mine = _order(client, auth, admin, VENUE)

    r = client.delete(f"/api/v1/admin/restaurants/{VENUE}/staff/{rider['id']}", headers=admin)

    assert r.status_code == 204
    assert client.get("/api/v1/auth/me", headers=rider["headers"]).json()["role"] == "customer"
    assert client.get("/api/v1/orders/available", headers=rider["headers"]).status_code == 403
    assert client.post(f"/api/v1/orders/{mine}/accept", headers=rider["headers"]).status_code == 403


def test_a_courier_with_two_venues_sees_both_and_survives_losing_one(client, auth, admin, rider):
    assert _hire(client, admin, rider["email"], OTHER).status_code == 201
    a, b = _order(client, auth, admin, VENUE), _order(client, auth, admin, OTHER)
    assert {a, b} <= set(_ids(client, rider["headers"]))

    client.delete(f"/api/v1/admin/restaurants/{VENUE}/staff/{rider['id']}", headers=admin)

    assert client.get("/api/v1/auth/me", headers=rider["headers"]).json()["role"] == "courier"
    assert b in _ids(client, rider["headers"]) and a not in _ids(client, rider["headers"])


def test_hiring_leaves_an_existing_admin_an_admin(client, admin):
    email = "admin@food.dev"
    r = _hire(client, admin, email)
    assert r.status_code == 201
    assert client.get("/api/v1/auth/me", headers=admin).json()["role"] == "admin"
    admin_id = client.get("/api/v1/auth/me", headers=admin).json()["id"]
    client.delete(f"/api/v1/admin/restaurants/{VENUE}/staff/{admin_id}", headers=admin)
    assert client.get("/api/v1/auth/me", headers=admin).json()["role"] == "admin"


def test_the_pool_banner_skips_couriers_hired_elsewhere(client, auth, admin, rider):
    from app.db.session import SessionLocal
    from app.models import Order
    from app.services import order_service

    theirs = _order(client, auth, admin, OTHER)
    with SessionLocal() as db:
        audience = order_service.audience(db, db.get(Order, theirs), pool=True)

    assert rider["id"] not in audience
