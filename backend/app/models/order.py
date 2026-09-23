import enum
from datetime import datetime

from sqlalchemy import JSON, DateTime, Enum, Float, ForeignKey, Integer, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base


class OrderStatus(str, enum.Enum):
    pending = "pending"
    confirmed = "confirmed"
    preparing = "preparing"
    on_the_way = "on_the_way"
    delivered = "delivered"
    cancelled = "cancelled"


class Order(Base):
    __tablename__ = "orders"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    restaurant_id: Mapped[int] = mapped_column(ForeignKey("restaurants.id"))
    courier_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), index=True)
    status: Mapped[OrderStatus] = mapped_column(Enum(OrderStatus), default=OrderStatus.pending)
    address: Mapped[str] = mapped_column(String(300))
    comment: Mapped[str | None] = mapped_column(String(500))
    subtotal: Mapped[float] = mapped_column(Float)
    delivery_fee: Mapped[float] = mapped_column(Float)
    total: Mapped[float] = mapped_column(Float)
    rating: Mapped[int | None] = mapped_column(Integer)  # 1..5, set by customer after delivery
    # delivery | qr_table | pickup — string so we can add channels without a PG enum migrate
    channel: Mapped[str] = mapped_column(String(20), default="delivery")
    table_object_id: Mapped[int | None] = mapped_column(
        ForeignKey("floor_objects.id", ondelete="SET NULL")
    )
    dest_lat: Mapped[float | None] = mapped_column(Float, nullable=True)
    dest_lng: Mapped[float | None] = mapped_column(Float, nullable=True)
    pickup_lat: Mapped[float | None] = mapped_column(Float, nullable=True)
    pickup_lng: Mapped[float | None] = mapped_column(Float, nullable=True)
    # cash = pay the courier / at the counter. online needs a PaymentProvider.
    pay_method: Mapped[str] = mapped_column(String(20), default="cash")
    pay_status: Mapped[str] = mapped_column(String(20), default="unpaid")
    pay_ref: Mapped[str | None] = mapped_column(String(120), nullable=True)
    # Proof of delivery. The customer reads it out; the courier types it in.
    handover_code: Mapped[str | None] = mapped_column(String(8), nullable=True)
    checkout_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    scheduled_for: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    promo_code: Mapped[str | None] = mapped_column(String(24), nullable=True)
    discount: Mapped[float] = mapped_column(Float, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())

    user: Mapped["User"] = relationship(back_populates="orders", foreign_keys=[user_id])  # noqa: F821
    courier: Mapped["User | None"] = relationship(foreign_keys=[courier_id])  # noqa: F821
    restaurant: Mapped["Restaurant"] = relationship()  # noqa: F821
    items: Mapped[list["OrderItem"]] = relationship(
        back_populates="order", cascade="all, delete-orphan", lazy="selectin"
    )

    @property
    def customer(self) -> "User":  # noqa: F821
        return self.user

    @property
    def restaurant_name(self) -> str:
        return self.restaurant.name

    @property
    def courier_lat(self) -> float | None:
        return self.courier.last_lat if self.courier else None

    @property
    def courier_lng(self) -> float | None:
        return self.courier.last_lng if self.courier else None

    @property
    def courier_heading(self) -> float | None:
        return self.courier.last_heading if self.courier else None

    @property
    def courier_seen_at(self) -> datetime | None:
        return self.courier.last_seen_at if self.courier else None


class OrderItem(Base):
    __tablename__ = "order_items"

    id: Mapped[int] = mapped_column(primary_key=True)
    order_id: Mapped[int] = mapped_column(ForeignKey("orders.id"), index=True)
    menu_item_id: Mapped[int] = mapped_column(ForeignKey("menu_items.id"))
    name: Mapped[str] = mapped_column(String(150))  # snapshot at order time
    price: Mapped[float] = mapped_column(Float)  # unit price incl. modifiers
    quantity: Mapped[int] = mapped_column(Integer)
    modifiers: Mapped[list] = mapped_column(JSON, default=list)

    order: Mapped["Order"] = relationship(back_populates="items")
