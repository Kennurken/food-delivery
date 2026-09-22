from datetime import timedelta
from typing import Annotated

from fastapi import APIRouter, Header, HTTPException, Query, status
from sqlalchemy import or_, select

from app.api.deps import DB, CourierUser, CurrentUser
from app.core.access import require_restaurant
from app.models import Order, OrderStatus, UserRole
from app.schemas.order import OrderCreate, OrderOut, OrderRate, OrderStatusUpdate
from app.services import order_service
from app.services.schedule import utcnow

router = APIRouter(prefix="/orders", tags=["orders"])


@router.post("", response_model=OrderOut, status_code=status.HTTP_201_CREATED)
def create_order(
    data: OrderCreate,
    db: DB,
    user: CurrentUser,
    idempotency_key: Annotated[str | None, Header()] = None,
) -> Order:
    return order_service.create_order(db, user, data, idempotency_key=idempotency_key)


@router.get("", response_model=list[OrderOut])
def my_orders(
    db: DB,
    user: CurrentUser,
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
    restaurant_id: int | None = None,
) -> list[Order]:
    """Customer: own orders. Courier: assigned. Kitchen/admin: a venue's tickets."""
    stmt = (
        select(Order).order_by(Order.created_at.desc(), Order.id.desc()).limit(limit).offset(offset)
    )
    if restaurant_id is not None:
        require_restaurant(db, user, restaurant_id, "orders.read")
        stmt = stmt.where(Order.restaurant_id == restaurant_id)
    elif user.role == UserRole.customer:
        stmt = stmt.where(Order.user_id == user.id)
    elif user.role == UserRole.courier:
        stmt = stmt.where(Order.courier_id == user.id)
    return list(db.scalars(stmt))


@router.get("/available", response_model=list[OrderOut])
def available_orders(db: DB, _: CourierUser) -> list[Order]:
    """Unassigned orders a courier can pick up."""
    stmt = (
        select(Order)
        .where(
            Order.courier_id.is_(None),
            Order.status.in_(order_service.COURIER_PICKABLE),
            Order.channel == order_service.DELIVERY_CHANNEL,
            or_(
                Order.scheduled_for.is_(None),
                Order.scheduled_for <= utcnow() + timedelta(minutes=40),
            ),
        )
        .order_by(Order.created_at)
    )
    return list(db.scalars(stmt))


def _get_or_404(db, order_id: int) -> Order:
    order = db.get(Order, order_id)
    if not order:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Order not found")
    return order


@router.post("/{order_id}/accept", response_model=OrderOut)
def accept_order(order_id: int, db: DB, courier: CourierUser) -> Order:
    return order_service.accept_order(db, courier, _get_or_404(db, order_id))


@router.post("/{order_id}/advance", response_model=OrderOut)
def advance_order(order_id: int, db: DB, courier: CourierUser) -> Order:
    return order_service.advance_order(db, courier, _get_or_404(db, order_id))


@router.get("/{order_id}", response_model=OrderOut)
def get_order(order_id: int, db: DB, user: CurrentUser) -> Order:
    order = db.get(Order, order_id)
    visible = order and (
        user.role == UserRole.admin or order.user_id == user.id or order.courier_id == user.id
    )
    if order and not visible:
        try:
            require_restaurant(db, user, order.restaurant_id, "orders.read")
            visible = True
        except HTTPException:
            visible = False
    if not visible:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Order not found")
    return order


@router.post("/{order_id}/cancel", response_model=OrderOut)
def cancel_order(order_id: int, db: DB, user: CurrentUser) -> Order:
    order = get_order(order_id, db, user)
    if order.user_id != user.id and user.role != UserRole.admin:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Only the customer can cancel")
    return order_service.update_status(db, order, OrderStatus.cancelled)


@router.post("/{order_id}/rate", response_model=OrderOut)
def rate_order(order_id: int, data: OrderRate, db: DB, user: CurrentUser) -> Order:
    return order_service.rate_order(db, user, get_order(order_id, db, user), data.rating)


@router.patch("/{order_id}/status", response_model=OrderOut)
def set_status(order_id: int, data: OrderStatusUpdate, db: DB, user: CurrentUser) -> Order:
    order = _get_or_404(db, order_id)
    require_restaurant(db, user, order.restaurant_id, "orders.manage")
    return order_service.update_status(db, order, data.status)
