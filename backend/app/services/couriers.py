"""Whose orders a courier may take.

A restaurant hires its own couriers by adding them as `delivery_courier` staff.
Such a courier sees and takes orders of the venues that hired them and nobody
else's. A courier with no such membership is on the platform's shared pool —
the marketplace behaviour every existing courier has — and keeps seeing every
delivery, so nothing changes for them.
"""

from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import Order, RestaurantMember, User, UserRole

COURIER_ROLE = "delivery_courier"


def scoped_venues(db: Session, courier: User) -> list[int] | None:
    """The venues that employ this courier, or None for the shared pool."""
    rows = list(
        db.scalars(
            select(RestaurantMember.restaurant_id).where(
                RestaurantMember.user_id == courier.id,
                RestaurantMember.role == COURIER_ROLE,
                RestaurantMember.is_active.is_(True),
            )
        )
    )
    return rows or None


def may_take(db: Session, courier: User, order: Order) -> bool:
    if courier.role == UserRole.admin:
        return True
    venues = scoped_venues(db, courier)
    return venues is None or order.restaurant_id in venues


def pool_courier_ids(db: Session) -> set[int]:
    """Couriers not tied to any venue: the ones who hear about every delivery."""
    employed = select(RestaurantMember.user_id).where(
        RestaurantMember.role == COURIER_ROLE, RestaurantMember.is_active.is_(True)
    )
    return set(
        db.scalars(
            select(User.id).where(User.role == UserRole.courier, User.id.not_in(employed))
        )
    )


def hire(person: User) -> None:
    """Being someone's courier needs the courier role. A guest who is hired gets
    it; a platform admin or an existing courier is left as they are."""
    if person.role == UserRole.customer:
        person.role = UserRole.courier


def release(db: Session, person: User) -> None:
    """A courier let go by their last venue goes back to being a guest, not to
    the shared pool — otherwise being fired would widen what they can see."""
    if person.role != UserRole.courier or scoped_venues(db, person) is not None:
        return
    person.role = UserRole.customer
    person.on_shift = False
