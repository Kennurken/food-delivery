import logging
from hashlib import sha256

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.access import has_permission, require_restaurant
from app.core.billing import (
    CashProvider,
    UnconfiguredProvider,
    card_connected,
    create_checkout_session,
    refund_session,
    session_is_paid,
)
from app.core.events import hub
from app.core.features import INACTIVE_BILLING, entitlements
from app.core.geo import resolve_point, valid_coord
from app.core.push import fanout as push_fanout
from app.core.qr import parse_table_token
from app.models import MenuItem, Order, OrderItem, OrderStatus, Restaurant, User, UserRole
from app.models.floor_plan import FloorObject
from app.models.idempotency import IdempotencyRecord
from app.models.member import RestaurantMember
from app.schemas.order import OrderCreate, OrderOut
from app.services import delivery_pricing
from app.services import promo as promo_service
from app.services.schedule import due_for_courier, parse_slot

log = logging.getLogger(__name__)

# Statuses a courier can pick up from
COURIER_PICKABLE = {OrderStatus.confirmed, OrderStatus.preparing}
DELIVERY_CHANNEL = "delivery"


def _is_delivery(order: Order) -> bool:
    return (order.channel or DELIVERY_CHANNEL) == DELIVERY_CHANNEL


def audience(db: Session, order: Order, *, pool: bool = False) -> set[int]:
    """Who may see this ticket. `pool` adds every courier for grab-order banners."""
    admins = set(db.scalars(select(User.id).where(User.role == UserRole.admin)))
    staff = {
        m.user_id
        for m in db.scalars(
            select(RestaurantMember).where(
                RestaurantMember.restaurant_id == order.restaurant_id,
                RestaurantMember.is_active.is_(True),
            )
        )
        if has_permission(m.role, "orders.read")
    }
    targets = admins | staff | {order.user_id}
    if order.courier_id:
        targets.add(order.courier_id)
    elif (
        pool
        and _is_delivery(order)
        and order.status in COURIER_PICKABLE
        and due_for_courier(order.scheduled_for)
    ):
        targets.update(db.scalars(select(User.id).where(User.role == UserRole.courier)))
    return targets


def get_visible_order(db: Session, user: User, order_id: int) -> Order:
    """Same people as GET /orders/{id}. Unknown tickets look like 404."""
    order = db.get(Order, order_id)
    if not order:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Order not found")
    if user.role == UserRole.admin or order.user_id == user.id or order.courier_id == user.id:
        return order
    try:
        require_restaurant(db, user, order.restaurant_id, "orders.read")
    except HTTPException as exc:
        if exc.status_code == status.HTTP_404_NOT_FOUND:
            raise
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Order not found") from exc
    return order


def notify(db: Session, order: Order, *, cause: str = "status") -> None:
    """Push the order snapshot to whoever is watching it.

    Customer, restaurant staff with orders.read, platform admins, assigned
    courier. Unassigned delivery tickets also go to every courier so the
    available-pool banner still fires. Pickup / table never hit that pool.
    """
    targets = audience(db, order, pool=True)
    payload = {
        "type": "order.updated",
        "cause": cause,
        "order": OrderOut.model_validate(order).model_dump(mode="json"),
    }
    hub.publish_threadsafe(targets, payload)
    if cause != "location":
        push_fanout(
            db,
            targets,
            title=f"Order #{order.id}",
            body=f"{order.restaurant_name} · {order.status.value.replace('_', ' ')}",
            data={"order_id": str(order.id), "status": order.status.value},
        )


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
    return new_status in _TRANSITIONS[order.status]


