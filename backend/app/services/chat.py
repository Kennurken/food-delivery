"""Order thread. Same people who can GET the ticket. Closed when the ticket is final."""

from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.events import hub
from app.core.push import fanout as push_fanout
from app.models import Order, OrderStatus, User
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
