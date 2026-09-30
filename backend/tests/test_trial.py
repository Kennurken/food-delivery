"""The free month, the week of grace, and paying by hand.

Vercel has no scheduler, so nothing flips a venue when its time runs out: the
state is computed from the end date on every read. What must hold is that a
venue trades through its trial and a week past it, stops taking orders after
that, keeps its data, and comes back the moment the platform records a payment.
"""

import itertools
import secrets
from datetime import UTC, datetime, timedelta

import pytest

from app.core import subscriptions
from app.core.subscriptions import GRACE_DAYS, TRIAL_DAYS
from app.db.session import SessionLocal
from app.models import Restaurant

_n = itertools.count(1)
NOW = datetime(2026, 10, 1, 12, 0, tzinfo=UTC).replace(tzinfo=None)


def _venue(status: str, ends: datetime | None, **extra) -> Restaurant:
    return Restaurant(name="V", cuisine="x", billing_status=status, plan_renews_at=ends, **extra)


class TestEffectiveStatus:
    def test_a_venue_without_an_end_date_never_times_out(self):
        assert subscriptions.effective_status(_venue("active", None), NOW) == "active"

    def test_inside_the_trial_it_is_a_trial(self):
        v = _venue("trial", NOW + timedelta(days=3))
        assert subscriptions.effective_status(v, NOW) == "trial"

    def test_past_the_end_it_is_in_grace_and_still_trading(self):
        v = _venue("trial", NOW - timedelta(days=1))
        assert subscriptions.effective_status(v, NOW) == "grace_period"

    def test_grace_lasts_exactly_a_week(self):
        ends = NOW - timedelta(days=GRACE_DAYS)
        assert subscriptions.effective_status(_venue("trial", ends), NOW) == "grace_period"
        v = _venue("trial", ends - timedelta(minutes=1))
        assert subscriptions.effective_status(v, NOW) == "expired"

    def test_a_paid_period_runs_out_the_same_way(self):
        v = _venue("active", NOW - timedelta(days=GRACE_DAYS + 1))
        assert subscriptions.effective_status(v, NOW) == "expired"

    def test_stripe_is_left_to_stripe(self):
        v = _venue("active", NOW - timedelta(days=90), stripe_subscription_id="sub_1")
        assert subscriptions.effective_status(v, NOW) == "active"

    @pytest.mark.parametrize("stored", ["suspended", "cancelled", "past_due"])
    def test_other_states_are_taken_as_written(self, stored):
        v = _venue(stored, NOW - timedelta(days=90))
        assert subscriptions.effective_status(v, NOW) == stored

    def test_days_left_counts_to_the_next_event(self):
        assert subscriptions.days_left(_venue("trial", NOW + timedelta(days=3, hours=2)), NOW) == 4
        assert subscriptions.days_left(_venue("trial", NOW - timedelta(days=2)), NOW) == GRACE_DAYS - 2
        assert subscriptions.days_left(_venue("trial", NOW - timedelta(days=30)), NOW) == 0
        assert subscriptions.days_left(_venue("active", None), NOW) is None


class TestRecordPayment:
    def test_it_starts_from_today_when_lapsed(self):
        v = _venue("trial", NOW - timedelta(days=20))
        subscriptions.record_payment(v, "pro", 1, NOW)
        assert v.billing_status == "active" and v.plan_code == "pro"
        assert v.plan_renews_at == NOW + timedelta(days=30)

    def test_paying_early_extends_instead_of_restarting(self):
        v = _venue("trial", NOW + timedelta(days=10))
        subscriptions.record_payment(v, "basic", 2, NOW)
        assert v.plan_renews_at == NOW + timedelta(days=70)

    def test_a_bad_plan_or_month_count_is_refused(self):
        from fastapi import HTTPException

        v = _venue("trial", NOW)
        for plan, months in (("gold", 1), ("pro", 0), ("pro", 13)):
            with pytest.raises(HTTPException):
                subscriptions.record_payment(v, plan, months, NOW)


@pytest.fixture
def venue(client, admin) -> dict:
    r = client.post(
        "/api/v1/admin/restaurants",
        json={"name": f"Trial Cafe {next(_n)}", "cuisine": "Test"},
        headers=admin,
    )
    assert r.status_code == 201, r.text
    rid = r.json()["id"]
    dish = client.post(
        f"/api/v1/admin/restaurants/{rid}/menu",
        json={"name": "Plov", "price": 1500, "category": "Main"},
        headers=admin,
    ).json()["id"]
    return {"id": rid, "dish": dish}


def _set_end(rid: int, status: str, ends: datetime | None) -> None:
    with SessionLocal() as db:
        v = db.get(Restaurant, rid)
        v.billing_status, v.plan_renews_at = status, ends
        db.commit()


def _now() -> datetime:
    return datetime.now(UTC).replace(tzinfo=None)


