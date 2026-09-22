from app.core.access import has_permission
from app.core.features import entitlements, plan_of
from app.core.qr import parse_table_token, table_token


def test_permission_matrix():
    assert has_permission("owner", "billing.manage")
    assert has_permission("waiter", "tables.write")
    assert not has_permission("waiter", "staff.write")
    assert not has_permission("kitchen", "menu.write")
    assert has_permission("accountant", "billing.read")


def test_basic_plan_has_no_delivery():
    basic = plan_of("basic")
    assert "table.ordering" in basic["features"]
    assert "delivery.enabled" not in basic["features"]
    assert "delivery.enabled" in plan_of("pro")["features"]
    assert basic["limits"]["tables.max"] == 20
    assert plan_of("premium")["limits"]["tables.max"] is None


def test_request_id_header(client):
    r = client.get("/health")
    assert r.status_code == 200
    assert r.headers.get("x-request-id")


def test_plans_are_public(client):
    r = client.get("/api/v1/billing/plans")
    assert r.status_code == 200
    codes = {p["code"] for p in r.json()}
    assert codes == {"basic", "pro", "premium"}
    assert all(p["billed"] is False for p in r.json())


def test_platform_overview_admin_only(client, auth, admin):
    assert client.get("/api/v1/platform/overview", headers=auth).status_code == 403
    r = client.get("/api/v1/platform/overview", headers=admin)
    assert r.status_code == 200
    body = r.json()
    assert body["restaurants"] >= 3
    assert body["billing"] == "unconfigured"
    assert "mrr" not in body
    assert body["plans"].get("pro", 0) >= 3


def test_tenant_isolation_floors(client, admin):
    a = client.post(
        "/api/v1/admin/restaurants/1/floors",
        json={"name": "Hall A", "template": "cafe"},
        headers=admin,
    ).json()
    b = client.post(
        "/api/v1/admin/restaurants/2/floors",
        json={"name": "Hall B"},
        headers=admin,
    ).json()

    reg = client.post(
        "/api/v1/auth/register",
        json={"email": "alice-staff@x.com", "name": "Alice", "password": "secret1"},
    )
    assert reg.status_code == 201
    alice = {"Authorization": f"Bearer {reg.json()['access_token']}"}

    assert client.get("/api/v1/admin/restaurants/1/floors", headers=alice).status_code == 403

    added = client.post(
        "/api/v1/admin/restaurants/1/staff",
        json={"email": "alice-staff@x.com", "role": "manager"},
        headers=admin,
    )
    assert added.status_code == 201, added.text

    own = client.get("/api/v1/admin/restaurants/1/floors", headers=alice)
    assert own.status_code == 200
    assert any(f["id"] == a["id"] for f in own.json())

    other = client.get("/api/v1/admin/restaurants/2/floors", headers=alice)
    assert other.status_code == 403
    assert client.get(f"/api/v1/admin/floors/{b['id']}", headers=alice).status_code == 403
    assert client.get(f"/api/v1/admin/floors/{a['id']}", headers=alice).status_code == 200

    mine = client.get("/api/v1/me/memberships", headers=alice).json()
    assert mine[0]["restaurant_id"] == 1
    assert mine[0]["role"] == "manager"


