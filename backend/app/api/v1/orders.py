from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select

from app.api.deps import DB, AdminUser, CourierUser, CurrentUser
from app.models import Order, OrderStatus, UserRole
from app.schemas.order import OrderCreate, OrderOut, OrderRate, OrderStatusUpdate
from app.services import order_service

router = APIRouter(prefix="/orders", tags=["orders"])


@router.post("", response_model=OrderOut, status_code=status.HTTP_201_CREATED)
def create_order(data: OrderCreate, db: DB, user: CurrentUser) -> Order:
    return order_service.create_order(db, user, data)


@router.get("", response_model=list[OrderOut])
def my_orders(db: DB, user: CurrentUser) -> list[Order]:
    """Customer: own orders. Courier: assigned orders. Admin: everything."""
    stmt = select(Order).order_by(Order.created_at.desc())
    if user.role == UserRole.customer:
        stmt = stmt.where(Order.user_id == user.id)
    elif user.role == UserRole.courier:
        stmt = stmt.where(Order.courier_id == user.id)
    return list(db.scalars(stmt))


@router.get("/available", response_model=list[OrderOut])
def available_orders(db: DB, _: CourierUser) -> list[Order]:
    """Unassigned orders a courier can pick up."""
    stmt = (
        select(Order)
        .where(Order.courier_id.is_(None), Order.status.in_(order_service.COURIER_PICKABLE))
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
def set_status(order_id: int, data: OrderStatusUpdate, db: DB, _: AdminUser) -> Order:
    return order_service.update_status(db, _get_or_404(db, order_id), data.status)
