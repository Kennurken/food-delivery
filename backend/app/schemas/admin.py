from pydantic import BaseModel, Field


class RestaurantCreate(BaseModel):
    name: str = Field(min_length=1, max_length=150)
    description: str = ""
    cuisine: str = Field(min_length=1, max_length=50)
    image_url: str | None = None
    delivery_fee: float = Field(default=0, ge=0)
    delivery_time_min: int = Field(default=30, ge=1, le=240)
    lat: float | None = Field(default=None, ge=-90, le=90)
    lng: float | None = Field(default=None, ge=-180, le=180)


class RestaurantUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=150)
    description: str | None = None
    is_open: bool | None = None
    delivery_fee: float | None = Field(default=None, ge=0)
    delivery_time_min: int | None = Field(default=None, ge=1, le=240)
    plan_code: str | None = None
    billing_status: str | None = None
    lat: float | None = Field(default=None, ge=-90, le=90)
    lng: float | None = Field(default=None, ge=-180, le=180)


class MenuItemCreate(BaseModel):
    name: str = Field(min_length=1, max_length=150)
    description: str = ""
    price: float = Field(gt=0)
    category: str = Field(default="Main", max_length=50)
    image_url: str | None = None


class MenuItemUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=150)
    description: str | None = None
    price: float | None = Field(default=None, gt=0)
    category: str | None = Field(default=None, max_length=50)
    is_available: bool | None = None
    image_url: str | None = None
