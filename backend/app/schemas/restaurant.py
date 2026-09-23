from pydantic import BaseModel, ConfigDict, Field


class ModifierOptionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    price_delta: float
    is_default: bool
    is_available: bool


class ModifierGroupOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    required: bool
    min_select: int
    max_select: int
    options: list[ModifierOptionOut] = Field(default_factory=list)


class MenuItemOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    restaurant_id: int
    name: str
    description: str
    price: float
    category: str
    image_url: str | None
    is_available: bool
    modifier_groups: list[ModifierGroupOut] = Field(default_factory=list)


class RestaurantOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    description: str
    cuisine: str
    image_url: str | None
    rating: float
    rating_count: int
    delivery_fee: float
    delivery_fee_per_km: float = 0
    delivery_free_km: float = 0
    delivery_max_km: float | None = None
    delivery_time_min: int
    is_open: bool
    # Open *and* with room on the stove. The storefront greys out a full kitchen
    # instead of letting someone build a cart it will refuse.
    accepting_orders: bool = True
    kitchen_busy: bool = False
    plan_code: str = "pro"
    channels: list[str] = Field(default_factory=lambda: ["delivery"])
    reservations: bool = False
    lat: float | None = None
    lng: float | None = None


class RestaurantDetail(RestaurantOut):
    menu_items: list[MenuItemOut]
