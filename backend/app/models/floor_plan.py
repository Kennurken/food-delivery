from datetime import datetime

from sqlalchemy import JSON, DateTime, Float, ForeignKey, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base


class Floor(Base):
    __tablename__ = "floors"

    id: Mapped[int] = mapped_column(primary_key=True)
    restaurant_id: Mapped[int] = mapped_column(ForeignKey("restaurants.id", ondelete="CASCADE"), index=True)
    name: Mapped[str] = mapped_column(String(80))
    sort_order: Mapped[int] = mapped_column(Integer, default=0)
    width_cm: Mapped[float] = mapped_column(Float, default=2000)
    height_cm: Mapped[float] = mapped_column(Float, default=1400)
    grid_cm: Mapped[int] = mapped_column(Integer, default=40)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, server_default=func.now(), onupdate=func.now(), default=func.now()
    )

    restaurant: Mapped["Restaurant"] = relationship()  # noqa: F821
    zones: Mapped[list["FloorZone"]] = relationship(back_populates="floor", cascade="all, delete-orphan")
    objects: Mapped[list["FloorObject"]] = relationship(back_populates="floor", cascade="all, delete-orphan")
    versions: Mapped[list["FloorVersion"]] = relationship(back_populates="floor", cascade="all, delete-orphan")


class FloorZone(Base):
    __tablename__ = "floor_zones"

    id: Mapped[int] = mapped_column(primary_key=True)
    floor_id: Mapped[int] = mapped_column(ForeignKey("floors.id", ondelete="CASCADE"), index=True)
    name: Mapped[str] = mapped_column(String(80))
    kind: Mapped[str] = mapped_column(String(40), default="hall")
    color: Mapped[str] = mapped_column(String(16), default="#C4B5A0")
    capacity: Mapped[int | None] = mapped_column(Integer)
    description: Mapped[str] = mapped_column(Text, default="")
    x: Mapped[float] = mapped_column(Float, default=80)
    y: Mapped[float] = mapped_column(Float, default=80)
    width: Mapped[float] = mapped_column(Float, default=800)
    height: Mapped[float] = mapped_column(Float, default=600)

    floor: Mapped[Floor] = relationship(back_populates="zones")


class FloorObject(Base):
    """A placed layout node. Tables live here — the app has no separate Table entity."""

    __tablename__ = "floor_objects"

    id: Mapped[int] = mapped_column(primary_key=True)
    floor_id: Mapped[int] = mapped_column(ForeignKey("floors.id", ondelete="CASCADE"), index=True)
    zone_id: Mapped[int | None] = mapped_column(ForeignKey("floor_zones.id", ondelete="SET NULL"))
    kind: Mapped[str] = mapped_column(String(40), index=True)
    name: Mapped[str] = mapped_column(String(80), default="")
    x: Mapped[float] = mapped_column(Float)
    y: Mapped[float] = mapped_column(Float)
    width: Mapped[float] = mapped_column(Float)
    height: Mapped[float] = mapped_column(Float)
    rotation: Mapped[float] = mapped_column(Float, default=0)
    z_index: Mapped[int] = mapped_column(Integer, default=0)
    capacity: Mapped[int | None] = mapped_column(Integer)
    min_guests: Mapped[int | None] = mapped_column(Integer)
    max_guests: Mapped[int | None] = mapped_column(Integer)
    status: Mapped[str] = mapped_column(String(20), default="available")
    mergeable: Mapped[bool] = mapped_column(default=False)
    merge_group: Mapped[str | None] = mapped_column(String(40))
    extra: Mapped[dict | None] = mapped_column(JSON, default=dict)

    floor: Mapped[Floor] = relationship(back_populates="objects")


class FloorVersion(Base):
    __tablename__ = "floor_versions"

    id: Mapped[int] = mapped_column(primary_key=True)
    floor_id: Mapped[int] = mapped_column(ForeignKey("floors.id", ondelete="CASCADE"), index=True)
    label: Mapped[str] = mapped_column(String(80), default="")
    snapshot: Mapped[dict] = mapped_column(JSON)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())

    floor: Mapped[Floor] = relationship(back_populates="versions")
