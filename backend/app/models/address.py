from sqlalchemy import Boolean, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base


class Address(Base):
    __tablename__ = "addresses"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    label: Mapped[str] = mapped_column(String(50))  # "Home", "Work"
    line: Mapped[str] = mapped_column(String(300))
    apt: Mapped[str | None] = mapped_column(String(40))
    entrance: Mapped[str | None] = mapped_column(String(40))
    floor: Mapped[str | None] = mapped_column(String(20))
    intercom: Mapped[str | None] = mapped_column(String(40))
    is_default: Mapped[bool] = mapped_column(Boolean, default=False)

    user: Mapped["User"] = relationship(back_populates="addresses")  # noqa: F821
