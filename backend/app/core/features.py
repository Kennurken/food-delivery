"""Plan entitlements live here — not `if plan == "premium"` in endpoints.

Limits are data. `None` means unlimited. Overrides (per restaurant) can add or
remove a feature without changing the restaurant's plan row.
"""

from __future__ import annotations

from dataclasses import dataclass

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.restaurant import Restaurant

# Keys the rest of the app checks. Keep names stable; add, don't rename.
FEATURE_KEYS = (
    "qr.menu",
    "catalog",
    "table.ordering",
    "orders.basic",
    "analytics.basic",
    "branding.basic",
    "staff.basic",
    "floor_plan",
    "delivery.enabled",
    "pickup.enabled",
    "kds",
    "reservations",
    "promotions",
    "payments.online",
    "notifications",
    "analytics.pro",
    "staff.advanced",
    "multi_branch",
    "analytics.advanced",
    "inventory",
    "loyalty",
    "api.public",
    "webhooks",
    "integrations",
    "custom_domain",
    "ai",
)

_BASIC = (
    "qr.menu",
    "catalog",
    "table.ordering",
    "orders.basic",
    "analytics.basic",
    "branding.basic",
    "staff.basic",
    "floor_plan",
)
_PRO = _BASIC + (
    "delivery.enabled",
    "pickup.enabled",
    "kds",
    "reservations",
    "promotions",
    "payments.online",
    "notifications",
    "analytics.pro",
    "staff.advanced",
)
_PREMIUM = _PRO + (
    "multi_branch",
    "analytics.advanced",
    "inventory",
    "loyalty",
    "api.public",
    "webhooks",
    "integrations",
    "custom_domain",
    "ai",
)

# monthly_price is documentation until a PaymentProvider is wired.
PLANS: dict[str, dict] = {
    "basic": {
        "name": "Basic",
        "features": _BASIC,
        "limits": {"branches.max": 1, "tables.max": 20, "staff.max": 5},
        "billed": False,
    },
    "pro": {
        "name": "Pro",
        "features": _PRO,
        "limits": {"branches.max": 3, "tables.max": 100, "staff.max": 30},
        "billed": False,
    },
    "premium": {
        "name": "Premium",
        "features": _PREMIUM,
        "limits": {"branches.max": None, "tables.max": None, "staff.max": None},
        "billed": False,
    },
}

DEFAULT_PLAN = "pro"  # existing marketplace venues keep delivery
INACTIVE_BILLING = frozenset({"suspended", "cancelled", "expired"})


@dataclass(frozen=True)
class Entitlements:
    plan_code: str
    features: frozenset[str]
    limits: dict[str, int | None]

    def enabled(self, key: str) -> bool:
        return key in self.features

    def limit(self, key: str) -> int | None:
        return self.limits.get(key)


def plan_of(code: str | None) -> dict:
    return PLANS.get(code or DEFAULT_PLAN, PLANS["basic"])


def public_plans() -> list[dict]:
    return [
        {
            "code": code,
            "name": spec["name"],
            "features": list(spec["features"]),
            "limits": spec["limits"],
            "billed": spec["billed"],
        }
        for code, spec in PLANS.items()
    ]


def entitlements(db: Session, restaurant: Restaurant) -> Entitlements:
    spec = plan_of(restaurant.plan_code)
    flags = set(spec["features"])
    from app.models.feature_flag import FeatureOverride

    rows = db.scalars(
        select(FeatureOverride).where(FeatureOverride.restaurant_id == restaurant.id)
    )
    for row in rows:
        if row.enabled:
            flags.add(row.key)
        else:
            flags.discard(row.key)
    return Entitlements(
        plan_code=restaurant.plan_code or DEFAULT_PLAN,
        features=frozenset(flags),
        limits=dict(spec["limits"]),
    )


def cache_key(restaurant_id: int, *parts: object) -> str:
    """Tenant-aware cache key. Use this even before Redis exists."""
    return "tenant:" + ":".join(str(p) for p in (restaurant_id, *parts))


def channels_of(ent: Entitlements) -> list[str]:
    """How customers may place an order here. Empty means catalog-only."""
    out: list[str] = []
    if ent.enabled("delivery.enabled"):
        out.append("delivery")
    if ent.enabled("pickup.enabled"):
        out.append("pickup")
    if ent.enabled("table.ordering"):
        out.append("qr_table")
    return out
