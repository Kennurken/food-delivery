"""Customer checkout money. Restaurant SaaS billing is still UnconfiguredProvider."""

from __future__ import annotations

import logging
import re

import stripe
from fastapi import HTTPException, status
from pydantic import BaseModel

from app.core.config import settings

log = logging.getLogger(__name__)

# Stripe's zero-decimal currencies: the amount is whole units, not cents.
# KZT is NOT one of them — Stripe bills tenge with two decimals, so 2900 ₸ is 290000.
_ZERO_DECIMAL = frozenset(
    {
        "bif", "clp", "djf", "gnf", "jpy", "kmf", "krw", "mga",
        "pyg", "rwf", "ugx", "vnd", "vuv", "xaf", "xof", "xpf",
    }
)


class PaymentResult(BaseModel):
    provider: str
    reference: str
    status: str  # unpaid | pending | paid | failed
    url: str | None = None


class UnconfiguredProvider:
    """Honest no-op. Do not pretend a card payment succeeded."""

    name = "none"

    def charge(
        self,
        *,
        amount: float,
        currency: str,
        idempotency_key: str,
        description: str,
    ) -> PaymentResult:
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            "Card payments are not connected. Pay with cash.",
        )


class CashProvider:
    """Pay the courier, the counter, or the table. No money moves here."""

    name = "cash"

    def charge(
        self,
        *,
        amount: float,
        currency: str,
        idempotency_key: str,
        description: str,
    ) -> PaymentResult:
        return PaymentResult(provider="cash", reference=idempotency_key, status="unpaid")


def card_connected() -> bool:
    return bool((settings.stripe_secret_key or "").strip())


def public_config() -> dict:
    if not card_connected():
        return {"card": False, "provider": None, "publishable_key": None}
    return {
        "card": True,
        "provider": "stripe",
        "publishable_key": (settings.stripe_publishable_key or "").strip() or None,
    }


def get_payment_provider(*, method: str = "online"):
    if method == "cash":
        return CashProvider()
    return UnconfiguredProvider()


def _stripe_amount(amount: float, currency: str) -> int:
    if currency.lower() in _ZERO_DECIMAL:
        return round(amount)
    return round(amount * 100)


def _app_base(origin: str | None) -> str:
    raw = (origin or "").strip().rstrip("/")
    if raw:
        allowed = settings.cors_origin_list
        if "*" in allowed or raw in allowed:
            return raw
        pattern = (settings.cors_origin_regex or "").strip()
        if pattern and re.fullmatch(pattern, raw):
            return raw
    return (settings.public_app_url or "https://food-delivery-drab-theta.vercel.app").rstrip("/")


def create_checkout_session(
    *,
    amount: float,
    currency: str,
    description: str,
    order_id: int,
    origin: str | None,
    idempotency_key: str,
    customer_email: str | None = None,
) -> PaymentResult:
    """Hosted Stripe Checkout. Order stays pending until Stripe says paid."""
    secret = (settings.stripe_secret_key or "").strip()
    if not secret:
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            "Card payments are not connected. Pay with cash.",
        )
    if amount <= 0:
        return PaymentResult(provider="stripe", reference="free", status="paid")
    units = _stripe_amount(amount, currency)
    if units < 1:
        return PaymentResult(provider="stripe", reference="free", status="paid")
    base = _app_base(origin)
    stripe.api_key = secret
    payload: dict = {
        "mode": "payment",
        # Ask for cards by name instead of letting Stripe pick from the dashboard.
        # Dynamic payment methods resolve against the account's enabled set, and in
        # tenge that set can come back empty — "No valid payment method types for
        # this Checkout Session". A card is the only thing this app can take anyway.
        "payment_method_types": ["card"],
        "success_url": f"{base}/orders/{order_id}?paid=1",
        "cancel_url": f"{base}/orders/{order_id}?paid=0",
        "client_reference_id": str(order_id),
        "line_items": [
            {
                "quantity": 1,
                "price_data": {
                    "currency": currency.lower(),
                    "unit_amount": units,
                    "product_data": {"name": description[:120] or f"Order #{order_id}"},
                },
            }
        ],
        "metadata": {"order_id": str(order_id)},
    }
    if customer_email:
        payload["customer_email"] = customer_email
    _ = idempotency_key
    try:
        session = stripe.checkout.Session.create(**payload)
    except stripe.StripeError as exc:
        log.warning("stripe checkout %s", exc)
        raise HTTPException(
            status.HTTP_502_BAD_GATEWAY,
            "Card checkout failed. Try cash, or try again.",
        ) from exc
    url = session.get("url") if isinstance(session, dict) else session.url
    sid = session.get("id") if isinstance(session, dict) else session.id
    if not url or not sid:
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, "Card checkout failed. Try cash, or try again.")
    return PaymentResult(provider="stripe", reference=sid, status="pending", url=url)


def session_is_paid(session_id: str) -> bool:
    secret = (settings.stripe_secret_key or "").strip()
    if not secret or not session_id or session_id == "free":
        return False
    stripe.api_key = secret
    try:
        session = stripe.checkout.Session.retrieve(session_id)
    except stripe.StripeError:
        log.exception("stripe retrieve failed")
        return False
    status_value = session.get("payment_status") if isinstance(session, dict) else session.payment_status
    return status_value == "paid"


def refund_session(session_id: str) -> str | None:
    """Refund a paid Checkout Session in full. Returns the refund id, or None.

    Cancelling a ticket the customer already paid for must move the money back.
    The mirror of "never fake paid": never keep money for food nobody cooks.
    """
    secret = (settings.stripe_secret_key or "").strip()
    if not secret or not session_id or session_id == "free":
        return None
    stripe.api_key = secret
    try:
        session = stripe.checkout.Session.retrieve(session_id)
        intent = session.get("payment_intent") if isinstance(session, dict) else session.payment_intent
        if not intent:
            return None
        refund = stripe.Refund.create(payment_intent=intent)
    except stripe.StripeError:
        # Surfacing this as a 5xx would block the cancel; the ticket still has to
        # close. Log loudly so a human settles the money.
        log.exception("stripe refund failed for session %s", session_id)
        return None
    return refund.get("id") if isinstance(refund, dict) else refund.id


def parse_webhook(payload: bytes, signature: str) -> dict:
    secret = (settings.stripe_webhook_secret or "").strip()
    if not secret:
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, "Stripe webhook is not configured")
    try:
        event = stripe.Webhook.construct_event(payload, signature, secret)
    except (ValueError, stripe.SignatureVerificationError) as exc:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Invalid Stripe signature") from exc
    return event if isinstance(event, dict) else event.to_dict()


def order_id_from_event(event: dict) -> int | None:
    etype = event.get("type") or ""
    if etype not in {
        "checkout.session.completed",
        "checkout.session.async_payment_succeeded",
    }:
        return None
    obj = (event.get("data") or {}).get("object") or {}
    if obj.get("payment_status") not in {None, "paid"}:
        return None
    meta = obj.get("metadata") or {}
    raw = meta.get("order_id") or obj.get("client_reference_id")
    try:
        return int(raw)
    except (TypeError, ValueError):
        return None
