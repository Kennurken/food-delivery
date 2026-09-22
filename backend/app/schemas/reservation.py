from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator


class ReservationCreate(BaseModel):
    restaurant_id: int
    table_object_id: int | None = None
    name: str = Field(min_length=1, max_length=80)
    phone: str | None = Field(default=None, max_length=30)
    guests: int = Field(default=2, ge=1, le=20)
    starts_at: datetime
    duration_min: int = Field(default=90, ge=60, le=180)
    comment: str | None = Field(default=None, max_length=500)

    @field_validator("name")
    @classmethod
    def _name(cls, value: str) -> str:
        text = value.strip()
        if not text:
            raise ValueError("Name is empty")
        return text

    @field_validator("phone")
    @classmethod
    def _phone(cls, value: str | None) -> str | None:
        if value is None:
            return None
        text = value.strip()
        return text or None


class ReservationUpdate(BaseModel):
    status: str | None = Field(
        default=None,
        pattern="^(requested|confirmed|seated|cancelled|no_show)$",
    )
    table_object_id: int | None = None
    guests: int | None = Field(default=None, ge=1, le=20)


class ReservationOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    restaurant_id: int
    restaurant_name: str = ""
    user_id: int | None
    table_object_id: int | None
    table_name: str | None = None
    name: str
    phone: str | None
    guests: int
    starts_at: datetime
    duration_min: int
    status: str
    comment: str | None
    created_at: datetime


class TableOut(BaseModel):
    id: int
    name: str
    capacity: int | None
    status: str
    floor_name: str
    kind: str
