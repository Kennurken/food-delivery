from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy import select

from app.api.deps import DB, CurrentUser
from app.core.config import settings
from app.core.ratelimit import limiter
from app.core.security import (
    create_access_token,
    create_refresh_token,
    hash_password,
    parse_subject_id,
    verify_password,
)
from app.models import User
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