def _order(client, auth, venue):
    return client.post(
        "/api/v1/orders",
        json={
            "restaurant_id": venue["id"],
            "channel": "pickup",
            "items": [{"menu_item_id": venue["dish"], "quantity": 1}],
        },
        headers=auth,
    )


class TestOrdersFollowTheClock:
    def test_a_trial_venue_takes_orders(self, client, auth, venue):
        _set_end(venue["id"], "trial", _now() + timedelta(days=5))
        assert _order(client, auth, venue).status_code == 201

    def test_grace_still_takes_orders(self, client, auth, venue):
        _set_end(venue["id"], "trial", _now() - timedelta(days=3))
        assert _order(client, auth, venue).status_code == 201

    def test_after_grace_orders_close(self, client, auth, venue):
        _set_end(venue["id"], "trial", _now() - timedelta(days=GRACE_DAYS + 1))
        r = _order(client, auth, venue)
        assert r.status_code == 403
        assert "subscription" in r.json()["detail"].lower()

    def test_the_menu_stays_visible_when_orders_are_closed(self, client, venue):
        _set_end(venue["id"], "trial", _now() - timedelta(days=GRACE_DAYS + 1))
        assert client.get(f"/api/v1/restaurants/{venue['id']}").status_code == 200

    def test_a_recorded_payment_reopens_orders(self, client, auth, admin, venue):
        _set_end(venue["id"], "trial", _now() - timedelta(days=GRACE_DAYS + 1))
        r = client.post(
            f"/api/v1/admin/restaurants/{venue['id']}/subscription/manual",
            json={"plan_code": "pro", "months": 1},
            headers=admin,
        )
        assert r.status_code == 200, r.text
        assert r.json()["billing_status"] == "active" and r.json()["orders_open"] is True
        assert _order(client, auth, venue).status_code == 201


class TestManualPaymentEndpoint:
    def test_only_the_platform_may_record_one(self, client, auth, venue):
        r = client.post(
            f"/api/v1/admin/restaurants/{venue['id']}/subscription/manual",
            json={"plan_code": "pro"},
            headers=auth,
        )
        assert r.status_code == 403

    def test_an_unknown_venue_is_404(self, client, admin):
        r = client.post(
            "/api/v1/admin/restaurants/999999/subscription/manual",
            json={"plan_code": "pro"},
            headers=admin,
        )
        assert r.status_code == 404

    def test_it_is_audited(self, client, admin, venue):
        client.post(
            f"/api/v1/admin/restaurants/{venue['id']}/subscription/manual",
            json={"plan_code": "premium", "months": 3},
            headers=admin,
        )
        from sqlalchemy import select

        from app.models.audit import AuditLog

        with SessionLocal() as db:
            rows = db.scalars(
                select(AuditLog).where(
                    AuditLog.restaurant_id == venue["id"], AuditLog.action == "subscription.manual"
                )
            ).all()
        assert len(rows) == 1 and rows[0].payload["months"] == 3


class TestApprovalStartsTheTrial:
    def test_approving_gives_a_thirty_day_pro_trial(self, client, admin):
        body = {
            "venue_name": f"Fresh Cafe {next(_n)}",
            "cuisine": "Kazakh",
            "contact_name": "Aigerim S.",
            "email": f"owner.{secrets.token_hex(3)}@cafe.kz",
            "phone": "+77011234567",
            "password": "ownerpass123",
            "has_couriers": True,
        }
        applied = client.post("/api/v1/partners/apply", json=body).json()
        rid = applied["restaurant_id"]
        client.post(f"/api/v1/admin/restaurants/{rid}/approval", json={"approve": True}, headers=admin)

        auth = {"Authorization": f"Bearer {applied['access_token']}"}
        state = client.get(f"/api/v1/admin/restaurants/{rid}/billing", headers=auth).json()

        assert state["billing_status"] == "trial"
        assert state["plan_code"] == "pro"
        assert state["days_left"] in (TRIAL_DAYS, TRIAL_DAYS - 1)
        assert state["orders_open"] is True

    def test_rejecting_starts_nothing(self, client, admin):
        body = {
            "venue_name": f"No Cafe {next(_n)}",
            "cuisine": "Kazakh",
            "contact_name": "X Y",
            "email": f"owner.{secrets.token_hex(3)}@cafe.kz",
            "phone": "+77011234567",
            "password": "ownerpass123",
            "has_couriers": False,
        }
        applied = client.post("/api/v1/partners/apply", json=body).json()
        rid = applied["restaurant_id"]
        client.post(
            f"/api/v1/admin/restaurants/{rid}/approval",
            json={"approve": False, "reason": "no"},
            headers=admin,
        )
        with SessionLocal() as db:
            assert db.get(Restaurant, rid).plan_renews_at is None
