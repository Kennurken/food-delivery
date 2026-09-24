"""Campaigns and whether they are actually running.

The rule this module exists to enforce: a campaign is public only while it is
live. Showing a finished offer on the landing page, or leaving its URL
answering 200 after it ends, promises a customer something the checkout will
refuse — which is worse than never having advertised it.
"""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import Select, or_, select
from sqlalchemy.orm import Session

from app.models.offer import Offer
from app.models.promo import Promo


def _now() -> datetime:
    return datetime.now()  # noqa: DTZ005 — stored datetimes are naive


def live_filter(moment: datetime | None = None):
    """Active, started, and not finished. Null dates mean "no bound"."""
    at = moment or _now()
    return (
        Offer.is_active.is_(True)
        & or_(Offer.starts_at.is_(None), Offer.starts_at <= at)
        & or_(Offer.ends_at.is_(None), Offer.ends_at >= at)
    )


def _ordered(stmt: Select) -> Select:
    return stmt.order_by(Offer.sort_order.desc(), Offer.id.desc())


def live(db: Session, *, limit: int | None = None) -> list[Offer]:
    stmt = _ordered(select(Offer).where(live_filter()))
    if limit is not None:
        stmt = stmt.limit(limit)
    return list(db.scalars(stmt))


def by_slug(db: Session, slug: str) -> Offer | None:
    """Only a running campaign. A finished one is gone, not merely stale."""
    return db.scalar(select(Offer).where(Offer.slug == slug, live_filter()))


def usable_code(db: Session, offer: Offer) -> str | None:
    """The code, but only if the checkout would still take it.

    A campaign can outlive the code it advertises: the code gets switched off,
    or its uses run out. Printing it anyway sends someone to a till that will
    refuse them.
    """
    code = (offer.promo_code or "").strip()
    if not code:
        return None
    stmt = select(Promo).where(Promo.code == code, Promo.is_active.is_(True))
    if offer.restaurant_id is not None:
        stmt = stmt.where(Promo.restaurant_id == offer.restaurant_id)
    promo = db.scalar(stmt)
    if promo is None:
        return None
    if promo.max_uses is not None and promo.used_count >= promo.max_uses:
        return None
    return code
