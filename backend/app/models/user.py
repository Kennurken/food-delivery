import enum
from datetime import datetime

from sqlalchemy import Boolean, DateTime, Enum, Float, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base


class UserRole(str, enum.Enum):
    customer = "customer"
    courier = "courier"
    admin = "admin"


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    name: Mapped[str] = mapped_column(String(100))
    phone: Mapped[str | None] = mapped_column(String(30))
    hashed_password: Mapped[str] = mapped_column(String(255))
    role: Mapped[UserRole] = mapped_column(Enum(UserRole), default=UserRole.customer)
    # A table session rather than an account: created by scanning a QR, with
    # no password anyone knows. Kept as a flag so the app can stop offering
    # profile settings that mean nothing without an email.
    is_guest: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())
    last_lat: Mapped[float | None] = mapped_column(Float, nullable=True)
    last_lng: Mapped[float | None] = mapped_column(Float, nullable=True)
    last_heading: Mapped[float | None] = mapped_column(Float, nullable=True)
    last_seen_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)

    orders: Mapped[list["Order"]] = relationship(back_populates="user", foreign_keys="Order.user_id")  # noqa: F821
    addresses: Mapped[list["Address"]] = relationship(  # noqa: F821
        back_populates="user", cascade="all, delete-orphan", order_by="Address.id"
    )
