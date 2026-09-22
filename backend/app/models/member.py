from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base

STAFF_ROLES = (
    "owner",
    "admin",
    "manager",
    "cashier",
    "waiter",
    "kitchen",
    "delivery_manager",
    "delivery_courier",
    "accountant",
)


class RestaurantMember(Base):
    """A person who works at a restaurant. Platform admins are not rows here."""

    __tablename__ = "restaurant_members"
    __table_args__ = (UniqueConstraint("user_id", "restaurant_id", name="uq_member_user_restaurant"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    restaurant_id: Mapped[int] = mapped_column(
        ForeignKey("restaurants.id", ondelete="CASCADE"), index=True
    )
    role: Mapped[str] = mapped_column(String(40), default="manager")
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
