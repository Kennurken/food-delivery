def test_health(client):
    assert client.get("/health").json() == {"status": "ok"}


def test_register_and_me(client):
    r = client.post(
        "/api/v1/auth/register",
        json={"email": "new@x.com", "name": "New", "password": "secret1"},
    )
    assert r.status_code == 201
    token = r.json()["access_token"]
    me = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert me.json()["email"] == "new@x.com"


def test_list_restaurants(client):
    r = client.get("/api/v1/restaurants")
    assert r.status_code == 200
    assert len(r.json()) == 3


def test_order_flow(client, auth):
    menu = client.get("/api/v1/restaurants/1/menu").json()
    payload = {
        "restaurant_id": 1,
        "address": "Abay 10",
        "items": [{"menu_item_id": menu[0]["id"], "quantity": 2}],
    }
    r = client.post("/api/v1/orders", json=payload, headers=auth)
    assert r.status_code == 201, r.text
    order = r.json()
    assert order["subtotal"] == menu[0]["price"] * 2
    assert order["total"] == order["subtotal"] + order["delivery_fee"]

    r = client.post(f"/api/v1/orders/{order['id']}/cancel", headers=auth)
    assert r.json()["status"] == "cancelled"

    r = client.post(f"/api/v1/orders/{order['id']}/cancel", headers=auth)
    assert r.status_code == 409


def test_order_requires_auth(client):
    assert client.get("/api/v1/orders").status_code == 401


def _place(client, auth):
    menu = client.get("/api/v1/restaurants/2/menu").json()
    r = client.post(
        "/api/v1/orders",
        json={"restaurant_id": 2, "address": "Dostyk 1", "items": [{"menu_item_id": menu[0]["id"], "quantity": 1}]},
        headers=auth,
    )
    assert r.status_code == 201
    return r.json()["id"]


def test_courier_flow(client, auth, courier, admin):
    oid = _place(client, auth)

    # pending order is not yet pickable
    assert oid not in [o["id"] for o in client.get("/api/v1/orders/available", headers=courier).json()]
    assert client.post(f"/api/v1/orders/{oid}/accept", headers=courier).status_code == 409

    r = client.patch(f"/api/v1/orders/{oid}/status", json={"status": "confirmed"}, headers=admin)
    assert r.status_code == 200

    assert oid in [o["id"] for o in client.get("/api/v1/orders/available", headers=courier).json()]
    r = client.post(f"/api/v1/orders/{oid}/accept", headers=courier)
    assert r.status_code == 200
    assert r.json()["courier"]["name"] == "Courier Bek"

    # second accept refused
    assert client.post(f"/api/v1/orders/{oid}/accept", headers=courier).status_code == 409

    for expected in ("preparing", "on_the_way", "delivered"):
        r = client.post(f"/api/v1/orders/{oid}/advance", headers=courier)
        assert r.status_code == 200, r.text
        assert r.json()["status"] == expected

    assert client.post(f"/api/v1/orders/{oid}/advance", headers=courier).status_code == 409

    # customer sees courier on their order, courier sees it in own list
    assert client.get(f"/api/v1/orders/{oid}", headers=auth).json()["courier"]["id"]
    assert oid in [o["id"] for o in client.get("/api/v1/orders", headers=courier).json()]


def test_customer_cannot_use_courier_endpoints(client, auth):
    assert client.get("/api/v1/orders/available", headers=auth).status_code == 403


def test_admin_menu_and_restaurant(client, admin, auth):
    # customer forbidden
    assert client.get("/api/v1/admin/restaurants", headers=auth).status_code == 403

    r = client.post(
        "/api/v1/admin/restaurants/3/menu",
        json={"name": "Onion Rings", "price": 1100, "category": "Sides"},
        headers=admin,
    )
    assert r.status_code == 201
    item_id = r.json()["id"]

    r = client.patch(f"/api/v1/admin/menu/{item_id}", json={"is_available": False, "price": 1200}, headers=admin)
    assert r.json() == {**r.json(), "is_available": False, "price": 1200}

    # unavailable item cannot be ordered
    r = client.post(
        "/api/v1/orders",
        json={"restaurant_id": 3, "address": "Abay 1", "items": [{"menu_item_id": item_id, "quantity": 1}]},
        headers=auth,
    )
    assert r.status_code == 400

    # closing restaurant hides it from public list
    client.patch("/api/v1/admin/restaurants/3", json={"is_open": False}, headers=admin)
    assert 3 not in [x["id"] for x in client.get("/api/v1/restaurants").json()]
    assert 3 in [x["id"] for x in client.get("/api/v1/admin/restaurants", headers=admin).json()]
    client.patch("/api/v1/admin/restaurants/3", json={"is_open": True}, headers=admin)

    assert client.delete(f"/api/v1/admin/menu/{item_id}", headers=admin).status_code == 204


