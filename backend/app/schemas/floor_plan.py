from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator


class FloorCreate(BaseModel):
    name: str = Field(min_length=1, max_length=80)
    width_cm: float = Field(default=2000, ge=400, le=20000)
    height_cm: float = Field(default=1400, ge=400, le=20000)
    grid_cm: int = Field(default=40, ge=10, le=200)
    template: str | None = Field(default=None, max_length=40)


class FloorUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=80)
    sort_order: int | None = None
    width_cm: float | None = Field(default=None, ge=400, le=20000)
    height_cm: float | None = Field(default=None, ge=400, le=20000)
    grid_cm: int | None = Field(default=None, ge=10, le=200)


class FloorOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    restaurant_id: int
    name: str
    sort_order: int
    width_cm: float
    height_cm: float
    grid_cm: int
    updated_at: datetime


class ZoneIn(BaseModel):
    id: int | None = None
    name: str = Field(min_length=1, max_length=80)
    kind: str = Field(default="hall", max_length=40)
    color: str = Field(default="#C4B5A0", max_length=16)
    capacity: int | None = Field(default=None, ge=0, le=500)
    description: str = ""
    x: float
    y: float
    width: float = Field(gt=0)
    height: float = Field(gt=0)


class ZoneOut(ZoneIn):
    model_config = ConfigDict(from_attributes=True)

    id: int
    floor_id: int


class ObjectIn(BaseModel):
    id: int | None = None
    zone_id: int | None = None
    kind: str = Field(min_length=1, max_length=40)
    name: str = Field(default="", max_length=80)
    x: float
    y: float
    width: float = Field(gt=0)
    height: float = Field(gt=0)
    rotation: float = 0
    z_index: int = 0
    capacity: int | None = Field(default=None, ge=0, le=100)
    min_guests: int | None = Field(default=None, ge=0, le=100)
    max_guests: int | None = Field(default=None, ge=0, le=100)
    status: str = Field(default="available", max_length=20)
    mergeable: bool = False
    merge_group: str | None = Field(default=None, max_length=40)
    extra: dict = Field(default_factory=dict)

    @field_validator("extra", mode="before")
    @classmethod
    def extra_dict(cls, v: object) -> dict:
        return v if isinstance(v, dict) else {}


class ObjectOut(ObjectIn):
    model_config = ConfigDict(from_attributes=True)

    id: int
    floor_id: int


class FloorDetail(FloorOut):
    zones: list[ZoneOut]
    objects: list[ObjectOut]


class LayoutSave(BaseModel):
    updated_at: datetime
    zones: list[ZoneIn]
    objects: list[ObjectIn]


class VersionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    floor_id: int
    label: str
    created_at: datetime
