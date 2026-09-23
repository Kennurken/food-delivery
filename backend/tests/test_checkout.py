def test_default_modifiers_keep_base_price(client, auth):
    menu = client.get("/api/v1/restaurants/1/menu").json()
    bao = next(i for i in menu if i["name"] == "Pork Bao")
    assert bao["modifier_groups"]
    r = client.post(
        "/api/v1/orders",
        json={
            "restaurant_id": 1,
            "address": "Abay 10",
            "items": [{"menu_item_id": bao["id"], "quantity": 1}],
        },
        headers=auth,
    )
    assert r.status_code == 201, r.text
    order = r.json()
    assert order["subtotal"] == bao["price"]
    assert order["pay_method"] == "cash"
    assert order["pay_status"] == "unpaid"
    names = [m["name"] for m in order["items"][0]["modifiers"]]
    assert "Regular" in names


def test_size_and_extras_add_to_line(client, auth):
    menu = client.get("/api/v1/restaurants/1/menu").json()
    bao = next(i for i in menu if i["name"] == "Pork Bao")
    size = next(g for g in bao["modifier_groups"] if g["name"] == "Size")
    extras = next(g for g in bao["modifier_groups"] if g["name"] == "Extras")
    large = next(o for o in size["options"] if o["name"] == "Large")
    egg = next(o for o in extras["options"] if o["name"] == "Egg")
    r = client.post(
        "/api/v1/orders",
        json={
            "restaurant_id": 1,
            "address": "Abay 10",
            "items": [
                {
                    "menu_item_id": bao["id"],
                    "quantity": 2,
                    "option_ids": [large["id"], egg["id"]],
                }
            ],
        },
        headers=auth,
    )
    assert r.status_code == 201, r.text
    unit = bao["price"] + large["price_delta"] + egg["price_delta"]
    assert r.json()["subtotal"] == unit * 2
    assert r.json()["items"][0]["price"] == unit


def test_missing_required_size_rejected_when_defaults_cleared(client, admin, auth):
    menu = client.get("/api/v1/restaurants/1/menu").json()
    bao = next(i for i in menu if i["name"] == "Pork Bao")
    r = client.put(
        f"/api/v1/admin/menu/{bao['id']}/modifiers",
        json=[
            {
                "name": "Size",
                "required": True,
                "min_select": 1,
                "max_select": 1,
                "options": [{"name": "Large", "price_delta": 400, "is_default": False}],
            }
        ],
        headers=admin,
    )
    assert r.status_code == 200, r.text
    miss = client.post(
        "/api/v1/orders",
        json={
            "restaurant_id": 1,
            "address": "Abay 10",
            "items": [{"menu_item_id": bao["id"], "quantity": 1, "option_ids": []}],
        },
        headers=auth,
    )
    assert miss.status_code == 400
    # restore seed-like defaults so later tests stay stable
    client.put(
        f"/api/v1/admin/menu/{bao['id']}/modifiers",
        json=[
            {
                "name": "Size",
                "required": True,
                "min_select": 1,
                "max_select": 1,
                "options": [
                    {"name": "Regular", "price_delta": 0, "is_default": True},
                    {"name": "Large", "price_delta": 400, "is_default": False},
                ],
            },
            {
                "name": "Extras",
                "required": False,
                "min_select": 0,
                "max_select": 3,
                "options": [
                    {"name": "Egg", "price_delta": 200},
                    {"name": "Chili oil", "price_delta": 100},
                ],
            },
        ],
        headers=admin,
    )


def test_card_checkout_stays_honest(client, auth):
    menu = client.get("/api/v1/restaurants/1/menu").json()
    r = client.post(
        "/api/v1/orders",
        json={
            "restaurant_id": 1,
            "address": "Abay 10",
            "pay_method": "online",
            "items": [{"menu_item_id": menu[0]["id"], "quantity": 1}],
        },
        headers=auth,
    )
    assert r.status_code == 409
    assert "cash" in r.json()["detail"].lower()


def test_billing_config_hides_card_without_key(client):
    body = client.get("/api/v1/billing/config").json()
    assert body["card"] is False


def test_stripe_checkout_stays_pending_until_stripe_says_paid(client, auth, admin, monkeypatch):
    from app.core.billing import PaymentResult
    from app.services import order_service as svc

    monkeypatch.setattr(svc, "card_connected", lambda: True)

    def fake_checkout(**kwargs):
        assert kwargs["order_id"] > 0
        return PaymentResult(
            provider="stripe",
            reference="cs_test_1",
            status="pending",
            url="https://checkout.stripe.com/c/pay/cs_test_1",
        )

    monkeypatch.setattr(svc, "create_checkout_session", fake_checkout)
    menu = client.get("/api/v1/restaurants/1/menu").json()
    r = client.post(
        "/api/v1/orders",
        json={
            "restaurant_id": 1,
            "address": "Abay 10",
            "pay_method": "online",
            "items": [{"menu_item_id": menu[0]["id"], "quantity": 1}],
        },
        headers=auth,
    )
    assert r.status_code == 201, r.text
    order = r.json()
    assert order["pay_method"] == "online"
    assert order["pay_status"] == "pending"
    assert order["checkout_url"].startswith("https://checkout.stripe.com/")
    oid = order["id"]
    ids = [
        o["id"]
        for o in client.get("/api/v1/orders", params={"restaurant_id": 1}, headers=admin).json()
    ]
    assert oid not in ids

    monkeypatch.setattr(svc, "session_is_paid", lambda _ref: True)
    synced = client.post(f"/api/v1/orders/{oid}/pay/sync", headers=auth)
    assert synced.status_code == 200, synced.text
    assert synced.json()["pay_status"] == "paid"
    ids = [
        o["id"]
        for o in client.get("/api/v1/orders", params={"restaurant_id": 1}, headers=admin).json()
    ]
    assert oid in ids


