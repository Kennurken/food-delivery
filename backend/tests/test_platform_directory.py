"""The platform admin's tenant directory: who runs each restaurant and how it trades."""


def _names(rows):
    return [r["name"] for r in rows]


def test_directory_is_admin_only(client, auth, courier, admin):
    assert client.get("/api/v1/platform/restaurants", headers=auth).status_code == 403
    assert client.get("/api/v1/platform/restaurants", headers=courier).status_code == 403
    assert client.get("/api/v1/platform/restaurants").status_code == 401
    assert client.get("/api/v1/platform/restaurants", headers=admin).status_code == 200


def test_directory_lists_every_tenant_with_its_owner(client, admin):
    rows = client.get("/api/v1/platform/restaurants", headers=admin).json()
    assert len(rows) >= 3
    assert _names(rows) == sorted(_names(rows))  # stable, name-ordered

    bao = next(r for r in rows if r["name"] == "Bao Bar")
    assert bao["owner"]["role"] == "owner"
    assert bao["owner"]["email"] and bao["owner"]["phone"]
    assert bao["staff_count"] >= 1
    assert bao["plan_code"] and bao["billing_status"]


def test_directory_search_narrows_by_name(client, admin):
    rows = client.get("/api/v1/platform/restaurants?q=bao", headers=admin).json()
    assert _names(rows) == ["Bao Bar"]


def test_revenue_counts_only_money_that_actually_moved(client, auth, admin, courier):
    """A delivered cash ticket earns; an unpaid card ticket does not."""
    before = next(
        r
        for r in client.get("/api/v1/platform/restaurants", headers=admin).json()
        if r["id"] == 1
    )

    menu = client.get("/api/v1/restaurants/1/menu").json()
    order_id = client.post(
        "/api/v1/orders",
        json={
            "restaurant_id": 1,
            "address": "Abay 10",
            "items": [{"menu_item_id": menu[0]["id"], "quantity": 1}],
            "pay_method": "cash",
        },
        headers=auth,
    ).json()["id"]

    mid = next(
        r
        for r in client.get("/api/v1/platform/restaurants", headers=admin).json()
        if r["id"] == 1
    )
    assert mid["orders_total"] == before["orders_total"] + 1
    # Still pending, so nothing earned yet.
    assert mid["revenue_total"] == before["revenue_total"]

    client.patch(
        f"/api/v1/orders/{order_id}/status", json={"status": "confirmed"}, headers=admin
    )
    client.post(f"/api/v1/orders/{order_id}/accept", headers=courier)
    client.patch(
        f"/api/v1/orders/{order_id}/status", json={"status": "preparing"}, headers=admin
    )
    for _ in range(2):
        client.post(f"/api/v1/orders/{order_id}/advance", headers=courier)

    after = next(
        r
        for r in client.get("/api/v1/platform/restaurants", headers=admin).json()
        if r["id"] == 1
    )
    assert after["revenue_total"] > before["revenue_total"]


def test_detail_carries_staff_and_recent_orders(client, admin):
    card = client.get("/api/v1/platform/restaurants/1", headers=admin).json()
    assert card["name"] == "Bao Bar"
    assert any(s["role"] == "owner" for s in card["staff"])
    assert len(card["recent_orders"]) <= 10
    for order in card["recent_orders"]:
        assert {"id", "status", "total", "pay_status"} <= set(order)


def test_detail_404s_on_a_restaurant_that_is_not_there(client, admin):
    assert client.get("/api/v1/platform/restaurants/9999", headers=admin).status_code == 404
