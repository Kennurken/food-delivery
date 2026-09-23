"""Cash that reached the courier should stop reading as money nobody collected."""

from tests.conftest import deliver


def _cash_delivery(client, auth, admin, courier) -> int:
    menu = client.get("/api/v1/restaurants/1/menu").json()
    oid = client.post(
        "/api/v1/orders",
        json={
            "restaurant_id": 1,
            "address": "Abay 10",
            "dest_lat": 43.2389,
            "dest_lng": 76.9455,
            "items": [{"menu_item_id": menu[0]["id"], "quantity": 1}],
            "pay_method": "cash",
        },
        headers=auth,
    ).json()["id"]
    client.patch(f"/api/v1/orders/{oid}/status", json={"status": "confirmed"}, headers=admin)
    client.post(f"/api/v1/orders/{oid}/accept", headers=courier)
    client.patch(f"/api/v1/orders/{oid}/status", json={"status": "preparing"}, headers=admin)
    client.post(f"/api/v1/orders/{oid}/advance", headers=courier)
    return oid


def test_cash_is_unpaid_until_the_bag_changes_hands(client, auth, admin, courier):
    oid = _cash_delivery(client, auth, admin, courier)
    assert client.get(f"/api/v1/orders/{oid}", headers=auth).json()["pay_status"] == "unpaid"


def test_closing_a_cash_delivery_records_the_money_as_collected(
    client, auth, admin, courier
):
    oid = _cash_delivery(client, auth, admin, courier)
    assert deliver(client, oid, courier, auth)["pay_status"] == "collected"


def test_collected_is_not_reported_as_paid(client, auth, admin, courier):
    """No card was charged; the word has to stay distinguishable."""
    oid = _cash_delivery(client, auth, admin, courier)
    assert deliver(client, oid, courier, auth)["pay_status"] != "paid"


def test_a_cancelled_cash_order_collects_nothing(client, auth, admin):
    menu = client.get("/api/v1/restaurants/1/menu").json()
    oid = client.post(
        "/api/v1/orders",
        json={
            "restaurant_id": 1,
            "address": "Abay 10",
            "items": [{"menu_item_id": menu[0]["id"], "quantity": 1}],
            "pay_method": "cash",
        },
        headers=auth,
    ).json()["id"]
    body = client.post(f"/api/v1/orders/{oid}/cancel", headers=auth).json()
    assert body["status"] == "cancelled" and body["pay_status"] == "unpaid"


def test_a_paid_card_order_is_untouched_by_cash_settlement(client, auth, admin, courier):
    """Settling cash must never rewrite what Stripe already said."""
    from app.db.session import SessionLocal
    from app.models import Order

    oid = _cash_delivery(client, auth, admin, courier)
    with SessionLocal() as db:
        row = db.get(Order, oid)
        row.pay_method = "online"
        row.pay_status = "paid"
        db.commit()
    assert deliver(client, oid, courier, auth)["pay_status"] == "paid"


def test_collected_cash_still_counts_as_earned_revenue(client, auth, admin, courier):
    before = next(
        r
        for r in client.get("/api/v1/platform/restaurants", headers=admin).json()
        if r["id"] == 1
    )
    oid = _cash_delivery(client, auth, admin, courier)
    deliver(client, oid, courier, auth)
    after = next(
        r
        for r in client.get("/api/v1/platform/restaurants", headers=admin).json()
        if r["id"] == 1
    )
    assert after["revenue_total"] > before["revenue_total"]
