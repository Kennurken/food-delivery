from pydantic import BaseModel, ConfigDict, Field


class AddressCreate(BaseModel):
    label: str = Field(min_length=1, max_length=50)
    line: str = Field(min_length=3, max_length=300)
    is_default: bool = False


class AddressUpdate(BaseModel):
    label: str | None = Field(default=None, min_length=1, max_length=50)
    line: str | None = Field(default=None, min_length=3, max_length=300)
    is_default: bool | None = None


class AddressOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    label: str
    line: str
    is_default: bool
