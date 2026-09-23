"""Venue subscriptions: who pays the platform, and what happens when they stop.

The whole point is that nothing here trusts this process about money. Every
status is written by a Stripe webhook, and the tests drive real signed events.
"""

import hashlib
import hmac
import json
import time

import pytest

from app.core import subscriptions
from app.core.config import settings
from app.db.session import SessionLocal
from app.models import Restaurant

WEBHOOK = "/api/v1/billing/stripe/webhook"
BILLING = "/api/v1/admin/restaurants/1/billing"
SECRET = "whsec_test_only_never_a_real_secret"


def _signed(event: dict) -> tuple[bytes, str]:
    payload = json.dumps(event).encode()
    stamp = int(time.time())
    digest = hmac.new(
        SECRET.encode(), f"{stamp}.".encode() + payload, hashlib.sha256
    ).hexdigest()
    return payload, f"t={stamp},v1={digest}"


def _send(client, event: dict):
    payload, signature = _signed(event)
    return client.post(
        WEBHOOK,
        content=payload,
        headers={"stripe-signature": signature, "Content-Type": "application/json"},
    )


def _subscription_event(
    etype: str,
    *,
    status: str,
    plan_code: str = "premium",
    restaurant_id: int = 1,
    period_end: int | None = None,
) -> dict:
    return {
        "id": "evt_sub_1",
        "type": etype,
        "data": {
            "object": {
                "id": "sub_test_1",
                "object": "subscription",
                "status": status,
                "current_period_end": period_end or int(time.time()) + 2_592_000,
                "metadata": {
                    "restaurant_id": str(restaurant_id),
                    "plan_code": plan_code,
                },
            }
        },
    }


@pytest.fixture(autouse=True)
def _restore(client):
    yield
    with SessionLocal() as db:
        venue = db.get(Restaurant, 1)
        venue.plan_code = "pro"
        venue.billing_status = "active"
        venue.stripe_subscription_id = None
        venue.plan_renews_at = None
        db.commit()


@pytest.fixture
def signed(monkeypatch):
    monkeypatch.setattr(settings, "stripe_webhook_secret", SECRET)


def _state(client, admin) -> dict:
    r = client.get(BILLING, headers=admin)
    assert r.status_code == 200, r.text
    return r.json()


class TestWhoMaySeeAndChange:
    def test_a_customer_cannot_read_the_bill(self, client, auth):
        assert client.get(BILLING, headers=auth).status_code in (403, 404)

    def test_a_courier_cannot_subscribe_a_venue(self, client, courier):
        r = client.post(
            f"{BILLING}/subscribe", json={"plan_code": "premium"}, headers=courier
        )

        assert r.status_code in (403, 404)


class TestState:
    def test_it_reports_the_plan_and_its_price(self, client, admin):
        body = _state(client, admin)

        assert body["plan_code"] == "pro"
        assert body["monthly_price"] > 0
        assert body["billed"] is True

    def test_a_venue_with_no_subscription_says_so(self, client, admin):
        body = _state(client, admin)

        assert body["has_subscription"] is False
        assert body["renews_at"] is None


class TestSubscribing:
    def test_a_free_plan_is_refused_rather_than_charged(self, client, admin):
        r = client.post(f"{BILLING}/subscribe", json={"plan_code": "basic"}, headers=admin)

        assert r.status_code == 400
        assert "free" in r.text.lower()

    def test_an_unknown_plan_is_refused(self, client, admin):
        r = client.post(f"{BILLING}/subscribe", json={"plan_code": "gold"}, headers=admin)

        assert r.status_code == 400

    def test_without_stripe_it_says_so_instead_of_pretending(self, client, admin):
        """Tests run with no keys. This must read as a message, not a 500."""
        r = client.post(f"{BILLING}/subscribe", json={"plan_code": "premium"}, headers=admin)

        assert r.status_code == 409
        assert "not connected" in r.text.lower()

    def test_opening_checkout_does_not_move_the_plan(self, client, admin):
        """Nobody has paid until Stripe says so."""
        before = _state(client, admin)["plan_code"]

        client.post(f"{BILLING}/subscribe", json={"plan_code": "premium"}, headers=admin)

        assert _state(client, admin)["plan_code"] == before

    def test_cancelling_nothing_is_a_conflict_not_a_crash(self, client, admin):
        r = client.post(f"{BILLING}/cancel", headers=admin)

        assert r.status_code == 409


