"""Written reviews: read by anyone, answered by the venue, removable by the platform."""

from fastapi import APIRouter, HTTPException, Query, Request, status

from app.api.deps import DB, AdminUser, CurrentUser
from app.core import audit
from app.core.access import require_restaurant
from app.models import Order, Restaurant
from app.schemas.order import ReviewReply
from app.services.reviews import public_row, recent

router = APIRouter(tags=["reviews"])


@router.get("/restaurants/{restaurant_id}/reviews")
def list_reviews(
    restaurant_id: int,
    db: DB,
    limit: int = Query(20, ge=1, le=50),
    before: int | None = Query(None, ge=1),
) -> dict:
    """Newest first; page on with `before=<next_before>`."""
    if db.get(Restaurant, restaurant_id) is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Restaurant not found")
    rows = recent(db, restaurant_id, limit=limit + 1, before=before)
    more = len(rows) > limit
    rows = rows[:limit]
    return {
        "items": [public_row(o) for o in rows],
        "next_before": rows[-1].id if more and rows else None,
    }


@router.post("/admin/orders/{order_id}/review-reply")
def reply(order_id: int, body: ReviewReply, db: DB, user: CurrentUser, request: Request) -> dict:
    """The venue answers a review, once visibly and replaceable."""
    order = db.get(Order, order_id)
    if order is None or order.review is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Review not found")
    require_restaurant(db, user, order.restaurant_id, "orders.manage")
    order.review_reply = body.text.strip()
    audit.record(
        db,
        actor_id=user.id,
        restaurant_id=order.restaurant_id,
        action="review.reply",
        resource=f"order:{order.id}",
        request_id=getattr(request.state, "request_id", None),
    )
    db.commit()
    return public_row(order)


@router.delete("/admin/orders/{order_id}/review", status_code=status.HTTP_204_NO_CONTENT)
def remove(order_id: int, db: DB, admin: AdminUser, request: Request) -> None:
    """Take a review's text and the venue's answer off the public page.

    The star rating stays: it is already in the venue's average, and removing
    text is moderation, not editing the score. Platform admin only — a venue
    deleting its own bad reviews is not moderation.
    """
    order = db.get(Order, order_id)
    if order is None or order.review is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Review not found")
    order.review = None
    order.review_reply = None
    audit.record(
        db,
        actor_id=admin.id,
        restaurant_id=order.restaurant_id,
        action="review.remove",
        resource=f"order:{order.id}",
        request_id=getattr(request.state, "request_id", None),
    )
    db.commit()