def price_line(item: MenuItem, option_ids: list[int] | None) -> tuple[float, list[dict]]:
    """Unit price + snapshot. Empty option_ids pick each group's defaults."""
    wanted = list(option_ids or [])
    by_id = {o.id: o for g in item.modifier_groups for o in g.options}
    if not wanted:
        wanted = [
            o.id for g in item.modifier_groups for o in g.options if o.is_default and o.is_available
        ]
    unknown = set(wanted) - set(by_id)
    if unknown:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Unknown modifier")
    snaps: list[dict] = []
    for group in item.modifier_groups:
        picked = [o for o in group.options if o.id in wanted]
        if any(not o.is_available for o in picked):
            raise HTTPException(status.HTTP_400_BAD_REQUEST, f"{group.name}: option unavailable")
        n = len(picked)
        need = group.min_select if not group.required else max(group.min_select, 1)
        if n < need:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, f"Pick {group.name}")
        if n > group.max_select:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, f"Too many options on {group.name}")
        for opt in picked:
            snaps.append(
                {
                    "group_id": group.id,
                    "group": group.name,
                    "option_id": opt.id,
                    "name": opt.name,
                    "price": opt.price_delta,
                }
            )
    unit = item.price + sum(s["price"] for s in snaps)
    return round(unit, 2), snaps


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
    db: Session,
    user: User,
    data: OrderCreate,
    *,
    idempotency_key: str | None = None,
    origin: str | None = None,
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
    elif data.channel == "pickup":
        if not flags.enabled("pickup.enabled"):
            raise HTTPException(status.HTTP_403_FORBIDDEN, "Pickup is not on this plan")
        channel = "pickup"
        address = f"Pickup · {restaurant.name}"
        delivery_fee = 0
    else:
        if not flags.enabled("delivery.enabled"):
            raise HTTPException(status.HTTP_403_FORBIDDEN, "Delivery is not on this plan")

    slot = parse_slot(data.scheduled_for)
    if slot is not None and channel == "qr_table":
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Table orders are now, not later")

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
        unit, snaps = price_line(m, line.option_ids)
        subtotal += unit * line.quantity
        items.append(
            OrderItem(
                menu_item_id=m.id,
                name=m.name,
                price=unit,
                quantity=line.quantity,
                modifiers=snaps,
            )
        )

    discount = 0.0
    promo_code = None
    applied = None
    raw_code = (data.promo_code or "").strip()
    if raw_code:
        applied, discount = promo_service.quote(db, restaurant, raw_code, subtotal)
        promo_code = applied.code
        applied.used_count += 1

    pay_method = data.pay_method or "cash"
    if pay_method == "online" and not flags.enabled("payments.online"):
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Online payments are not on this plan")
    if pay_method == "online" and not card_connected():
        UnconfiguredProvider().charge(
            amount=0,
            currency="KZT",
            idempotency_key="unconfigured",
            description="",
        )

    pickup_lat, pickup_lng = restaurant.lat, restaurant.lng
    dest_lat, dest_lng = pickup_lat, pickup_lng
    if channel == DELIVERY_CHANNEL:
        dest_lat, dest_lng = data.dest_lat, data.dest_lng
        if not valid_coord(dest_lat, dest_lng) and address:
            hit = resolve_point(address, lat=pickup_lat, lng=pickup_lng)
            if hit:
                dest_lat, dest_lng = hit.lat, hit.lng
        # The server prices the ride; the cart only ever quotes it.
        priced = delivery_pricing.quote(restaurant, dest_lat, dest_lng)
        if priced.out_of_range:
            raise HTTPException(
                status.HTTP_400_BAD_REQUEST,
                f"This address is {priced.distance_km} km out; "
                f"{restaurant.name} delivers up to {priced.max_km} km.",
            )
        delivery_fee = priced.fee

    total = round(max(subtotal + delivery_fee - discount, 0), 2)
    pay_status = "unpaid"
    if pay_method == "cash":
        pay_status = CashProvider().charge(
            amount=total,
            currency="KZT",
            idempotency_key=idempotency_key or f"order:{user.id}:{restaurant.id}",
            description=f"{restaurant.name} · {len(items)} items",
        ).status

    order = Order(
        user_id=user.id,
        restaurant_id=restaurant.id,
        address=address,
        comment=data.comment,
        subtotal=round(subtotal, 2),
        delivery_fee=delivery_fee,
        total=total,
        items=items,
        channel=channel,
        table_object_id=table_object_id,
        dest_lat=dest_lat,
        dest_lng=dest_lng,
        pickup_lat=pickup_lat,
        pickup_lng=pickup_lng,
        pay_method="cash" if pay_method == "cash" else "online",
        pay_status=pay_status,
        scheduled_for=slot,
        promo_code=promo_code,
        discount=round(discount, 2),
    )
    db.add(order)
    db.flush()
    try:
        if pay_method == "online":
            paid = create_checkout_session(
                amount=total,
                currency="KZT",
                description=f"{restaurant.name} · {len(items)} items",
                order_id=order.id,
                origin=origin,
                idempotency_key=idempotency_key or f"order:{order.id}:checkout",
                customer_email=user.email,
            )
            order.pay_status = paid.status
            order.pay_ref = paid.reference
            order.checkout_url = paid.url
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
    except HTTPException:
        db.rollback()
        raise
    db.refresh(order)
    if order.pay_status != "pending":
        notify(db, order)
    return order