def test_unknown_modifier_rejected(client, auth):
    menu = client.get("/api/v1/restaurants/1/menu").json()
    bao = next(i for i in menu if i["name"] == "Pork Bao")
    size = next(g for g in bao["modifier_groups"] if g["name"] == "Size")
    regular = next(o for o in size["options"] if o["name"] == "Regular")
    r = client.post(
        "/api/v1/orders",
        json={
            "restaurant_id": 1,
            "address": "Abay 10",
            "items": [
                {
                    "menu_item_id": bao["id"],
                    "quantity": 1,
                    "option_ids": [regular["id"], 9_999_999],
                }
            ],
        },
        headers=auth,
    )
    assert r.status_code == 400


def test_push_is_noop_without_key():
    from app.core.push import send

    assert send(["token-long-enough"], title="Order", body="Hi", data={}) == 0


def test_device_token_roundtrip(client, auth):
    r = client.put(
        "/api/v1/me/devices",
        json={"token": "fcm-token-example-1", "platform": "android"},
        headers=auth,
    )
    assert r.status_code == 204
    r = client.delete(
        "/api/v1/me/devices",
        params={"token": "fcm-token-example-1"},
        headers=auth,
    )
    assert r.status_code == 204


def test_stripe_amount_uses_two_decimals_for_tenge():
    """KZT is not a Stripe zero-decimal currency: 2900 ₸ must become 290000."""
    from app.core.billing import _stripe_amount

    assert _stripe_amount(2900, "KZT") == 290000
    assert _stripe_amount(2900, "JPY") == 2900  # zero-decimal stays whole
    assert _stripe_amount(19.99, "USD") == 1999


def test_checkout_asks_for_cards_by_name(monkeypatch):
    """Dynamic payment methods came back empty in tenge. Name the card explicitly."""
    import stripe

    from app.core import billing
    from app.core.config import settings

    monkeypatch.setattr(settings, "stripe_secret_key", "sk_test_fake")
    seen: dict = {}

    def fake_create(**payload):
        seen.update(payload)
        return {"id": "cs_test_1", "url": "https://checkout.stripe.com/c/pay/cs_test_1"}

    monkeypatch.setattr(stripe.checkout.Session, "create", fake_create)

    result = billing.create_checkout_session(
        amount=2900,
        currency="KZT",
        description="Order #1",
        order_id=1,
        origin=None,
        idempotency_key="k",
    )

    assert result.status == "pending"
    assert seen["payment_method_types"] == ["card"]
    assert seen["line_items"][0]["price_data"]["unit_amount"] == 290000
    # The app routes on the fragment; a bare /orders/1 loses the ticket.
    assert seen["success_url"].endswith("/#/orders/1?paid=1")
    assert seen["cancel_url"].endswith("/#/orders/1?paid=0")


def test_cancelling_a_paid_card_order_refunds_it(client, auth, admin, monkeypatch):
    """Money must move back when the kitchen cancels a ticket the customer paid."""
    from app.services import order_service

    calls: list[str] = []
    monkeypatch.setattr(
        order_service, "refund_session", lambda ref: calls.append(ref) or "re_test_1"
    )

    menu = client.get("/api/v1/restaurants/1/menu").json()
    placed = client.post(
        "/api/v1/orders",
        json={
            "restaurant_id": 1,
            "address": "Abay 10",
            "items": [{"menu_item_id": menu[0]["id"], "quantity": 1}],
        },
        headers=auth,
    )
    assert placed.status_code == 201, placed.text
    order_id = placed.json()["id"]

    # Force the ticket into the state Stripe would leave behind after payment.
    from app.db.session import SessionLocal
    from app.models import Order

    with SessionLocal() as db:
        row = db.get(Order, order_id)
        row.pay_method = "online"
        row.pay_status = "paid"
        row.pay_ref = "cs_test_paid"
        db.commit()

    cancelled = client.post(f"/api/v1/orders/{order_id}/cancel", headers=auth)
    assert cancelled.status_code == 200, cancelled.text
    body = cancelled.json()
    assert body["status"] == "cancelled"
    assert body["pay_status"] == "refunded"
    assert calls == ["cs_test_paid"]


def test_failed_refund_does_not_claim_the_money_came_back(client, auth, monkeypatch):
    """A Stripe failure closes the ticket but must not lie about the refund."""
    from app.services import order_service

    monkeypatch.setattr(order_service, "refund_session", lambda ref: None)

    menu = client.get("/api/v1/restaurants/1/menu").json()
    order_id = client.post(
        "/api/v1/orders",
        json={
            "restaurant_id": 1,
            "address": "Abay 10",
            "items": [{"menu_item_id": menu[0]["id"], "quantity": 1}],
        },
        headers=auth,
    ).json()["id"]

    from app.db.session import SessionLocal
    from app.models import Order

    with SessionLocal() as db:
        row = db.get(Order, order_id)
        row.pay_method = "online"
        row.pay_status = "paid"
        row.pay_ref = "cs_test_paid"
        db.commit()

    body = client.post(f"/api/v1/orders/{order_id}/cancel", headers=auth).json()
    assert body["status"] == "cancelled"
    assert body["pay_status"] == "paid"  # still owed to the customer


def test_cancelling_a_cash_order_refunds_nothing(client, auth, monkeypatch):
    from app.services import order_service

    def explode(ref):  # pragma: no cover - must never run
        raise AssertionError("cash never reached Stripe")

    monkeypatch.setattr(order_service, "refund_session", explode)

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
    body = client.post(f"/api/v1/orders/{order_id}/cancel", headers=auth).json()
    assert body["status"] == "cancelled" and body["pay_status"] == "unpaid"
