"""Customer checkout money. Restaurant SaaS billing is still UnconfiguredProvider."""

from typing import Protocol

from fastapi import HTTPException, status
from pydantic import BaseModel


class PaymentResult(BaseModel):
    provider: str
    reference: str
    status: str  # unpaid | pending | paid | failed


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


def get_payment_provider(*, method: str = "online") -> PaymentProvider:
    if method == "cash":
        return CashProvider()
    return UnconfiguredProvider()