def test_qr_table_order(client, auth, admin, courier):
    created = client.post(
        "/api/v1/admin/restaurants/1/floors",
        json={"name": "QR Hall", "template": "cafe"},
        headers=admin,
    )
    assert created.status_code == 201, created.text
    table = next(o for o in created.json()["objects"] if o["kind"].startswith("table"))
    fid = created.json()["id"]
    qr = client.get(f"/api/v1/admin/floors/{fid}/objects/{table['id']}/qr", headers=admin)
    assert qr.status_code == 200, qr.text
    token = qr.json()["token"]
    assert parse_table_token(token) == (1, table["id"])
    assert parse_table_token(token[:-1] + "0") is None
    assert table_token(1, table["id"]) == token

    public = client.get(f"/api/v1/qr/{token}")
    assert public.status_code == 200
    assert public.json()["restaurant_id"] == 1
    assert public.json()["table"]["id"] == table["id"]
    assert "hashed_password" not in str(public.json())

    menu = client.get("/api/v1/restaurants/1/menu").json()
    r = client.post(
        "/api/v1/orders",
        json={
            "restaurant_id": 1,
            "qr_token": token,
            "items": [{"menu_item_id": menu[0]["id"], "quantity": 1}],
        },
        headers=auth,
    )
    assert r.status_code == 201, r.text
    order = r.json()
    assert order["channel"] == "qr_table"
    assert order["delivery_fee"] == 0
    assert order["total"] == order["subtotal"]
    assert order["table_object_id"] == table["id"]
    assert table["name"] in order["address"]

    oid = order["id"]
    assert oid not in [o["id"] for o in client.get("/api/v1/orders/available", headers=courier).json()]
    assert client.patch(f"/api/v1/orders/{oid}/status", json={"status": "confirmed"}, headers=admin).status_code == 200
    assert client.patch(f"/api/v1/orders/{oid}/status", json={"status": "preparing"}, headers=admin).status_code == 200
    ready = client.patch(f"/api/v1/orders/{oid}/status", json={"status": "on_the_way"}, headers=admin)
    assert ready.status_code == 200, ready.text
    assert ready.json()["status"] == "on_the_way"
    done = client.patch(f"/api/v1/orders/{oid}/status", json={"status": "delivered"}, headers=admin)
    assert done.status_code == 200, done.text
    assert done.json()["status"] == "delivered"


def test_pickup_and_kitchen_board(client, auth, admin, courier):
    listed = client.get("/api/v1/restaurants/1").json()
    assert listed["channels"] == ["delivery", "pickup", "qr_table"]

    menu = client.get("/api/v1/restaurants/1/menu").json()
    r = client.post(
        "/api/v1/orders",
        json={
            "restaurant_id": 1,
            "channel": "pickup",
            "items": [{"menu_item_id": menu[0]["id"], "quantity": 1}],
        },
        headers=auth,
    )
    assert r.status_code == 201, r.text
    order = r.json()
    assert order["channel"] == "pickup"
    assert order["delivery_fee"] == 0
    assert order["total"] == order["subtotal"]
    assert order["address"].startswith("Pickup")
    oid = order["id"]
    assert oid not in [o["id"] for o in client.get("/api/v1/orders/available", headers=courier).json()]
    assert client.post(f"/api/v1/orders/{oid}/accept", headers=courier).status_code == 409
    assert client.get("/api/v1/orders", params={"restaurant_id": 1}, headers=auth).status_code == 403

    board = client.get("/api/v1/orders", params={"restaurant_id": 1}, headers=admin)
    assert board.status_code == 200
    assert oid in [o["id"] for o in board.json()]

    cook = client.post(
        "/api/v1/auth/register",
        json={"email": "cook-kds@x.com", "name": "Cook", "password": "secret1"},
    )
    assert cook.status_code == 201
    kitchen = {"Authorization": f"Bearer {cook.json()['access_token']}"}
    assert client.get("/api/v1/orders", params={"restaurant_id": 1}, headers=kitchen).status_code == 403
    added = client.post(
        "/api/v1/admin/restaurants/1/staff",
        json={"email": "cook-kds@x.com", "role": "kitchen"},
        headers=admin,
    )
    assert added.status_code == 201, added.text
    tickets = client.get("/api/v1/orders", params={"restaurant_id": 1}, headers=kitchen)
    assert tickets.status_code == 200
    assert oid in [o["id"] for o in tickets.json()]
    assert oid not in [o["id"] for o in client.get("/api/v1/orders", headers=kitchen).json()]

    other_menu = client.get("/api/v1/restaurants/2/menu").json()
    other = client.post(
        "/api/v1/orders",
        json={
            "restaurant_id": 2,
            "address": "Dostyk 1",
            "items": [{"menu_item_id": other_menu[0]["id"], "quantity": 1}],
        },
        headers=auth,
    ).json()
    assert client.patch(
        f"/api/v1/orders/{other['id']}/status", json={"status": "confirmed"}, headers=kitchen
    ).status_code == 403

    for expected in ("confirmed", "preparing", "on_the_way", "delivered"):
        step = client.patch(f"/api/v1/orders/{oid}/status", json={"status": expected}, headers=kitchen)
        assert step.status_code == 200, step.text
        assert step.json()["status"] == expected


