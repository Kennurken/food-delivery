from datetime import UTC, datetime, timedelta


def _menu_item(client, restaurant_id=1, name="Pork Bao"):
    menu = client.get(f"/api/v1/restaurants/{restaurant_id}/menu").json()
    return next(i for i in menu if i["name"] == name)


def test_bao10_takes_ten_percent(client, auth):
    bao = _menu_item(client)
    preview = client.get(
        "/api/v1/restaurants/1/promo",
        params={"code": "bao10", "subtotal": bao["price"] * 2},
    )
    assert preview.status_code == 200, preview.text
    assert preview.json()["code"] == "BAO10"
    assert preview.json()["discount"] == round(bao["price"] * 2 * 0.1, 2)

    r = client.post(
        "/api/v1/orders",
        json={
            "restaurant_id": 1,
            "address": "Abay 10",
            "promo_code": "bao10",
            "items": [{"menu_item_id": bao["id"], "quantity": 2}],
        },
        headers=auth,
    )
    assert r.status_code == 201, r.text
    order = r.json()
    assert order["promo_code"] == "BAO10"
    assert order["discount"] == round(order["subtotal"] * 0.1, 2)
    assert order["total"] == round(order["subtotal"] + order["delivery_fee"] - order["discount"], 2)


def test_promo_below_minimum_rejected(client, auth):
    bao = _menu_item(client)
    r = client.post(
        "/api/v1/orders",
        json={
            "restaurant_id": 1,
            "address": "Abay 10",
            "promo_code": "BAO10",
            "items": [{"menu_item_id": bao["id"], "quantity": 1}],
        },
        headers=auth,
    )
    assert r.status_code == 400


def test_unknown_promo_rejected(client, auth):
    bao = _menu_item(client)
    r = client.post(
        "/api/v1/orders",
        json={
            "restaurant_id": 1,
            "address": "Abay 10",
            "promo_code": "NOPE99",
            "items": [{"menu_item_id": bao["id"], "quantity": 2}],
        },
        headers=auth,
    )
    assert r.status_code == 400


def test_schedule_too_soon_rejected(client, auth):
    bao = _menu_item(client)
    soon = (datetime.now(UTC) + timedelta(minutes=5)).isoformat()
    r = client.post(
        "/api/v1/orders",
        json={
            "restaurant_id": 1,
            "address": "Abay 10",
            "scheduled_for": soon,
            "items": [{"menu_item_id": bao["id"], "quantity": 1}],
        },
        headers=auth,
    )
    assert r.status_code == 400


def test_scheduled_order_hides_from_couriers(client, auth, courier, admin):
    bao = _menu_item(client)
    when = (datetime.now(UTC) + timedelta(hours=3)).isoformat()
    r = client.post(
        "/api/v1/orders",
        json={
            "restaurant_id": 1,
            "address": "Abay 10",
            "scheduled_for": when,
            "items": [{"menu_item_id": bao["id"], "quantity": 1}],
        },
        headers=auth,
    )
    assert r.status_code == 201, r.text
    order = r.json()
    assert order["scheduled_for"]
    oid = order["id"]
    client.patch(f"/api/v1/orders/{oid}/status", json={"status": "confirmed"}, headers=admin)
    ids = [o["id"] for o in client.get("/api/v1/orders/available", headers=courier).json()]
    assert oid not in ids
    assert client.post(f"/api/v1/orders/{oid}/accept", headers=courier).status_code == 409


def test_admin_can_toggle_promo(client, admin):
    rows = client.get("/api/v1/admin/restaurants/1/promos", headers=admin).json()
    bao = next(p for p in rows if p["code"] == "BAO10")
    r = client.patch(
        f"/api/v1/admin/promos/{bao['id']}",
        json={"is_active": False},
        headers=admin,
    )
    assert r.status_code == 200
    assert r.json()["is_active"] is False
    client.patch(
        f"/api/v1/admin/promos/{bao['id']}",
        json={"is_active": True},
        headers=admin,
    )
