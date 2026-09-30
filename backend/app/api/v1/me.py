from fastapi import APIRouter, HTTPException, Query, Request, status
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError

from app.api.deps import DB, CourierUser, CurrentUser
from app.core.config import settings
from app.core.push import drop_token, register_token
from app.core.ratelimit import limiter
from app.core.security import hash_password, verify_password
from app.models import Address, Favorite, Order, OrderStatus, Restaurant, User
from app.models.member import RestaurantMember
from app.schemas.address import AddressCreate, AddressOut, AddressUpdate
from app.schemas.restaurant import RestaurantOut
from app.schemas.user import DeviceIn, PasswordChange, UserOut, UserUpdate
from app.services import accounts, courier_earnings
from app.services.restaurant_view import to_out

router = APIRouter(prefix="/me", tags=["me"])


class DeleteAccountIn(BaseModel):
    password: str | None = None


@router.delete("", status_code=status.HTTP_204_NO_CONTENT)
@limiter.limit(lambda: settings.login_rate_limit)
def delete_account(request: Request, data: DeleteAccountIn, db: DB, user: CurrentUser) -> None:
    """Close the account. Orders stay with the restaurants, without the person."""
    accounts.delete_account(db, user, data.password)


@router.patch("", response_model=UserOut)
def update_profile(data: UserUpdate, db: DB, user: CurrentUser) -> User:
    for k, v in data.model_dump(exclude_unset=True).items():
        setattr(user, k, v)
    db.commit()
    db.refresh(user)
    return user


@router.post("/password", status_code=status.HTTP_204_NO_CONTENT)
@limiter.limit(lambda: settings.login_rate_limit)
def change_password(request: Request, data: PasswordChange, db: DB, user: CurrentUser) -> None:
    if user.is_guest:
        raise HTTPException(status.HTTP_409_CONFLICT, "A table session has no password")
    if not verify_password(data.current_password, user.hashed_password):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Invalid credentials")
    if data.current_password == data.new_password:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "New password must be different")
    user.hashed_password = hash_password(data.new_password)
    db.commit()


@router.get("/addresses", response_model=list[AddressOut])
def list_addresses(user: CurrentUser) -> list[Address]:
    return user.addresses


@router.post("/addresses", response_model=AddressOut, status_code=status.HTTP_201_CREATED)
def add_address(data: AddressCreate, db: DB, user: CurrentUser) -> Address:
    make_default = data.is_default or not user.addresses
    if make_default:
        for a in user.addresses:
            a.is_default = False
    addr = Address(
        user_id=user.id,
        label=data.label,
        line=data.line,
        apt=data.apt,
        entrance=data.entrance,
        floor=data.floor,
        intercom=data.intercom,
        is_default=make_default,
        lat=data.lat,
        lng=data.lng,
    )
    db.add(addr)
    db.commit()
    db.refresh(addr)
    return addr


@router.patch("/addresses/{address_id}", response_model=AddressOut)
def update_address(address_id: int, data: AddressUpdate, db: DB, user: CurrentUser) -> Address:
    addr = next((a for a in user.addresses if a.id == address_id), None)
    if not addr:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Address not found")
    updates = data.model_dump(exclude_unset=True)
    if updates.get("is_default"):
        for a in user.addresses:
            a.is_default = False
        addr.is_default = True
    for k, v in updates.items():
        if k != "is_default":
            setattr(addr, k, v)
    db.commit()
    db.refresh(addr)
    return addr


