"""Cities: which ones exist, and which one a request is about.

A city's slug becomes a top-level URL on the site (/almaty/), so it shares a
namespace with every other top-level path. A city called "cart" or "actions"
would either shadow a real page or be shadowed by it, depending on route order
— and route order is not something anyone should have to remember. So the
reserved names are listed here and checked here, once.
"""

from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.city import City

# Every first path segment the site or the API already answers. Adding a new
# top-level page means adding its name here in the same change.
RESERVED_SLUGS = frozenset(
    {
        "about",
        "actions",
        "api",
        "cart",
        "checkout",
        "delivery",
        "docs",
        "health",
        "kk",
        "lang",
        "login",
        "logout",
        "openapi.json",
        "orders",
        "partners",
        "r",
        "redoc",
        "register",
        "robots.txt",
        "site",
        "sitemap.xml",
        "t",
    }
)

# The city every restaurant predates. Existing venues are backfilled into it,
# and it is what a request without a city means.
DEFAULT_SLUG = "almaty"


class ReservedSlugError(ValueError):
    pass


def check_slug(slug: str) -> str:
    if slug in RESERVED_SLUGS:
        raise ReservedSlugError(f"'{slug}' is already a path on the site")
    return slug


def active(db: Session) -> list[City]:
    return list(
        db.scalars(
            select(City)
            .where(City.is_active.is_(True))
            .order_by(City.sort_order, City.name)
        )
    )


def by_slug(db: Session, slug: str) -> City | None:
    """Only a live city: a switched-off one is gone, like a finished campaign."""
    return db.scalar(select(City).where(City.slug == slug, City.is_active.is_(True)))


def default(db: Session) -> City | None:
    return by_slug(db, DEFAULT_SLUG) or next(iter(active(db)), None)
