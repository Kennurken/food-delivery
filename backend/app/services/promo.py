"""Promo codes. One per order. Entitlement is `promotions`, not `if plan == pro`."""

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.features import entitlements
from app.models.promo import Promo
from app.models.restaurant import Restaurant

_CODE_CHARS = set("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")


def normalize_code(raw: str) -> str:
    return "".join(ch for ch in raw.strip().upper() if ch in _CODE_CHARS)


def find_promo(db: Session, restaurant_id: int, code: str) -> Promo | None:
    key = normalize_code(code)
    if len(key) < 3:
        return None
    return db.scalar(select(Promo).where(Promo.restaurant_id == restaurant_id, Promo.code == key))


def quote(db: Session, restaurant: Restaurant, code: str, subtotal: float) -> tuple[Promo, float]:
    flags = entitlements(db, restaurant)
    if not flags.enabled("promotions"):
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Promotions are not on this plan")
    promo = find_promo(db, restaurant.id, code)
    if promo is None or not promo.is_active:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Unknown promo")
    if promo.max_uses is not None and promo.used_count >= promo.max_uses:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Promo is used up")
    if subtotal + 1e-9 < promo.min_subtotal:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            f"Min order {promo.min_subtotal:.0f} ₸",
        )
    if promo.kind == "percent":
        discount = round(subtotal * (promo.value / 100.0), 2)
    else:
        discount = min(float(promo.value), subtotal)
    discount = round(max(discount, 0), 2)
    if discount <= 0:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Promo does not apply")
    return promo, discount
