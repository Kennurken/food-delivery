from sqlalchemy import Boolean, ForeignKey, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base


class FeatureOverride(Base):
    """Per-tenant flag that adds or removes a plan feature without changing the plan."""

    __tablename__ = "feature_overrides"
    __table_args__ = (UniqueConstraint("restaurant_id", "key", name="uq_feature_restaurant_key"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    restaurant_id: Mapped[int] = mapped_column(
        ForeignKey("restaurants.id", ondelete="CASCADE"), index=True
    )
    key: Mapped[str] = mapped_column(String(80))
    enabled: Mapped[bool] = mapped_column(Boolean, default=True)
