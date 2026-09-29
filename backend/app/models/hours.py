from datetime import time

from sqlalchemy import ForeignKey, Integer, Time
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base


class OpeningHours(Base):
    """One stretch of a weekday when the kitchen takes orders.

    Several rows on one day mean a break (11:00–15:00, 17:00–23:00). A row whose
    `closes` is not after `opens` runs past midnight into the next day
    (18:00–02:00), which is how a bar's Friday actually looks. A venue with no
    rows at all has no schedule, and only the owner's open switch applies — so
    every venue that predates schedules keeps behaving as it did.

    Times are the venue's local wall clock (its city's offset), never UTC: an
    owner types "10:00" and means ten in the morning where the kitchen is.
    """

    __tablename__ = "opening_hours"

    id: Mapped[int] = mapped_column(primary_key=True)
    restaurant_id: Mapped[int] = mapped_column(
        ForeignKey("restaurants.id", ondelete="CASCADE"), index=True
    )
    weekday: Mapped[int] = mapped_column(Integer)  # 0 = Monday … 6 = Sunday
    opens: Mapped[time] = mapped_column(Time)
    closes: Mapped[time] = mapped_column(Time)
