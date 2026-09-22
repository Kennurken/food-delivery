from pydantic import BaseModel, ConfigDict, Field, field_validator


def _blank_to_none(v: str | None) -> str | None:
    if v is None:
        return None
    s = v.strip()
    return s or None


class AddressCreate(BaseModel):
    label: str = Field(min_length=1, max_length=50)
    line: str = Field(min_length=3, max_length=300)
    apt: str | None = Field(default=None, max_length=40)
    entrance: str | None = Field(default=None, max_length=40)
    floor: str | None = Field(default=None, max_length=20)
    intercom: str | None = Field(default=None, max_length=40)
    is_default: bool = False

    @field_validator("apt", "entrance", "floor", "intercom", mode="before")
    @classmethod
    def blank_optional(cls, v: object) -> str | None:
        return _blank_to_none(v if isinstance(v, str) or v is None else str(v))


class AddressUpdate(BaseModel):
    label: str | None = Field(default=None, min_length=1, max_length=50)
    line: str | None = Field(default=None, min_length=3, max_length=300)
    apt: str | None = Field(default=None, max_length=40)
    entrance: str | None = Field(default=None, max_length=40)
    floor: str | None = Field(default=None, max_length=20)
    intercom: str | None = Field(default=None, max_length=40)
    is_default: bool | None = None

    @field_validator("apt", "entrance", "floor", "intercom", mode="before")
    @classmethod
    def blank_optional(cls, v: object) -> str | None:
        return _blank_to_none(v if isinstance(v, str) or v is None else str(v))


class AddressOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    label: str
    line: str
    apt: str | None = None
    entrance: str | None = None
    floor: str | None = None
    intercom: str | None = None
    is_default: bool
