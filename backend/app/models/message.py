from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base


class OrderMessage(Base):
    """One line in an order thread. `sender_name` is a snapshot."""

    __tablename__ = "order_messages"

    id: Mapped[int] = mapped_column(primary_key=True)
    order_id: Mapped[int] = mapped_column(ForeignKey("orders.id", ondelete="CASCADE"), index=True)
    user_id: Mapped[int | None] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True
    )
    sender_name: Mapped[str] = mapped_column(String(80))
    body: Mapped[str] = mapped_column(String(800))
    # "text" is a person talking; "escalation" is the thread saying a member of
    # staff called the venue's manager in. The app words it in the reader's language.
    kind: Mapped[str] = mapped_column(String(12), default="text", server_default="text")
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())

    order: Mapped["Order"] = relationship()  # noqa: F821
