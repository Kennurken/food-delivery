"""A restaurant applying to join, and the platform letting it in.

An application creates two things at once — the owner's account and a venue —
and the venue starts hidden. Until the platform approves it, a guest can't see
it, list it, find it by URL or order from it; only its own staff and the
platform can. That is the whole point of the approval step: the platform talks
to each owner before anyone sees the venue, and a stranger can't fill the
public list with empty or fake ones.
"""

from __future__ import annotations

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core import subscriptions
from app.core.push import fanout as push_fanout
from app.core.security import hash_password
from app.models import City, Restaurant, RestaurantMember, User, UserRole
from app.services import cities
from app.services.schedule import utcnow
from app.services.slugs import unique_slug

PENDING, APPROVED, REJECTED = "pending", "approved", "rejected"


def apply(
    db: Session,
    *,
    venue_name: str,
    cuisine: str,
    contact_name: str,
    email: str,
    phone: str,
    password: str,
    has_couriers: bool,
    city_slug: str | None = None,
    description: str = "",
) -> tuple[User, Restaurant]:
    if db.scalar(select(User).where(User.email == email)):
        # Sign in and add a venue from the panel instead of starting a second account.
        raise HTTPException(status.HTTP_409_CONFLICT, "This email is already registered")
    city: City | None
    if city_slug:
        city = cities.by_slug(db, city_slug)
        if city is None:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "Unknown city")
    else:
        city = cities.default(db)

    owner = User(
        email=email,
        name=contact_name,
        phone=phone,
        role=UserRole.customer,
        hashed_password=hash_password(password),
    )
    db.add(owner)
    db.flush()
    venue = Restaurant(
        name=venue_name,
        description=description,
        cuisine=cuisine,
        city_id=city.id if city else None,
        approval=PENDING,
        offers_delivery=has_couriers,
        applied_at=utcnow(),
        # Closed until it is approved and the owner has a menu: nothing about a
        # new venue should look open to a guest.
        is_open=False,
    )
    db.add(venue)
    db.flush()
    venue.slug = unique_slug(db, Restaurant, venue.name, skip_id=venue.id)
    db.add(RestaurantMember(user_id=owner.id, restaurant_id=venue.id, role="owner"))
    db.commit()
    db.refresh(owner)
    db.refresh(venue)
    # Nobody checks an admin tab for fun: the platform hears about it at once.
    admins = set(db.scalars(select(User.id).where(User.role == UserRole.admin)))
    push_fanout(
        db,
        admins,
        key="application.new",
        params={
            "venue": venue.name,
            "cuisine": venue.cuisine,
            "contact": contact_name,
            "phone": phone,
        },
        data={"cause": "application", "restaurant_id": str(venue.id)},
    )
    return owner, venue


def decide(db: Session, venue: Restaurant, *, approve: bool, reason: str | None = None) -> Restaurant:
    if venue.approval != PENDING:
        raise HTTPException(status.HTTP_409_CONFLICT, f"Already {venue.approval}")
    if approve:
        venue.approval = APPROVED
        venue.rejection_reason = None
        # Open on approval: the owner already built the menu while it was hidden.
        venue.is_open = True
        subscriptions.start_trial(venue)
    else:
        venue.approval = REJECTED
        venue.rejection_reason = (reason or "").strip()[:300] or None
    db.commit()
    db.refresh(venue)
    owner = owner_of(db, venue)
    if owner is not None:
        push_fanout(
            db,
            {owner.id},
            key="application.approved" if approve else "application.declined",
            params={"venue": venue.name, "reason": venue.rejection_reason},
            data={"cause": "approval", "restaurant_id": str(venue.id)},
        )
    return venue


def pending(db: Session) -> list[Restaurant]:
    return list(
        db.scalars(
            select(Restaurant)
            .where(Restaurant.approval == PENDING)
            .order_by(Restaurant.applied_at, Restaurant.id)
        )
    )


def owner_of(db: Session, venue: Restaurant) -> User | None:
    return db.scalar(
        select(User)
        .join(RestaurantMember, RestaurantMember.user_id == User.id)
        .where(RestaurantMember.restaurant_id == venue.id, RestaurantMember.role == "owner")
        .order_by(RestaurantMember.id)
    )


def visible_to(db: Session, venue: Restaurant, user: User | None) -> bool:
    """Can this person see the venue at all? Anyone can see an approved one; a
    pending or rejected one only its own staff and the platform."""
    if venue.approval == APPROVED:
        return True
    if user is None:
        return False
    if user.role == UserRole.admin:
        return True
    return (
        db.scalar(
            select(RestaurantMember.id).where(
                RestaurantMember.user_id == user.id,
                RestaurantMember.restaurant_id == venue.id,
                RestaurantMember.is_active.is_(True),
            )
        )
        is not None
    )


__all__ = ["APPROVED", "PENDING", "REJECTED", "apply", "decide", "owner_of", "pending", "visible_to"]