def test_basic_plan_blocks_delivery(client, auth, admin):
    r = client.post(
        "/api/v1/admin/restaurants",
        json={"name": "Solo Cafe", "cuisine": "Cafe", "delivery_fee": 0, "delivery_time_min": 15},
        headers=admin,
    )
    assert r.status_code == 201, r.text
    rid = r.json()["id"]
    client.patch(f"/api/v1/admin/restaurants/{rid}", json={"plan_code": "basic"}, headers=admin)
    item = client.post(
        f"/api/v1/admin/restaurants/{rid}/menu",
        json={"name": "Tea", "price": 500, "category": "Drinks"},
        headers=admin,
    ).json()
    blocked = client.post(
        "/api/v1/orders",
        json={"restaurant_id": rid, "address": "Abay 1", "items": [{"menu_item_id": item["id"], "quantity": 1}]},
        headers=auth,
    )
    assert blocked.status_code == 403
    pickup = client.post(
        "/api/v1/orders",
        json={
            "restaurant_id": rid,
            "channel": "pickup",
            "items": [{"menu_item_id": item["id"], "quantity": 1}],
        },
        headers=auth,
    )
    assert pickup.status_code == 403
    pub = client.get(f"/api/v1/restaurants/{rid}").json()
    assert pub["channels"] == ["qr_table"]

    client.put(
        f"/api/v1/admin/restaurants/{rid}/features",
        json={"key": "delivery.enabled", "enabled": True},
        headers=admin,
    )
    allowed = client.post(
        "/api/v1/orders",
        json={"restaurant_id": rid, "address": "Abay 1", "items": [{"menu_item_id": item["id"], "quantity": 1}]},
        headers=auth,
    )
    assert allowed.status_code == 201, allowed.text


def test_order_idempotency(client, auth):
    menu = client.get("/api/v1/restaurants/1/menu").json()
    payload = {
        "restaurant_id": 1,
        "address": "Abay 10",
        "items": [{"menu_item_id": menu[0]["id"], "quantity": 1}],
    }
    headers = {**auth, "Idempotency-Key": "cart-abc-1"}
    a = client.post("/api/v1/orders", json=payload, headers=headers)
    b = client.post("/api/v1/orders", json=payload, headers=headers)
    assert a.status_code == 201
    assert b.status_code == 201
    assert a.json()["id"] == b.json()["id"]
    other = client.post(
        "/api/v1/orders",
        json={**payload, "address": "Abay 99"},
        headers={**auth, "Idempotency-Key": "cart-abc-1"},
    )
    assert other.status_code == 409


def test_workspace_and_plan_change_audited(client, admin):
    ws = client.get("/api/v1/admin/restaurants/1/workspace", headers=admin)
    assert ws.status_code == 200
    assert "delivery.enabled" in ws.json()["features"]
    assert ws.json()["setup"]["has_menu"] is True

    r = client.patch("/api/v1/admin/restaurants/1", json={"plan_code": "premium"}, headers=admin)
    assert r.status_code == 200
    assert r.json()["plan_code"] == "premium"
    logs = client.get("/api/v1/platform/audit", headers=admin).json()
    assert any(row["action"] == "subscription.change" for row in logs)
    client.patch("/api/v1/admin/restaurants/1", json={"plan_code": "pro"}, headers=admin)


def test_entitlements_follow_overrides(client, admin):
    from app.db.session import SessionLocal
    from app.models import Restaurant

    with SessionLocal() as db:
        r = db.get(Restaurant, 1)
        flags = entitlements(db, r)
        assert flags.enabled("delivery.enabled")
        assert flags.limit("tables.max") == 100