@router.delete("/addresses/{address_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_address(address_id: int, db: DB, user: CurrentUser) -> None:
    addr = next((a for a in user.addresses if a.id == address_id), None)
    if not addr:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Address not found")
    was_default = addr.is_default
    db.delete(addr)
    db.flush()
    if was_default and user.addresses:
        user.addresses[0].is_default = True
    db.commit()


@router.get("/favorites", response_model=list[RestaurantOut])
def list_favorites(db: DB, user: CurrentUser) -> list[RestaurantOut]:
    stmt = (
        select(Restaurant)
        .join(Favorite, Favorite.restaurant_id == Restaurant.id)
        .where(Favorite.user_id == user.id)
        .order_by(Favorite.created_at.desc())
    )
    return [to_out(db, r) for r in db.scalars(stmt)]


@router.put("/favorites/{restaurant_id}", status_code=status.HTTP_204_NO_CONTENT)
def add_favorite(restaurant_id: int, db: DB, user: CurrentUser) -> None:
    if not db.get(Restaurant, restaurant_id):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Restaurant not found")
    if db.get(Favorite, (user.id, restaurant_id)):
        return
    db.add(Favorite(user_id=user.id, restaurant_id=restaurant_id))
    try:
        db.commit()
    except IntegrityError:
        db.rollback()


@router.delete("/favorites/{restaurant_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_favorite(restaurant_id: int, db: DB, user: CurrentUser) -> None:
    fav = db.get(Favorite, (user.id, restaurant_id))
    if not fav:
        return
    db.delete(fav)
    db.commit()


@router.get("/memberships")
def list_memberships(db: DB, user: CurrentUser) -> list[dict]:
    rows = db.scalars(select(RestaurantMember).where(RestaurantMember.user_id == user.id))
    out = []
    for m in rows:
        r = db.get(Restaurant, m.restaurant_id)
        if not r:
            continue
        out.append({"restaurant_id": r.id, "name": r.name, "role": m.role, "is_active": m.is_active})
    return out


@router.put("/devices", status_code=status.HTTP_204_NO_CONTENT)
def save_device(data: DeviceIn, db: DB, user: CurrentUser) -> None:
    register_token(db, user.id, data.token, data.platform)


@router.delete("/devices", status_code=status.HTTP_204_NO_CONTENT)
def forget_device(
    db: DB, user: CurrentUser, token: str = Query(min_length=8, max_length=512)
) -> None:
    drop_token(db, user.id, token)


@router.get("/earnings")
def earnings(db: DB, courier: CourierUser, days: int = Query(7, ge=1, le=90)) -> dict:
    """What this courier earned, and what cash they still owe the platform."""
    data = courier_earnings.summary(db, courier, days=days)
    return {
        "days": data.days,
        "deliveries": data.deliveries,
        "earned": data.earned,
        "cash_held": data.cash_held,
        "earned_all_time": data.earned_all_time,
        "deliveries_all_time": data.deliveries_all_time,
        "rating": data.rating,
        "rated": data.rated,
        "by_day": [
            {"day": row.day, "deliveries": row.deliveries, "earned": row.earned}
            for row in data.by_day
        ],
    }


@router.get("/earnings/history")
def earnings_history(
    db: DB,
    courier: CourierUser,
    limit: int = Query(20, ge=1, le=50),
    before: int | None = Query(None, ge=1),
) -> dict:
    """Delivery by delivery, newest first — so a courier can find the one they
    think is missing from their pay. Page on with `before=<next_before>`."""
    items, next_before = courier_earnings.history(db, courier, limit=limit, before=before)
    return {
        "items": [
            {
                "order_id": row.order_id,
                "restaurant_name": row.restaurant_name,
                "at": row.at.isoformat(),
                "payout": row.payout,
                "pay_method": row.pay_method,
                "cash_held": row.cash_held,
            }
            for row in items
        ],
        "next_before": next_before,
    }


class ShiftIn(BaseModel):
    on: bool


@router.get("/shift")
def shift(courier: CourierUser) -> dict:
    return {"on_shift": courier.on_shift}


@router.post("/shift")
def set_shift(data: ShiftIn, db: DB, courier: CourierUser) -> dict:
    """Go on or off the line.

    Off the line a courier sees no new orders and can't take one. They can't go
    off while carrying one: an order with nobody answering for it is worse than
    a courier who ends their day a little late.
    """
    if not data.on:
        carrying = db.scalar(
            select(func.count(Order.id)).where(
                Order.courier_id == courier.id,
                Order.status.in_(
                    (OrderStatus.confirmed, OrderStatus.preparing, OrderStatus.on_the_way)
                ),
            )
        )
        if carrying:
            raise HTTPException(
                status.HTTP_409_CONFLICT, "Finish your current orders before going off the line"
            )
    courier.on_shift = data.on
    db.commit()
    return {"on_shift": courier.on_shift}
