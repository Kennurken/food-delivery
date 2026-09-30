from datetime import datetime

from sqlalchemy import (
    Boolean,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
    true,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base


class Restaurant(Base):
    __tablename__ = "restaurants"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(150), index=True)
    # Part of the public URL (/r/<slug>/) and of the sitemap, so it is stored
    # rather than derived: a rename must not break links already shared.
    slug: Mapped[str | None] = mapped_column(String(80), unique=True, index=True, nullable=True)
    description: Mapped[str] = mapped_column(Text, default="")
    cuisine: Mapped[str] = mapped_column(String(50), index=True)
    image_url: Mapped[str | None] = mapped_column(String(500))
    rating: Mapped[float] = mapped_column(Float, default=0.0)
    rating_count: Mapped[int] = mapped_column(Integer, default=0)
    # Delivery pricing. per_km = 0 keeps the flat fee this column always meant.
    delivery_fee: Mapped[float] = mapped_column(Float, default=0.0)
    delivery_fee_per_km: Mapped[float] = mapped_column(Float, default=0.0)
    delivery_free_km: Mapped[float] = mapped_column(Float, default=0.0)
    delivery_max_km: Mapped[float | None] = mapped_column(Float, nullable=True)
    # Tickets the kitchen will hold at once. None = no cap.
    max_active_orders: Mapped[int | None] = mapped_column(Integer, nullable=True)
    delivery_time_min: Mapped[int] = mapped_column(Integer, default=30)
    is_open: Mapped[bool] = mapped_column(Boolean, default=True)
    # Whether guests can see and order from this venue. A venue that applied
    # through the site starts "pending" and is invisible until the platform
    # approves it; every venue that existed before applications is "approved".
    approval: Mapped[str] = mapped_column(String(12), default="approved", server_default="approved")
    # Does the venue have its own couriers? Asked when it applies. Without them
    # it takes pickup and table orders only — the platform hires no couriers.
    offers_delivery: Mapped[bool] = mapped_column(Boolean, default=True, server_default=true())
    applied_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    rejection_reason: Mapped[str | None] = mapped_column(String(300), nullable=True)
    # Share of what a diner paid for food that comes back to them as bonuses
    # (5 = 5 %). 0 = no programme. Earning also needs the Premium `loyalty`
    # entitlement: a venue that stops paying for it stops giving, though what
    # diners already hold stays spendable.
    loyalty_percent: Mapped[float] = mapped_column(Float, default=0.0, server_default="0")
    # At most this share of the food subtotal can be paid with bonuses, so a
    # programme can't turn into free dinners.
    loyalty_max_share: Mapped[float] = mapped_column(Float, default=0.5, server_default="0.5")
    # Restaurant is the tenant. Plan codes are keys in app.core.features.PLANS.
    plan_code: Mapped[str] = mapped_column(String(20), default="pro")
    billing_status: Mapped[str] = mapped_column(String(20), default="active")
    # Stripe Billing. A subscription is only ever written here from a webhook:
    # the processor decides whether someone has paid, never this process.
    stripe_customer_id: Mapped[str | None] = mapped_column(String(80), nullable=True)
    stripe_subscription_id: Mapped[str | None] = mapped_column(String(80), nullable=True)
    plan_renews_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    lat: Mapped[float | None] = mapped_column(Float, nullable=True)
    lng: Mapped[float | None] = mapped_column(Float, nullable=True)
    # Nullable so a venue can exist before anyone decides where it trades;
    # every venue that predates cities is backfilled into the default one.
    city_id: Mapped[int | None] = mapped_column(
        ForeignKey("cities.id", ondelete="SET NULL"), index=True, nullable=True
    )
    city: Mapped["City | None"] = relationship()  # noqa: F821
    # Loaded with the venue (one extra query per batch, not per venue): every
    # listing asks whether each card is open.
    hours: Mapped[list["OpeningHours"]] = relationship(  # noqa: F821
        cascade="all, delete-orphan",
        order_by="(OpeningHours.weekday, OpeningHours.opens)",
        lazy="selectin",
    )

    menu_items: Mapped[list["MenuItem"]] = relationship(
        back_populates="restaurant", cascade="all, delete-orphan"
    )


class MenuItem(Base):
    __tablename__ = "menu_items"

    id: Mapped[int] = mapped_column(primary_key=True)
    restaurant_id: Mapped[int] = mapped_column(ForeignKey("restaurants.id"), index=True)
    name: Mapped[str] = mapped_column(String(150))
    description: Mapped[str] = mapped_column(Text, default="")
    price: Mapped[float] = mapped_column(Float)
    category: Mapped[str] = mapped_column(String(50), default="Main")
    image_url: Mapped[str | None] = mapped_column(String(500))
    is_available: Mapped[bool] = mapped_column(Boolean, default=True)

    restaurant: Mapped["Restaurant"] = relationship(back_populates="menu_items")
    modifier_groups: Mapped[list["ModifierGroup"]] = relationship(
        back_populates="menu_item", cascade="all, delete-orphan", lazy="selectin"
    )


class ModifierGroup(Base):
    __tablename__ = "modifier_groups"

    id: Mapped[int] = mapped_column(primary_key=True)
    menu_item_id: Mapped[int] = mapped_column(ForeignKey("menu_items.id"), index=True)
    name: Mapped[str] = mapped_column(String(80))
    required: Mapped[bool] = mapped_column(Boolean, default=False)
    min_select: Mapped[int] = mapped_column(Integer, default=0)
    max_select: Mapped[int] = mapped_column(Integer, default=1)

    menu_item: Mapped["MenuItem"] = relationship(back_populates="modifier_groups")
    options: Mapped[list["ModifierOption"]] = relationship(
        back_populates="group",
        cascade="all, delete-orphan",
        lazy="selectin",
        order_by="ModifierOption.id",
    )


class ModifierOption(Base):
    __tablename__ = "modifier_options"

    id: Mapped[int] = mapped_column(primary_key=True)
    group_id: Mapped[int] = mapped_column(ForeignKey("modifier_groups.id"), index=True)
    name: Mapped[str] = mapped_column(String(80))
    price_delta: Mapped[float] = mapped_column(Float, default=0)
    is_default: Mapped[bool] = mapped_column(Boolean, default=False)
    is_available: Mapped[bool] = mapped_column(Boolean, default=True)

    group: Mapped["ModifierGroup"] = relationship(back_populates="options")
