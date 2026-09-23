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
from datetime import UTC, datetime

import stripe
from fastapi import HTTPException, status

from app.core.billing import _app_base, _stripe_amount
from app.core.config import settings
from app.core.features import PLANS, plan_of
from app.models.restaurant import Restaurant

log = logging.getLogger(__name__)

CURRENCY = "KZT"

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
        # Falling back to the free tier rather than locking the venue out: they
        # stop paying, they stop getting the paid features, they keep trading.
        restaurant.plan_code = "basic"
        restaurant.billing_status = "active"
        restaurant.stripe_subscription_id = None
        restaurant.plan_renews_at = None

    db.commit()
    db.refresh(restaurant)
    return restaurant


def describe(restaurant: Restaurant) -> dict:
    spec = plan_of(restaurant.plan_code)
    return {
        "plan_code": restaurant.plan_code,
        "plan_name": spec["name"],
        "monthly_price": spec["monthly_price"],
        "billed": spec["billed"],
        "billing_status": restaurant.billing_status,
        "renews_at": restaurant.plan_renews_at.isoformat()
        if restaurant.plan_renews_at
        else None,
        "has_subscription": bool(restaurant.stripe_subscription_id),
        "billing_enabled": billing_enabled(),
    }
