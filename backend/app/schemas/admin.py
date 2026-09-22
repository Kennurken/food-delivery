from pydantic import BaseModel, ConfigDict, Field


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
    delivery_fee_per_km: float | None = Field(default=None, ge=0, le=100000)
    delivery_free_km: float | None = Field(default=None, ge=0, le=100)
    delivery_max_km: float | None = Field(default=None, ge=0, le=500)
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


class ModifierOptionIn(BaseModel):
    name: str = Field(min_length=1, max_length=80)
    price_delta: float = 0
    is_default: bool = False
    is_available: bool = True


class ModifierGroupIn(BaseModel):
    name: str = Field(min_length=1, max_length=80)
    required: bool = False
    min_select: int = Field(default=0, ge=0, le=10)
    max_select: int = Field(default=1, ge=1, le=10)
    options: list[ModifierOptionIn] = Field(min_length=1)


class PromoCreate(BaseModel):
    code: str = Field(min_length=3, max_length=24)
    kind: str = Field(default="percent", pattern="^(percent|amount)$")
    value: float = Field(gt=0)
    min_subtotal: float = Field(default=0, ge=0)
    max_uses: int | None = Field(default=None, ge=1)
    is_active: bool = True


class PromoUpdate(BaseModel):
    kind: str | None = Field(default=None, pattern="^(percent|amount)$")
    value: float | None = Field(default=None, gt=0)
    min_subtotal: float | None = Field(default=None, ge=0)
    max_uses: int | None = Field(default=None, ge=1)
    is_active: bool | None = None


class PromoOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    restaurant_id: int
    code: str
    kind: str
    value: float
    min_subtotal: float
    is_active: bool
    max_uses: int | None
    used_count: int


class PromoQuote(BaseModel):
    code: str
    kind: str
    value: float
    min_subtotal: float
    discount: float
