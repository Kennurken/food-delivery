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
    assert len(r.json()) >= 3


def test_search_matches_dish_name(client):
    by_dish = client.get("/api/v1/restaurants", params={"q": "ramen"}).json()
    assert any(r["name"] == "Bao Bar" for r in by_dish)
    by_cuisine = client.get("/api/v1/restaurants", params={"q": "italian"}).json()
    assert [r["name"] for r in by_cuisine] == ["Pizza Roma"]
    menu = client.get("/api/v1/restaurants/1/menu").json()
    assert any(item.get("image_url") for item in menu)


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


def test_refresh_token_flow(client):
    r = client.post("/api/v1/auth/login/json", json={"email": "user@food.dev", "password": "user123"})
    tokens = r.json()
    assert tokens["refresh_token"]
    # refresh token cannot be used as access token
    assert client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {tokens['refresh_token']}"}).status_code == 401
    r = client.post("/api/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]})
    assert r.status_code == 200
    new_access = r.json()["access_token"]
    assert client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {new_access}"}).status_code == 200
    # access token cannot be used to refresh
    assert client.post("/api/v1/auth/refresh", json={"refresh_token": tokens["access_token"]}).status_code == 401


def test_orders_pagination(client, auth):
    for _ in range(3):
        _place(client, auth)
    page1 = client.get("/api/v1/orders?limit=2&offset=0", headers=auth).json()
    page2 = client.get("/api/v1/orders?limit=2&offset=2", headers=auth).json()
    assert len(page1) == 2
    assert {o["id"] for o in page1}.isdisjoint({o["id"] for o in page2})
    assert page1[0]["id"] > page1[1]["id"]  # newest first


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
    assert o["items"][0]["menu_item_id"]


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


def test_change_password(client, auth):
    assert (
        client.post(
            "/api/v1/me/password",
            json={"current_password": "wrong", "new_password": "newpass1"},
            headers=auth,
        ).status_code
        == 400
    )
    assert client.post("/api/v1/me/password", json={"current_password": "user123", "new_password": "x"}).status_code == 401
    r = client.post(
        "/api/v1/me/password",
        json={"current_password": "user123", "new_password": "newpass1"},
        headers=auth,
    )
    assert r.status_code == 204
    assert client.post("/api/v1/auth/login/json", json={"email": "user@food.dev", "password": "user123"}).status_code == 401
    assert client.post("/api/v1/auth/login/json", json={"email": "user@food.dev", "password": "newpass1"}).status_code == 200
    # later tests reuse the user123 fixture login — put it back
    assert (
        client.post(
            "/api/v1/me/password",
            json={"current_password": "newpass1", "new_password": "user123"},
            headers=auth,
        ).status_code
        == 204
    )


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
    assert {"American", "Asian", "Italian"} <= set(client.get("/api/v1/restaurants/cuisines").json())


def test_prod_guard_rejects_default_secret():
    import pytest

    from app.core.config import Settings

    with pytest.raises(RuntimeError, match="SECRET_KEY"):
        Settings(env="prod", secret_key="change-me").validate_for_prod()
    with pytest.raises(RuntimeError, match="SECRET_KEY"):
        Settings(env="prod", secret_key="").validate_for_prod()
    assert Settings(allow_ephemeral_db="").allow_ephemeral_db is False
    with pytest.raises(RuntimeError, match="CORS_ORIGINS"):
        Settings(env="prod", secret_key="x" * 48, cors_origins="*").validate_for_prod()
    with pytest.raises(RuntimeError, match="DATABASE_URL"):
        Settings(
            env="prod",
            secret_key="x" * 48,
            cors_origins="",
            database_url="sqlite:///./food.db",
        ).validate_for_prod()
    Settings(
        env="prod",
        secret_key="x" * 48,
        cors_origins="none",
        cors_origin_regex=r"https://.*\.vercel\.app",
        allow_ephemeral_db=True,
        database_url="sqlite:////tmp/food.db",
    ).validate_for_prod()


def test_idor_customer_cannot_read_foreign_order(client, auth):
    oid = _place(client, auth)
    other = client.post(
        "/api/v1/auth/register",
        json={"email": "other@x.com", "name": "Other", "password": "secret1"},
    ).json()["access_token"]
    r = client.get(f"/api/v1/orders/{oid}", headers={"Authorization": f"Bearer {other}"})
    assert r.status_code == 404


def test_malformed_jwt_subject_is_401(client):
    from datetime import timedelta

    from app.core.security import _encode

    token = _encode("not-an-int", "access", timedelta(minutes=5))
    assert client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {token}"}).status_code == 401


def test_admin_can_create_restaurant(client, admin):
    r = client.post(
        "/api/v1/admin/restaurants",
        json={"name": "Lagman House", "cuisine": "Kazakh", "delivery_fee": 400},
        headers=admin,
    )
    assert r.status_code == 201, r.text
    assert r.json()["cuisine"] == "Kazakh"
    assert any(x["id"] == r.json()["id"] for x in client.get("/api/v1/restaurants").json())


def test_set_default_address(client, auth):
    a1 = client.post("/api/v1/me/addresses", json={"label": "Home", "line": "Abay 10"}, headers=auth).json()
    a2 = client.post("/api/v1/me/addresses", json={"label": "Work", "line": "Dostyk 1"}, headers=auth).json()
    r = client.patch(f"/api/v1/me/addresses/{a2['id']}", json={"is_default": True}, headers=auth)
    assert r.status_code == 200 and r.json()["is_default"] is True
    lst = client.get("/api/v1/me/addresses", headers=auth).json()
    by_id = {a["id"]: a["is_default"] for a in lst}
    assert by_id[a1["id"]] is False and by_id[a2["id"]] is True



def test_login_rate_limited(client, monkeypatch):
    from app.core.config import settings
    from app.core.ratelimit import limiter

    limiter.reset()
    monkeypatch.setattr(settings, "login_rate_limit", "2/minute")
    bad = {"email": "nobody@food.dev", "password": "x" * 8}
    assert client.post("/api/v1/auth/login/json", json=bad).status_code == 401
    assert client.post("/api/v1/auth/login/json", json=bad).status_code == 401
    assert client.post("/api/v1/auth/login/json", json=bad).status_code == 429
    limiter.reset()
