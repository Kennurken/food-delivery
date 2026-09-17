from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select

from app.api.deps import DB, AdminUser, CurrentUser
from app.models import Order, OrderStatus, UserRole
from app.schemas.order import OrderCreate, OrderOut, OrderStatusUpdate
from app.services import order_service

router = APIRouter(prefix="/orders", tags=["orders"])


@router.post("", response_model=OrderOut, status_code=status.HTTP_201_CREATED)
def create_order(data: OrderCreate, db: DB, user: CurrentUser) -> Order:
    return order_service.create_order(db, user, data)


@router.get("", response_model=list[OrderOut])
def my_orders(db: DB, user: CurrentUser) -> list[Order]:
    stmt = select(Order).order_by(Order.created_at.desc())
    if user.role != UserRole.admin:
        stmt = stmt.where(Order.user_id == user.id)
    return list(db.scalars(stmt))


@router.get("/{order_id}", response_model=OrderOut)
def get_order(order_id: int, db: DB, user: CurrentUser) -> Order:
    order = db.get(Order, order_id)
    if not order or (order.user_id != user.id and user.role != UserRole.admin):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Order not found")
    return order


@router.post("/{order_id}/cancel", response_model=OrderOut)
def cancel_order(order_id: int, db: DB, user: CurrentUser) -> Order:
    order = get_order(order_id, db, user)
    return order_service.update_status(db, order, OrderStatus.cancelled)


@router.patch("/{order_id}/status", response_model=OrderOut)
def set_status(order_id: int, data: OrderStatusUpdate, db: DB, _: AdminUser) -> Order:
    order = db.get(Order, order_id)
    if not order:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Order not found")
    return order_service.update_status(db, order, data.status)
