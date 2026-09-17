from pydantic import BaseModel, ConfigDict


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
    delivery_fee: float
    delivery_time_min: int
    is_open: bool


class RestaurantDetail(RestaurantOut):
    menu_items: list[MenuItemOut]
