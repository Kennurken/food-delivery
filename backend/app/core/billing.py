"""Payment provider adapter. Business code talks to this, not to Stripe/Kaspi."""

from typing import Protocol

from fastapi import HTTPException, status
from pydantic import BaseModel


class PaymentResult(BaseModel):
    provider: str
    reference: str
    status: str  # succeeded | pending | failed


class PaymentProvider(Protocol):
    name: str

    def charge(
        self,
        *,
        amount: float,
        currency: str,
        idempotency_key: str,
        description: str,
    ) -> PaymentResult: ...


class UnconfiguredProvider:
    """Honest no-op. Do not pretend a payment succeeded."""

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
            status.HTTP_501_NOT_IMPLEMENTED,
            "No payment provider configured",
        )


def get_payment_provider() -> PaymentProvider:
    return UnconfiguredProvider()
