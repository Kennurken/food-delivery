from datetime import datetime

from sqlalchemy import DateTime, Float, ForeignKey, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base


class LoyaltyEntry(Base):
    """One movement of a diner's bonus balance at one venue.

    A ledger, not a balance column: the balance is the sum of the rows, so it
    can always be explained line by line when a diner asks where their bonuses
    went, and two concurrent writes can't overwrite each other's total.

    Bonuses are per venue. A restaurant pays for its own programme (a Premium
    feature), so what it gives back can only be spent with it.

    Amounts are tenge: one bonus is worth one tenge at checkout.
    """

    __tablename__ = "loyalty_entries"
    # An order earns once, spends once and is refunded once. Status changes can
    # be retried (a webhook, a double tap); the ledger must not be.
    __table_args__ = (UniqueConstraint("order_id", "kind", name="uq_loyalty_order_kind"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    restaurant_id: Mapped[int] = mapped_column(
        ForeignKey("restaurants.id", ondelete="CASCADE"), index=True
    )
    order_id: Mapped[int | None] = mapped_column(
        ForeignKey("orders.id", ondelete="SET NULL"), nullable=True
    )
    # earn (+), spend (−), refund (+, a cancelled order gives back what it spent)
    kind: Mapped[str] = mapped_column(String(12))
    amount: Mapped[float] = mapped_column(Float)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())
