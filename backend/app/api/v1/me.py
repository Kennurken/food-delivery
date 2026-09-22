from fastapi import APIRouter, HTTPException, Request, status

from app.api.deps import DB, CurrentUser
from app.core.config import settings
from app.core.ratelimit import limiter
from app.core.security import hash_password, verify_password
from app.models import Address, User
from app.schemas.address import AddressCreate, AddressOut, AddressUpdate
from app.schemas.user import PasswordChange, UserOut, UserUpdate

router = APIRouter(prefix="/me", tags=["me"])


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
