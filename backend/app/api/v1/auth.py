import secrets
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.security import OAuth2PasswordRequestForm
from pydantic import BaseModel, Field
from sqlalchemy import select

from app.api.deps import DB, CurrentUser
from app.core.config import settings
from app.core.qr import parse_table_token
from app.core.ratelimit import limiter
from app.core.security import (
    create_access_token,
    create_refresh_token,
    hash_password,
    parse_subject_id,
    verify_password,
)
from app.models import User
from app.models.floor_plan import FloorObject
from app.schemas.user import AccessToken, RefreshRequest, Token, UserCreate, UserLogin, UserOut

router = APIRouter(prefix="/auth", tags=["auth"])


def _issue(user: User) -> Token:
    sub = str(user.id)
    return Token(
        access_token=create_access_token(sub),
        refresh_token=create_refresh_token(sub),
        user=UserOut.model_validate(user),
    )


def _authenticate(db, email: str, password: str) -> User:
    user = db.scalar(select(User).where(User.email == email))
    if not user or not verify_password(password, user.hashed_password):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid credentials")
    return user


@router.post("/register", response_model=Token, status_code=status.HTTP_201_CREATED)
@limiter.limit(lambda: settings.login_rate_limit)
def register(request: Request, data: UserCreate, db: DB) -> Token:
    if db.scalar(select(User).where(User.email == data.email)):
        raise HTTPException(status.HTTP_409_CONFLICT, "Email already registered")
    user = User(
        email=data.email,
        name=data.name,
        phone=data.phone,
        hashed_password=hash_password(data.password),
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return _issue(user)


class GuestIn(BaseModel):
    qr_token: str = Field(min_length=3, max_length=200)


@router.post("/guest", response_model=Token, status_code=status.HTTP_201_CREATED)
@limiter.limit(lambda: settings.login_rate_limit)
def guest(request: Request, data: GuestIn, db: DB) -> Token:
    """A table session for someone who scanned a QR.

    Making a diner register before they can order at a table they are already
    sitting at loses the order. So this hands out a session instead of asking
    for one — but an order still belongs to somebody, because the kitchen board,
    the chat and the order status all need an owner.

    It needs a valid table token, so it cannot be used as an open account
    factory, and it is rate limited like every other credential route.
    """
    parsed = parse_table_token(data.qr_token)
    if parsed is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Unknown QR")
    restaurant_id, object_id = parsed
    table = db.get(FloorObject, object_id)
    if table is None or not table.kind.startswith("table"):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Unknown QR")
    if table.floor.restaurant_id != restaurant_id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Unknown QR")

    # Named after the table: the kitchen reads "Стол T3", not "Guest #4181".
    label = table.name or f"Table {table.id}"
    user = User(
        # No mailbox exists behind this. It is a unique key the column needs,
        # on a domain that can never receive mail.
        email=f"guest.{secrets.token_hex(8)}@qr.invalid",
        name=label,
        # Random and thrown away: there is no password to guess, and no login
        # route that would accept one.
        hashed_password=hash_password(secrets.token_urlsafe(32)),
        is_guest=True,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return _issue(user)


@router.post("/login", response_model=Token)
@limiter.limit(lambda: settings.login_rate_limit)
def login(request: Request, form: Annotated[OAuth2PasswordRequestForm, Depends()], db: DB) -> Token:
    """OAuth2 form login (used by Swagger UI)."""
    return _issue(_authenticate(db, form.username, form.password))


@router.post("/login/json", response_model=Token)
@limiter.limit(lambda: settings.login_rate_limit)
def login_json(request: Request, data: UserLogin, db: DB) -> Token:
    """JSON login (used by the mobile app)."""
    return _issue(_authenticate(db, data.email, data.password))


@router.post("/refresh", response_model=AccessToken)
@limiter.limit(lambda: settings.login_rate_limit)
def refresh(request: Request, data: RefreshRequest, db: DB) -> AccessToken:
    user_id = parse_subject_id(data.refresh_token, expected="refresh")
    user = db.get(User, user_id) if user_id is not None else None
    if not user:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid refresh token")
    return AccessToken(access_token=create_access_token(str(user.id)))


@router.get("/me", response_model=UserOut)
def me(user: CurrentUser) -> User:
    return user
