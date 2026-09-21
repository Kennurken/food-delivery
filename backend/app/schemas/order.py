from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from app.models.order import OrderStatus


class OrderItemCreate(BaseModel):
    menu_item_id: int
    quantity: int = Field(ge=1, le=50)


class OrderCreate(BaseModel):
    restaurant_id: int
    address: str = Field(min_length=3, max_length=300)
    comment: str | None = Field(default=None, max_length=500)
    items: list[OrderItemCreate] = Field(min_length=1)


class OrderItemOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    menu_item_id: int
    name: str
    price: float
    quantity: int


class UserBrief(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    phone: str | None


class OrderOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    restaurant_id: int
    customer: UserBrief
    courier: UserBrief | None = None
    restaurant_name: str
    status: OrderStatus
    address: str
    comment: str | None
    subtotal: float
    delivery_fee: float
    total: float
    rating: int | None
    created_at: datetime
    items: list[OrderItemOut]


class OrderStatusUpdate(BaseModel):
    status: OrderStatus


class OrderRate(BaseModel):
    rating: int = Field(ge=1, le=5)