def mark_paid(db: Session, order: Order) -> Order:
    if order.pay_status == "paid":
        return order
    waiting = order.pay_status == "pending"
    order.pay_status = "paid"
    db.commit()
    db.refresh(order)
    if waiting:
        notify(db, order)
    return order


def sync_payment(db: Session, order: Order) -> Order:
    if order.pay_method != "online" or order.pay_status == "paid":
        return order
    if order.pay_ref and session_is_paid(order.pay_ref):
        return mark_paid(db, order)
    return order


def apply_stripe_event(db: Session, event: dict) -> Order | None:
    from app.core.billing import order_id_from_event

    oid = order_id_from_event(event)
    if oid is None:
        return None
    order = db.get(Order, oid)
    if order is None or order.pay_method != "online":
        return None
    return mark_paid(db, order)


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
    if not due_for_courier(locked.scheduled_for):
        raise HTTPException(status.HTTP_409_CONFLICT, "Order is scheduled later")
    locked.courier_id = courier.id
    db.commit()
    db.refresh(locked)
    notify(db, locked)
    return locked


def advance_order(db: Session, courier: User, order: Order) -> Order:
    """Courier moves own order one step: preparing -> on_the_way -> delivered.

    A courier may accept a ticket that is still `confirmed`, but only the kitchen
    says when cooking started. Advancing from `confirmed` is the kitchen's call.
    """
    if order.courier_id != courier.id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Not your order")
    next_status = {
        OrderStatus.preparing: OrderStatus.on_the_way,
        OrderStatus.on_the_way: OrderStatus.delivered,
    }.get(order.status)
    if next_status is None:
        if order.status == OrderStatus.confirmed:
            raise HTTPException(
                status.HTTP_409_CONFLICT, "Waiting for the kitchen to start this order"
            )
        raise HTTPException(status.HTTP_409_CONFLICT, f"Cannot advance from {order.status.value}")
    return update_status(db, order, next_status)


def refund_if_paid(db: Session, order: Order) -> Order:
    """Send the money back when a paid card ticket is cancelled.

    Cash never moved, so there is nothing to return. A failed refund still lets
    the cancel through and leaves pay_status 'paid' — a human has to settle it
    rather than the ticket silently claiming it was refunded.
    """
    if order.pay_method != "online" or order.pay_status != "paid":
        return order
    ref = refund_session(order.pay_ref or "")
    if ref is None:
        log.error("order %s cancelled but refund failed; settle by hand", order.id)
        return order
    order.pay_status = "refunded"
    return order


def update_status(db: Session, order: Order, new_status: OrderStatus) -> Order:
    if not _allowed(order, new_status):
        raise HTTPException(
            status.HTTP_409_CONFLICT, f"Cannot move from {order.status.value} to {new_status.value}"
        )
    order.status = new_status
    if new_status == OrderStatus.cancelled:
        refund_if_paid(db, order)
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
