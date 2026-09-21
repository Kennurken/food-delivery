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
