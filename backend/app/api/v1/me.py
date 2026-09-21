from fastapi import APIRouter, HTTPException, status

from app.api.deps import DB, CurrentUser
from app.models import Address, User
from app.schemas.address import AddressCreate, AddressOut
from app.schemas.user import UserOut, UserUpdate

router = APIRouter(prefix="/me", tags=["me"])


@router.patch("", response_model=UserOut)
def update_profile(data: UserUpdate, db: DB, user: CurrentUser) -> User:
    for k, v in data.model_dump(exclude_unset=True).items():
        setattr(user, k, v)
    db.commit()
    db.refresh(user)
    return user


@router.get("/addresses", response_model=list[AddressOut])
def list_addresses(user: CurrentUser) -> list[Address]:
    return user.addresses


@router.post("/addresses", response_model=AddressOut, status_code=status.HTTP_201_CREATED)
def add_address(data: AddressCreate, db: DB, user: CurrentUser) -> Address:
    make_default = data.is_default or not user.addresses
    if make_default:
        for a in user.addresses:
            a.is_default = False
    addr = Address(user_id=user.id, label=data.label, line=data.line, is_default=make_default)
    db.add(addr)
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
