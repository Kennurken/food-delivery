from pydantic import BaseModel, ConfigDict, Field


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
    delivery_time_min: int
    is_open: bool
    plan_code: str = "pro"
    channels: list[str] = Field(default_factory=lambda: ["delivery"])
    lat: float | None = None
    lng: float | None = None


class RestaurantDetail(RestaurantOut):
    menu_items: list[MenuItemOut]
