"""Stripe Billing for the venues themselves.

A fixed monthly price per venue, on the platform's own Stripe account. The
alternative — a commission on each order — needs Stripe Connect and a KYC
onboarding per restaurant, which is a wall this product cannot walk through
until it has real tenants. Nothing here forecloses adding commission later.

Two rules, the same ones the customer-facing payments follow.

Nothing marks a subscription paid except Stripe. `subscribe()` opens a Checkout
session and stops; every status in the database is written by a webhook. If the
processor never confirms, the venue simply stays on what it had.

A failed renewal is not a suspension. The card is retried, the venue keeps
working, and only Stripe ending the subscription closes the door — cutting a
restaurant off mid-service over a card hiccup costs them a day of trade and us
the customer.
"""

from __future__ import annotations

import logging
from datetime import UTC, datetime, timedelta

import stripe
from fastapi import HTTPException, status

from app.core.billing import _app_base, _stripe_amount
from app.core.config import settings
from app.core.features import INACTIVE_BILLING, PLANS, plan_of
from app.models.restaurant import Restaurant

log = logging.getLogger(__name__)

CURRENCY = "KZT"

TRIAL_DAYS = 30
GRACE_DAYS = 7
PERIOD_DAYS = 30
TRIAL_PLAN = "pro"

# Vercel runs no scheduler, so nothing flips a venue to "grace" or "expired"
# when its time runs out. The stored status is what was last *written*; the
# effective one below is what is true right now, computed on every read.
_TIMED = frozenset({"trial", "active", "grace_period"})

# What Stripe calls a subscription, and what that means for us. `past_due` is
# deliberately a working state: the retry window is Stripe's job, not a reason
# to shut a kitchen down.
_STATUS_MAP = {
    "trialing": "trial",
    "active": "active",
    "past_due": "past_due",
    "incomplete": "past_due",
    "incomplete_expired": "expired",
    "unpaid": "suspended",
    "canceled": "cancelled",
    "paused": "suspended",
}


def billing_enabled() -> bool:
    return bool((settings.stripe_secret_key or "").strip())


def _require_stripe() -> str:
    secret = (settings.stripe_secret_key or "").strip()
    if not secret:
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            "Subscriptions are not connected. Contact the platform.",
        )
    stripe.api_key = secret
    return secret


def _customer_id(restaurant: Restaurant, email: str | None) -> str:
    if restaurant.stripe_customer_id:
        return restaurant.stripe_customer_id
    customer = stripe.Customer.create(
        name=restaurant.name,
        email=email,
        metadata={"restaurant_id": str(restaurant.id)},
    )
    return customer["id"] if isinstance(customer, dict) else customer.id


def subscribe(
    restaurant: Restaurant, plan_code: str, *, email: str | None = None
) -> tuple[str, str]:
    """Open Stripe Checkout for a monthly plan. Returns (customer_id, url).

    The plan is not written here. It moves when Stripe says the subscription
    exists, which is the only moment anyone has actually paid.
    """
    spec = PLANS.get(plan_code)
    if spec is None:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "No such plan")
    if not spec["billed"]:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, f"{spec['name']} is free")
    _require_stripe()
    base = _app_base(None)
    customer = _customer_id(restaurant, email)
    try:
        session = stripe.checkout.Session.create(
            mode="subscription",
            customer=customer,
            # An inline price keeps the plan catalogue in this repo instead of
            # split between here and a dashboard nobody reviews.
            line_items=[
                {
                    "quantity": 1,
                    "price_data": {
                        "currency": CURRENCY.lower(),
                        "unit_amount": _stripe_amount(spec["monthly_price"], CURRENCY),
                        "recurring": {"interval": "month"},
                        "product_data": {"name": f"{spec['name']} — {restaurant.name}"},
                    },
                }
            ],
            payment_method_types=["card"],
            success_url=f"{base}/#/admin?billing=1",
            cancel_url=f"{base}/#/admin?billing=0",
            client_reference_id=str(restaurant.id),
            metadata={"restaurant_id": str(restaurant.id), "plan_code": plan_code},
            subscription_data={
                "metadata": {"restaurant_id": str(restaurant.id), "plan_code": plan_code}
            },
        )
    except stripe.StripeError as exc:
        log.warning("subscription checkout %s", exc)
        raise HTTPException(
            status.HTTP_502_BAD_GATEWAY, "Could not open checkout. Try again."
        ) from exc
    url = session.get("url") if isinstance(session, dict) else session.url
    if not url:
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, "Could not open checkout. Try again.")
    return customer, url


def cancel(restaurant: Restaurant) -> bool:
    """Stop renewing at the end of the paid period.

    Not immediately: the month is already paid for, and taking it away early
    would be charging for something and then withdrawing it.
    """
    if not restaurant.stripe_subscription_id:
        return False
    _require_stripe()
    try:
        stripe.Subscription.modify(
            restaurant.stripe_subscription_id, cancel_at_period_end=True
        )
    except stripe.StripeError:
        log.exception("subscription cancel failed for %s", restaurant.stripe_subscription_id)
        return False
    return True


