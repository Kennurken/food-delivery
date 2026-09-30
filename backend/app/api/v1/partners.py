"""Restaurants applying to join, and the platform's review of them."""

from fastapi import APIRouter, HTTPException, Request, status
from pydantic import BaseModel, EmailStr, Field

from app.api.deps import DB, AdminUser
from app.api.v1.auth import _issue
from app.core import audit
from app.core.config import settings
from app.core.ratelimit import limiter
from app.schemas.user import Token
from app.services import partners

router = APIRouter(tags=["partners"])


class Application(BaseModel):
    venue_name: str = Field(min_length=2, max_length=150)
    cuisine: str = Field(min_length=2, max_length=50)
    contact_name: str = Field(min_length=2, max_length=100)
    email: EmailStr
    phone: str = Field(min_length=6, max_length=30)
    password: str = Field(min_length=8, max_length=128)
    # The question every venue is asked: does it have its own couriers?
    has_couriers: bool
    city_slug: str | None = Field(default=None, max_length=40)
    description: str = Field(default="", max_length=500)


class ApplicationResult(Token):
    restaurant_id: int
    approval: str


class Decision(BaseModel):
    approve: bool
    reason: str | None = Field(default=None, max_length=300)


@router.post(
    "/partners/apply", response_model=ApplicationResult, status_code=status.HTTP_201_CREATED
)
@limiter.limit(lambda: settings.login_rate_limit)
def apply(request: Request, data: Application, db: DB) -> ApplicationResult:
    """Public. Creates the owner's account and a hidden venue, and signs the
    owner in — they can build their menu right away while they wait."""
    owner, venue = partners.apply(db, **data.model_dump())
    audit.record(
        db,
        actor_id=owner.id,
        restaurant_id=venue.id,
        action="partner.apply",
        resource=f"restaurant:{venue.id}",
        request_id=getattr(request.state, "request_id", None),
    )
    db.commit()
    token = _issue(owner)
    return ApplicationResult(**token.model_dump(), restaurant_id=venue.id, approval=venue.approval)


@router.get("/admin/applications")
def applications(db: DB, _: AdminUser) -> list[dict]:
    """Venues waiting for a decision, oldest first, with who to call."""
    rows = []
    for venue in partners.pending(db):
        owner = partners.owner_of(db, venue)
        rows.append(
            {
                "restaurant_id": venue.id,
                "name": venue.name,
                "cuisine": venue.cuisine,
                "description": venue.description,
                "city": venue.city.name if venue.city else None,
                "has_couriers": venue.offers_delivery,
                "applied_at": venue.applied_at.isoformat() if venue.applied_at else None,
                "owner_name": owner.name if owner else None,
                "owner_email": owner.email if owner else None,
                "owner_phone": owner.phone if owner else None,
            }
        )
    return rows


@router.post("/admin/restaurants/{restaurant_id}/approval")
def decide(
    restaurant_id: int, body: Decision, db: DB, admin: AdminUser, request: Request
) -> dict:
    from app.models import Restaurant

    venue = db.get(Restaurant, restaurant_id)
    if venue is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Restaurant not found")
    partners.decide(db, venue, approve=body.approve, reason=body.reason)
    audit.record(
        db,
        actor_id=admin.id,
        restaurant_id=venue.id,
        action="partner.approve" if body.approve else "partner.reject",
        resource=f"restaurant:{venue.id}",
        payload={"reason": body.reason} if body.reason else None,
        request_id=getattr(request.state, "request_id", None),
    )
    db.commit()
    return {"restaurant_id": venue.id, "approval": venue.approval}
