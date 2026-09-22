from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.models.order import OrderStatus


class OrderItemCreate(BaseModel):
    menu_item_id: int
    quantity: int = Field(ge=1, le=50)


class OrderCreate(BaseModel):
    restaurant_id: int
    address: str | None = Field(default=None, min_length=3, max_length=300)
    qr_token: str | None = Field(default=None, max_length=200)
    channel: str | None = Field(default=None, pattern="^(delivery|pickup)$")
    comment: str | None = Field(default=None, max_length=500)
    items: list[OrderItemCreate] = Field(min_length=1)

    @model_validator(mode="after")
    def destination(self) -> "OrderCreate":
        if (self.qr_token or "").strip():
            return self
        if self.channel == "pickup":
            return self
        if not self.address:
            raise ValueError("Provide a delivery address, pickup, or a table QR token")
        return self


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
    channel: str = "delivery"
    table_object_id: int | None = None
    created_at: datetime
    items: list[OrderItemOut]


class OrderStatusUpdate(BaseModel):
    status: OrderStatus


class OrderRate(BaseModel):
    rating: int = Field(ge=1, le=5)