def _period_end(subscription: dict) -> datetime | None:
    raw = subscription.get("current_period_end")
    if not isinstance(raw, int):
        items = (subscription.get("items") or {}).get("data") or []
        raw = items[0].get("current_period_end") if items else None
    if not isinstance(raw, int):
        return None
    return datetime.fromtimestamp(raw, tz=UTC).replace(tzinfo=None)


def apply_event(db, event: dict) -> Restaurant | None:
    """Move a venue's billing state because Stripe said so.

    Returns the restaurant it touched, or None when the event is not ours.
    """
    etype = event.get("type") or ""
    if not etype.startswith("customer.subscription."):
        return None
    subscription = (event.get("data") or {}).get("object") or {}
    meta = subscription.get("metadata") or {}
    raw_id = meta.get("restaurant_id")
    try:
        restaurant_id = int(raw_id)
    except (TypeError, ValueError):
        return None
    restaurant = db.get(Restaurant, restaurant_id)
    if restaurant is None:
        return None

    mapped = _STATUS_MAP.get(subscription.get("status") or "")
    if mapped is None:
        return None

    restaurant.stripe_subscription_id = subscription.get("id")
    restaurant.plan_renews_at = _period_end(subscription)
    restaurant.billing_status = mapped

    plan_code = meta.get("plan_code")
    if mapped in ("active", "trial") and plan_code in PLANS:
        restaurant.plan_code = plan_code
    if mapped in ("cancelled", "expired"):
        # There is no free tier to fall back to: the subscription is over, so
        # orders close. The account, menu and history stay for when they return.
        restaurant.stripe_subscription_id = None

    db.commit()
    db.refresh(restaurant)
    return restaurant


def _now() -> datetime:
    return datetime.now(UTC).replace(tzinfo=None)


def effective_status(restaurant: Restaurant, now: datetime | None = None) -> str:
    """The billing state as of `now`, whatever was last written.

    A venue with no end date (seeded or platform-created) never times out, and
    one that Stripe manages is left to Stripe — its webhooks are the authority.
    Otherwise the end date decides: inside it the stored status stands, within
    GRACE_DAYS after it the venue is in grace and still trading, beyond that it
    is expired and orders close.
    """
    stored = restaurant.billing_status
    ends = restaurant.plan_renews_at
    if stored not in _TIMED or ends is None or restaurant.stripe_subscription_id:
        return stored
    now = now or _now()
    if now <= ends:
        return "active" if stored == "grace_period" else stored
    if now <= ends + timedelta(days=GRACE_DAYS):
        return "grace_period"
    return "expired"


def days_left(restaurant: Restaurant, now: datetime | None = None) -> int | None:
    """Whole days until the next thing happens: the trial or period ends while
    it runs, the orders close while in grace. None when there is no end date."""
    ends = restaurant.plan_renews_at
    if ends is None or restaurant.stripe_subscription_id:
        return None
    now = now or _now()
    if now > ends:
        ends = ends + timedelta(days=GRACE_DAYS)
    return max(0, (ends - now).days + (1 if (ends - now).seconds else 0))


def start_trial(restaurant: Restaurant, now: datetime | None = None) -> None:
    """The free month a venue gets when the platform approves it."""
    restaurant.plan_code = TRIAL_PLAN
    restaurant.billing_status = "trial"
    restaurant.plan_renews_at = (now or _now()) + timedelta(days=TRIAL_DAYS)


def record_payment(
    restaurant: Restaurant, plan_code: str, months: int, now: datetime | None = None
) -> None:
    """Pay in advance for `months` months, taken outside Stripe (bank transfer,
    a Kazakh processor). Paying early extends the current period instead of
    starting a new one, so nobody loses days by not waiting for the last one."""
    if plan_code not in PLANS:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "No such plan")
    if not 1 <= months <= 12:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Months must be 1 to 12")
    now = now or _now()
    ends = restaurant.plan_renews_at
    live = effective_status(restaurant, now) in ("trial", "active") and ends is not None
    base = ends if live and ends > now else now
    restaurant.plan_code = plan_code
    restaurant.billing_status = "active"
    restaurant.plan_renews_at = base + timedelta(days=PERIOD_DAYS * months)


def describe(restaurant: Restaurant) -> dict:
    spec = plan_of(restaurant.plan_code)
    status_now = effective_status(restaurant)
    return {
        "plan_code": restaurant.plan_code,
        "plan_name": spec["name"],
        "monthly_price": spec["monthly_price"],
        "billed": spec["billed"],
        "billing_status": status_now,
        "days_left": days_left(restaurant),
        "orders_open": status_now not in INACTIVE_BILLING,
        "renews_at": restaurant.plan_renews_at.isoformat() if restaurant.plan_renews_at else None,
        "has_subscription": bool(restaurant.stripe_subscription_id),
        "billing_enabled": billing_enabled(),
    }
