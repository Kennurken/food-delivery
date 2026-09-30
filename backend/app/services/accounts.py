"""Leaving the service, and getting back in without a mailbox.

Deleting an account anonymises it rather than dropping the row: restaurants
keep their order history (what was sold, when, for how much) because they need
it for their books, but nothing in it points at a person any more. What only
the person used — addresses, favourites, device tokens, their name on chat
lines — goes.

Without an e-mail provider there is no "reset link". The platform resets a
password by hand for someone it has confirmed by phone, and every session the
old password opened is closed.
"""

from __future__ import annotations

import secrets

from fastapi import HTTPException, status
from sqlalchemy import delete, select, update
from sqlalchemy.orm import Session

from app.core.security import hash_password, verify_password
from app.core.sessions import sign_out_everywhere
from app.models import Address, Favorite, Order, OrderStatus, User, UserRole
from app.models.device import DeviceToken
from app.models.member import RestaurantMember
from app.models.message import OrderMessage
from app.models.reservation import Reservation

DELETED_NAME = "Deleted user"
_OPEN = (OrderStatus.pending, OrderStatus.confirmed, OrderStatus.preparing, OrderStatus.on_the_way)


def delete_account(db: Session, user: User, password: str | None) -> None:
    if user.role == UserRole.admin:
        raise HTTPException(
            status.HTTP_409_CONFLICT, "A platform admin account can't be deleted from the app"
        )
    # A QR table session has no password anyone knows; it is still theirs to end.
    if not user.is_guest and not verify_password(password or "", user.hashed_password):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Password is wrong")
    owns = db.scalar(
        select(RestaurantMember.id).where(
            RestaurantMember.user_id == user.id, RestaurantMember.role == "owner"
        )
    )
    if owns is not None:
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            "You own a restaurant. Ask the platform to transfer or close it first.",
        )
    busy = db.scalar(
        select(Order.id).where(
            ((Order.user_id == user.id) | (Order.courier_id == user.id)),
            Order.status.in_(_OPEN),
        )
    )
    if busy is not None:
        raise HTTPException(
            status.HTTP_409_CONFLICT, "You have an order in progress. Try again when it is done."
        )

    db.execute(delete(Address).where(Address.user_id == user.id))
    db.execute(delete(Favorite).where(Favorite.user_id == user.id))
    db.execute(delete(DeviceToken).where(DeviceToken.user_id == user.id))
    db.execute(delete(RestaurantMember).where(RestaurantMember.user_id == user.id))
    db.execute(
        update(OrderMessage).where(OrderMessage.user_id == user.id).values(sender_name=DELETED_NAME)
    )
    db.execute(
        update(Reservation)
        .where(Reservation.user_id == user.id)
        .values(name=DELETED_NAME, phone=None)
    )
    user.email = f"deleted.{user.id}.{secrets.token_hex(4)}@deleted.invalid"
    user.name = DELETED_NAME
    user.phone = None
    user.hashed_password = hash_password(secrets.token_urlsafe(32))
    user.role = UserRole.customer
    user.on_shift = False
    user.last_lat = user.last_lng = user.last_heading = None
    sign_out_everywhere(user)
    db.commit()


def reset_password(db: Session, email: str) -> str:
    """A fresh temporary password for `email`, returned once. Old sessions end."""
    user = db.scalar(select(User).where(User.email == email.strip()))
    if user is None or user.is_guest:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "No such account")
    if user.role == UserRole.admin:
        raise HTTPException(
            status.HTTP_409_CONFLICT, "Platform admins reset their password with scripts/set_admin.py"
        )
    temporary = secrets.token_urlsafe(9)
    user.hashed_password = hash_password(temporary)
    sign_out_everywhere(user)
    db.commit()
    return temporary
