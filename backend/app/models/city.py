from sqlalchemy import Boolean, Float, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base


class City(Base):
    """A city the service delivers in.

    Restaurants belong to one. The site gives each its own landing at
    /<slug>/, so the slug is a public URL and is stored rather than derived —
    and it must never collide with a path the site already serves (see
    `app.services.cities.RESERVED_SLUGS`).
    """

    __tablename__ = "cities"

    id: Mapped[int] = mapped_column(primary_key=True)
    slug: Mapped[str] = mapped_column(String(40), unique=True, index=True)
    # Shown to people. Russian is the site's language; the app localises
    # through its own ARB files and falls back to this.
    name: Mapped[str] = mapped_column(String(80))
    # Where the map opens and what "nearby" means before an address is known.
    lat: Mapped[float | None] = mapped_column(Float, nullable=True)
    lng: Mapped[float | None] = mapped_column(Float, nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    sort_order: Mapped[int] = mapped_column(Integer, default=0)