def test_order_carries_customer_and_restaurant(client, auth):
    oid = _place(client, auth)
    o = client.get(f"/api/v1/orders/{oid}", headers=auth).json()
    assert o["customer"]["name"] == "Test User"
    assert o["restaurant_name"] == "Pizza Roma"


def test_ws_receives_order_events(client, auth, admin):
    token = auth["Authorization"].split()[1]
    with client.websocket_connect(f"/api/v1/ws?token={token}") as ws:
        oid = _place(client, auth)
        evt = ws.receive_json()
        assert evt["type"] == "order.updated"
        assert evt["order"]["id"] == oid
        assert evt["order"]["status"] == "pending"

        client.patch(f"/api/v1/orders/{oid}/status", json={"status": "confirmed"}, headers=admin)
        assert ws.receive_json()["order"]["status"] == "confirmed"


def test_ws_rejects_bad_token(client):
    import pytest
    from starlette.websockets import WebSocketDisconnect

    with pytest.raises(WebSocketDisconnect), client.websocket_connect("/api/v1/ws?token=nope"):
        pass


def test_profile_and_addresses(client, auth):
    r = client.patch("/api/v1/me", json={"phone": "+77009998877"}, headers=auth)
    assert r.json()["phone"] == "+77009998877"

    a1 = client.post("/api/v1/me/addresses", json={"label": "Home", "line": "Abay 10"}, headers=auth).json()
    assert a1["is_default"] is True  # first address becomes default
    a2 = client.post(
        "/api/v1/me/addresses", json={"label": "Work", "line": "Dostyk 1", "is_default": True}, headers=auth
    ).json()
    lst = client.get("/api/v1/me/addresses", headers=auth).json()
    assert [a["is_default"] for a in lst] == [False, True]

    assert client.delete(f"/api/v1/me/addresses/{a2['id']}", headers=auth).status_code == 204
    lst = client.get("/api/v1/me/addresses", headers=auth).json()
    assert lst[0]["id"] == a1["id"] and lst[0]["is_default"] is True


def test_rate_order_updates_restaurant(client, auth, admin, courier):
    before = client.get("/api/v1/restaurants/2").json()
    oid = _place(client, auth)
    # not delivered yet
    assert client.post(f"/api/v1/orders/{oid}/rate", json={"rating": 5}, headers=auth).status_code == 409

    client.patch(f"/api/v1/orders/{oid}/status", json={"status": "confirmed"}, headers=admin)
    client.post(f"/api/v1/orders/{oid}/accept", headers=courier)
    for _ in range(3):
        client.post(f"/api/v1/orders/{oid}/advance", headers=courier)

    r = client.post(f"/api/v1/orders/{oid}/rate", json={"rating": 5}, headers=auth)
    assert r.status_code == 200 and r.json()["rating"] == 5
    assert client.post(f"/api/v1/orders/{oid}/rate", json={"rating": 1}, headers=auth).status_code == 409

    after = client.get("/api/v1/restaurants/2").json()
    assert after["rating_count"] == before["rating_count"] + 1
    expected = round((before["rating"] * before["rating_count"] + 5) / after["rating_count"], 2)
    assert after["rating"] == expected


def test_cuisines(client):
    assert client.get("/api/v1/restaurants/cuisines").json() == ["American", "Asian", "Italian"]


def test_prod_guard_rejects_default_secret():
    import pytest

    from app.core.config import Settings

    with pytest.raises(RuntimeError):
        Settings(env="prod", secret_key="change-me").validate_for_prod()
    Settings(env="prod", secret_key="x" * 48).validate_for_prod()
