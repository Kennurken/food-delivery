from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base


class Offer(Base):
    """A campaign with a page of its own.

    Distinct from `Promo`, which is a code the checkout applies. An offer is the
    thing a customer is shown and shares: a headline, a picture, a period, and
    optionally the code that makes it real. Half the campaigns a kitchen runs
    ("two for one on Tuesdays") have no code at all.
    """

    __tablename__ = "offers"

    id: Mapped[int] = mapped_column(primary_key=True)
    # Null = a platform-wide campaign rather than one venue's.
    restaurant_id: Mapped[int | None] = mapped_column(
        ForeignKey("restaurants.id", ondelete="CASCADE"), index=True, nullable=True
    )
    # Part of the public URL and of the sitemap, so it is stored, not derived:
    # a retitled campaign must not break links already shared.
    slug: Mapped[str] = mapped_column(String(80), unique=True, index=True)
    title: Mapped[str] = mapped_column(String(160))
    subtitle: Mapped[str] = mapped_column(String(300), default="")
    body: Mapped[str] = mapped_column(Text, default="")
    image_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    # The code this campaign is about, if it has one. Kept as text rather than a
    # foreign key: a campaign can name a code that has not been created yet, and
    # deleting a code should not delete the story about it.
    promo_code: Mapped[str | None] = mapped_column(String(24), nullable=True)
    starts_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    ends_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    sort_order: Mapped[int] = mapped_column(Integer, default=0)

    restaurant: Mapped["Restaurant | None"] = relationship()  # noqa: F821
