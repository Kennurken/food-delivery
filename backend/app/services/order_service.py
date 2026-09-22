from hashlib import sha256

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.events import hub
from app.core.features import INACTIVE_BILLING, entitlements
from app.core.qr import parse_table_token
from app.models import MenuItem, Order, OrderItem, OrderStatus, Restaurant, User, UserRole
from app.models.floor_plan import FloorObject
from app.models.idempotency import IdempotencyRecord
from app.schemas.order import OrderCreate, OrderOut

# Statuses a courier can pick up from
COURIER_PICKABLE = {OrderStatus.confirmed, OrderStatus.preparing}
DELIVERY_CHANNEL = "delivery"


def _is_delivery(order: Order) -> bool:
    return (order.channel or DELIVERY_CHANNEL) == DELIVERY_CHANNEL


def notify(db: Session, order: Order) -> None:
    """Push the order snapshot to the customer, assigned courier, and admins.

    Unassigned pickable orders also go to every courier so the available-pool
    banner still fires — they do not see other couriers' in-flight deliveries.
    Dine-in / pickup never hits the courier pool.
    """
    admins = set(db.scalars(select(User.id).where(User.role == UserRole.admin)))
    targets = admins | {order.user_id}
    if order.courier_id:
        targets.add(order.courier_id)
    elif _is_delivery(order) and order.status in COURIER_PICKABLE:
        targets.update(db.scalars(select(User.id).where(User.role == UserRole.courier)))
    payload = {"type": "order.updated", "order": OrderOut.model_validate(order).model_dump(mode="json")}
    hub.publish_threadsafe(targets, payload)


# Allowed status transitions: current -> set of next
_TRANSITIONS: dict[OrderStatus, set[OrderStatus]] = {
    OrderStatus.pending: {OrderStatus.confirmed, OrderStatus.cancelled},
    OrderStatus.confirmed: {OrderStatus.preparing, OrderStatus.cancelled},
    OrderStatus.preparing: {OrderStatus.on_the_way},
    OrderStatus.on_the_way: {OrderStatus.delivered},
    OrderStatus.delivered: set(),
    OrderStatus.cancelled: set(),
}


def _allowed(order: Order, new_status: OrderStatus) -> bool:
    allowed = set(_TRANSITIONS[order.status])
    if not _is_delivery(order) and order.status == OrderStatus.preparing:
        allowed = {OrderStatus.delivered, OrderStatus.cancelled}
    return new_status in allowed


def _resolve_table(db: Session, token: str, restaurant_id: int) -> FloorObject:
    parsed = parse_table_token(token)
    if not parsed:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Invalid table QR")
    rid, oid = parsed
    if rid != restaurant_id:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "QR does not belong to this restaurant")
    obj = db.get(FloorObject, oid)
    if not obj or obj.floor.restaurant_id != restaurant_id or not obj.kind.startswith("table"):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Unknown table")
    return obj


def create_order(
    db: Session, user: User, data: OrderCreate, *, idempotency_key: str | None = None
) -> Order:
    restaurant = db.get(Restaurant, data.restaurant_id)
    if not restaurant or not restaurant.is_open:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Restaurant not found or closed")
    if restaurant.billing_status in INACTIVE_BILLING:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Restaurant subscription is inactive")

    body_hash = sha256(data.model_dump_json().encode()).hexdigest()
    if idempotency_key:
        rec = db.scalar(
            select(IdempotencyRecord).where(
                IdempotencyRecord.user_id == user.id,
                IdempotencyRecord.key == idempotency_key,
            )
        )
        if rec:
            if rec.body_hash != body_hash:
                raise HTTPException(
                    status.HTTP_409_CONFLICT, "Idempotency key reused with a different body"
                )
            existing = db.get(Order, rec.order_id) if rec.order_id else None
            if existing:
                return existing

    flags = entitlements(db, restaurant)
    channel = DELIVERY_CHANNEL
    table_object_id = None
    address = (data.address or "").strip()
    delivery_fee = restaurant.delivery_fee

    if (data.qr_token or "").strip():
        if not flags.enabled("table.ordering"):
            raise HTTPException(status.HTTP_403_FORBIDDEN, "Table ordering is not on this plan")
        obj = _resolve_table(db, data.qr_token.strip(), restaurant.id)
        channel = "qr_table"
        table_object_id = obj.id
        address = obj.name or f"Table {obj.id}"
        delivery_fee = 0
    else:
        if not flags.enabled("delivery.enabled"):
            raise HTTPException(status.HTTP_403_FORBIDDEN, "Delivery is not on this plan")

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
        address=address,
        comment=data.comment,
        subtotal=round(subtotal, 2),
        delivery_fee=delivery_fee,
        total=round(subtotal + delivery_fee, 2),
        items=items,
        channel=channel,
        table_object_id=table_object_id,
    )
    db.add(order)
    db.flush()
    if idempotency_key:
        db.add(
            IdempotencyRecord(
                user_id=user.id,
                key=idempotency_key,
                body_hash=body_hash,
                order_id=order.id,
            )
        )
    db.commit()
    db.refresh(order)
    notify(db, order)
    return order


def accept_order(db: Session, courier: User, order: Order) -> Order:
    locked = db.scalar(select(Order).where(Order.id == order.id).with_for_update())
    if locked is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Order not found")
    if not _is_delivery(locked):
        raise HTTPException(status.HTTP_409_CONFLICT, "Not a delivery order")
    if locked.courier_id is not None:
        raise HTTPException(status.HTTP_409_CONFLICT, "Order already taken")
    if locked.status not in COURIER_PICKABLE:
        raise HTTPException(status.HTTP_409_CONFLICT, "Order not ready for pickup")
    locked.courier_id = courier.id
    db.commit()
    db.refresh(locked)
    notify(db, locked)
    return locked


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
    if not _allowed(order, new_status):
        raise HTTPException(
            status.HTTP_409_CONFLICT, f"Cannot move from {order.status.value} to {new_status.value}"
        )
    order.status = new_status
    db.commit()
    db.refresh(order)
    notify(db, order)
    return order


def rate_order(db: Session, user: User, order: Order, rating: int) -> Order:
    if order.user_id != user.id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Not your order")
    if order.status != OrderStatus.delivered:
        raise HTTPException(status.HTTP_409_CONFLICT, "Only delivered orders can be rated")
    if order.rating is not None:
        raise HTTPException(status.HTTP_409_CONFLICT, "Already rated")
    order.rating = rating
    # Running average keeps it O(1); no need to scan all orders.
    r = order.restaurant
    r.rating = round((r.rating * r.rating_count + rating) / (r.rating_count + 1), 2)
    r.rating_count += 1
    db.commit()
    db.refresh(order)
    return order
