from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base
from app.models.floor_plan import FloorObject
from app.models.restaurant import Restaurant


class Reservation(Base):
    """A booked sitting. Optional table; host can assign one later."""

    __tablename__ = "reservations"

    id: Mapped[int] = mapped_column(primary_key=True)
    restaurant_id: Mapped[int] = mapped_column(ForeignKey("restaurants.id"), index=True)
    user_id: Mapped[int | None] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True
    )
    table_object_id: Mapped[int | None] = mapped_column(
        Integer, ForeignKey("floor_objects.id", ondelete="SET NULL"), nullable=True, index=True
    )
    name: Mapped[str] = mapped_column(String(80))
    phone: Mapped[str | None] = mapped_column(String(30), nullable=True)
    guests: Mapped[int] = mapped_column(Integer, default=2)
    starts_at: Mapped[datetime] = mapped_column(DateTime, index=True)
    duration_min: Mapped[int] = mapped_column(Integer, default=90)
    status: Mapped[str] = mapped_column(String(20), default="requested")
    comment: Mapped[str | None] = mapped_column(String(500), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())

    restaurant: Mapped[Restaurant] = relationship()
    table: Mapped[FloorObject | None] = relationship(foreign_keys=[table_object_id])
