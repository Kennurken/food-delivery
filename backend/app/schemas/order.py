from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from app.models.order import OrderStatus


class OrderItemCreate(BaseModel):
    menu_item_id: int
    quantity: int = Field(ge=1, le=50)
    option_ids: list[int] = Field(default_factory=list)


class OrderCreate(BaseModel):
    restaurant_id: int
    address: str | None = Field(default=None, min_length=3, max_length=300)
    qr_token: str | None = Field(default=None, max_length=200)
    channel: str | None = Field(default=None, pattern="^(delivery|pickup)$")
    dest_lat: float | None = Field(default=None, ge=-90, le=90)
    dest_lng: float | None = Field(default=None, ge=-180, le=180)
    comment: str | None = Field(default=None, max_length=500)
    pay_method: str = Field(default="cash", pattern="^(cash|online)$")
    promo_code: str | None = Field(default=None, max_length=24)
    scheduled_for: datetime | None = None
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
    modifiers: list[dict] = Field(default_factory=list)

    @field_validator("modifiers", mode="before")
    @classmethod
    def _mods(cls, value: object) -> object:
        return value or []


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
    dest_lat: float | None = None
    dest_lng: float | None = None
    pickup_lat: float | None = None
    pickup_lng: float | None = None
    courier_lat: float | None = None
    courier_lng: float | None = None
    courier_heading: float | None = None
    courier_seen_at: datetime | None = None
    pay_method: str = "cash"
    pay_status: str = "unpaid"
    pay_ref: str | None = None
    checkout_url: str | None = None
    scheduled_for: datetime | None = None
    promo_code: str | None = None
    discount: float = 0
    created_at: datetime
    items: list[OrderItemOut]


class OrderStatusUpdate(BaseModel):
    status: OrderStatus


class OrderRate(BaseModel):
    rating: int = Field(ge=1, le=5)
