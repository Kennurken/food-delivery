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
