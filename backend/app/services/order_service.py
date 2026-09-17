from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import MenuItem, Order, OrderItem, OrderStatus, Restaurant, User
from app.schemas.order import OrderCreate

# Allowed status transitions: current -> set of next
_TRANSITIONS: dict[OrderStatus, set[OrderStatus]] = {
    OrderStatus.pending: {OrderStatus.confirmed, OrderStatus.cancelled},
    OrderStatus.confirmed: {OrderStatus.preparing, OrderStatus.cancelled},
    OrderStatus.preparing: {OrderStatus.on_the_way},
    OrderStatus.on_the_way: {OrderStatus.delivered},
    OrderStatus.delivered: set(),
    OrderStatus.cancelled: set(),
}


def create_order(db: Session, user: User, data: OrderCreate) -> Order:
    restaurant = db.get(Restaurant, data.restaurant_id)
    if not restaurant or not restaurant.is_open:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Restaurant not found or closed")

    ids = [i.menu_item_id for i in data.items]
    menu_items = db.scalars(
        select(MenuItem).where(MenuItem.id.in_(ids), MenuItem.restaurant_id == restaurant.id)
    ).all()
    by_id = {m.id: m for m in menu_items}
    if len(by_id) != len(set(ids)):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Some menu items are invalid")

    items: list[OrderItem] = []
    subtotal = 0.0
    for line in data.items:
        m = by_id[line.menu_item_id]
        if not m.is_available:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, f"{m.name} is unavailable")
        subtotal += m.price * line.quantity
        items.append(OrderItem(menu_item_id=m.id, name=m.name, price=m.price, quantity=line.quantity))

    order = Order(
        user_id=user.id,
        restaurant_id=restaurant.id,
        address=data.address,
        comment=data.comment,
        subtotal=round(subtotal, 2),
        delivery_fee=restaurant.delivery_fee,
        total=round(subtotal + restaurant.delivery_fee, 2),
        items=items,
    )
    db.add(order)
    db.commit()
    db.refresh(order)
    return order


# Statuses a courier can pick up from
COURIER_PICKABLE = {OrderStatus.confirmed, OrderStatus.preparing}


def accept_order(db: Session, courier: User, order: Order) -> Order:
    if order.courier_id is not None:
        raise HTTPException(status.HTTP_409_CONFLICT, "Order already taken")
    if order.status not in COURIER_PICKABLE:
        raise HTTPException(status.HTTP_409_CONFLICT, "Order not ready for pickup")
    order.courier_id = courier.id
    db.commit()
    db.refresh(order)
    return order


def advance_order(db: Session, courier: User, order: Order) -> Order:
    """Courier moves own order one step: preparing -> on_the_way -> delivered."""
    if order.courier_id != courier.id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Not your order")
    next_status = {
        OrderStatus.confirmed: OrderStatus.preparing,
        OrderStatus.preparing: OrderStatus.on_the_way,
        OrderStatus.on_the_way: OrderStatus.delivered,
    }.get(order.status)
    if next_status is None:
        raise HTTPException(status.HTTP_409_CONFLICT, f"Cannot advance from {order.status.value}")
    return update_status(db, order, next_status)


def update_status(db: Session, order: Order, new_status: OrderStatus) -> Order:
    if new_status not in _TRANSITIONS[order.status]:
        raise HTTPException(
            status.HTTP_409_CONFLICT, f"Cannot move from {order.status.value} to {new_status.value}"
        )
    order.status = new_status
    db.commit()
    db.refresh(order)
    return order