class TestWebhookDrivesEverything:
    def test_an_active_subscription_moves_the_plan(self, client, admin, signed):
        r = _send(client, _subscription_event("customer.subscription.created",
                                              status="active"))

        assert r.status_code == 200
        assert r.json()["restaurant_id"] == 1
        body = _state(client, admin)
        assert body["plan_code"] == "premium"
        assert body["billing_status"] == "active"
        assert body["renews_at"]
        assert body["has_subscription"] is True

    def test_a_forged_event_changes_nothing(self, client, admin, signed):
        payload, _ = _signed(_subscription_event("customer.subscription.created",
                                                 status="active"))
        r = client.post(
            WEBHOOK,
            content=payload,
            headers={"stripe-signature": "t=1,v1=deadbeef",
                     "Content-Type": "application/json"},
        )

        assert r.status_code == 400
        assert _state(client, admin)["plan_code"] == "pro"

    def test_a_failed_renewal_does_not_shut_the_kitchen_down(
        self, client, admin, auth, signed
    ):
        """A card hiccup costs a day of trade if it suspends a venue. Stripe
        retries; the restaurant keeps working."""
        _send(client, _subscription_event("customer.subscription.updated",
                                          status="past_due"))

        assert _state(client, admin)["billing_status"] == "past_due"
        menu = client.get("/api/v1/restaurants/1/menu").json()
        placed = client.post(
            "/api/v1/orders",
            json={"restaurant_id": 1, "address": "Abay 10",
                  "items": [{"menu_item_id": menu[0]["id"], "quantity": 1}],
                  "pay_method": "cash"},
            headers=auth,
        )
        assert placed.status_code == 201, placed.text

    def test_an_unpaid_subscription_does_close_the_door(self, client, admin, auth, signed):
        _send(client, _subscription_event("customer.subscription.updated", status="unpaid"))

        assert _state(client, admin)["billing_status"] == "suspended"
        menu = client.get("/api/v1/restaurants/1/menu").json()
        placed = client.post(
            "/api/v1/orders",
            json={"restaurant_id": 1, "address": "Abay 10",
                  "items": [{"menu_item_id": menu[0]["id"], "quantity": 1}],
                  "pay_method": "cash"},
            headers=auth,
        )
        assert placed.status_code == 403

    def test_cancelling_drops_to_the_free_plan_rather_than_suspending(
        self, client, admin, signed
    ):
        """Stopping payment is not the same as defaulting on it. The venue lands
        on the free tier, keeps its account and its menu, and is not locked out
        the way an unpaid subscription locks it out."""
        _send(client, _subscription_event("customer.subscription.created", status="active"))

        _send(client, _subscription_event("customer.subscription.deleted", status="canceled"))

        body = _state(client, admin)
        assert body["plan_code"] == "basic"
        assert body["billing_status"] == "active"
        assert body["has_subscription"] is False
        assert body["renews_at"] is None

    def test_after_cancelling_delivery_stops_and_says_which_plan(
        self, client, auth, signed
    ):
        """Delivery is a paid feature, so it does go away — but the refusal has
        to name the plan, not leave a customer staring at a bare 403."""
        _send(client, _subscription_event("customer.subscription.deleted", status="canceled"))

        menu = client.get("/api/v1/restaurants/1/menu").json()
        placed = client.post(
            "/api/v1/orders",
            json={"restaurant_id": 1, "address": "Abay 10",
                  "items": [{"menu_item_id": menu[0]["id"], "quantity": 1}],
                  "pay_method": "cash"},
            headers=auth,
        )

        assert placed.status_code == 403
        # Not "subscription is inactive": they are paid up, just on a smaller plan.
        assert "plan" in placed.json()["detail"].lower()
        assert "inactive" not in placed.json()["detail"].lower()

    def test_an_event_for_an_unknown_venue_is_ignored(self, client, signed):
        r = _send(client, _subscription_event("customer.subscription.updated",
                                              status="active", restaurant_id=99999))

        assert r.status_code == 200
        assert r.json().get("restaurant_id") is None

    def test_an_order_event_still_reaches_the_order_handler(self, client, signed):
        """Both kinds of money arrive on one endpoint; neither may swallow the
        other."""
        r = _send(client, {
            "id": "evt_order_1",
            "type": "checkout.session.completed",
            "data": {"object": {"id": "cs_x", "payment_status": "paid",
                                "metadata": {"order_id": "999999"}}},
        })

        assert r.status_code == 200
        assert "restaurant_id" not in r.json()


def test_status_mapping_keeps_past_due_working():
    """Encoded once, so nobody quietly turns a retry window into a shutdown."""
    from app.core.features import INACTIVE_BILLING

    assert subscriptions._STATUS_MAP["past_due"] == "past_due"
    assert "past_due" not in INACTIVE_BILLING
    assert subscriptions._STATUS_MAP["unpaid"] in INACTIVE_BILLING
