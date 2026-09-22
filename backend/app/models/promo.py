from sqlalchemy import Boolean, Float, ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base


class Promo(Base):
    """One restaurant-scoped code. Applied at checkout, snapshotted on the order."""

    __tablename__ = "promos"
    __table_args__ = (UniqueConstraint("restaurant_id", "code", name="uq_promos_restaurant_code"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    restaurant_id: Mapped[int] = mapped_column(ForeignKey("restaurants.id"), index=True)
    code: Mapped[str] = mapped_column(String(24))
    kind: Mapped[str] = mapped_column(String(16), default="percent")  # percent | amount
    value: Mapped[float] = mapped_column(Float)
    min_subtotal: Mapped[float] = mapped_column(Float, default=0)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    max_uses: Mapped[int | None] = mapped_column(Integer, nullable=True)
    used_count: Mapped[int] = mapped_column(Integer, default=0)

    restaurant: Mapped["Restaurant"] = relationship()  # noqa: F821
