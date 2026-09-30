"""Order thread. Same people who can GET the ticket. Closed when the ticket is final."""

from datetime import timedelta

from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.access import has_permission
from app.core.events import hub
from app.core.push import fanout as push_fanout
from app.models import Order, OrderStatus, RestaurantMember, User, UserRole
from app.models.message import OrderMessage
from app.schemas.chat import ChatMessageOut
from app.services.order_service import audience, get_visible_order
from app.services.schedule import utcnow

MAX_THREAD = 200
_CLOSED = {OrderStatus.delivered, OrderStatus.cancelled}


def list_messages(db: Session, user: User, order_id: int) -> list[OrderMessage]:
    get_visible_order(db, user, order_id)
    return list(
        db.scalars(
            select(OrderMessage)
            .where(OrderMessage.order_id == order_id)
            .order_by(OrderMessage.id)
            .limit(MAX_THREAD)
        )
    )


def post_message(db: Session, user: User, order_id: int, body: str) -> OrderMessage:
    order = get_visible_order(db, user, order_id)
    if order.status in _CLOSED:
        raise HTTPException(status.HTTP_409_CONFLICT, "Chat is closed")
    count = db.scalar(
        select(func.count()).select_from(OrderMessage).where(OrderMessage.order_id == order_id)
    )
    if (count or 0) >= MAX_THREAD:
        raise HTTPException(status.HTTP_409_CONFLICT, "Chat is full")
    row = OrderMessage(
        order_id=order.id,
        user_id=user.id,
        sender_name=user.name,
        body=body,
        created_at=utcnow(),
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    _publish(db, order, row, sender_id=user.id)
    return row


def _publish(db: Session, order: Order, row: OrderMessage, *, sender_id: int) -> None:
    targets = audience(db, order, pool=False)
    payload = {
        "type": "order.chat",
        "order_id": order.id,
        "restaurant_id": order.restaurant_id,
        "message": ChatMessageOut.model_validate(row).model_dump(mode="json"),
    }
    hub.publish_threadsafe(targets, payload)
    others = targets - {sender_id}
    preview = row.body if len(row.body) <= 80 else f"{row.body[:77]}…"
    push_fanout(
        db,
        others,
        title=f"Order #{order.id}",
        body=f"{row.sender_name}: {preview}",
        data={"order_id": str(order.id), "cause": "chat"},
    )


# Who a member of staff can hand a conversation up to.
MANAGER_ROLES = ("owner", "admin", "manager")
ESCALATION_COOLDOWN = timedelta(minutes=10)


def escalate(db: Session, user: User, order_id: int) -> OrderMessage:
    """A member of staff calls the venue's manager into a conversation.

    Only staff of that venue can (the customer has nobody above them to call, a
    courier is not the kitchen), and not a manager themselves. It is one line in
    the thread plus a push to the managers, and at most once every ten minutes,
    so it cannot be used to spam the owner's phone.
    """
    order = get_visible_order(db, user, order_id)
    if order.status in _CLOSED:
        raise HTTPException(status.HTTP_409_CONFLICT, "Chat is closed")
    membership = db.scalar(
        select(RestaurantMember).where(
            RestaurantMember.user_id == user.id,
            RestaurantMember.restaurant_id == order.restaurant_id,
            RestaurantMember.is_active.is_(True),
        )
    )
    if membership is None or not has_permission(membership.role, "orders.read"):
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Only the venue's staff can call a manager")
    if membership.role in MANAGER_ROLES:
        raise HTTPException(status.HTTP_409_CONFLICT, "You are the manager")
    recent = db.scalar(
        select(OrderMessage.id).where(
            OrderMessage.order_id == order.id,
            OrderMessage.kind == "escalation",
            OrderMessage.created_at >= utcnow() - ESCALATION_COOLDOWN,
        )
    )
    if recent is not None:
        raise HTTPException(status.HTTP_409_CONFLICT, "The manager was already called")

    managers = set(
        db.scalars(
            select(RestaurantMember.user_id).where(
                RestaurantMember.restaurant_id == order.restaurant_id,
                RestaurantMember.role.in_(MANAGER_ROLES),
                RestaurantMember.is_active.is_(True),
            )
        )
    ) or set(db.scalars(select(User.id).where(User.role == UserRole.admin)))
    managers.discard(user.id)

    row = OrderMessage(
        order_id=order.id,
        user_id=user.id,
        sender_name=user.name,
        body="escalated",
        kind="escalation",
        created_at=utcnow(),
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    _publish(db, order, row, sender_id=user.id)
    push_fanout(
        db,
        managers,
        title=f"Order #{order.id}: manager needed",
        body=f"{user.name} asks you to join the chat",
        data={"order_id": str(order.id), "cause": "escalation"},
    )
    return row
