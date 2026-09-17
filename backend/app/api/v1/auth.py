from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy import select

from app.api.deps import DB, CurrentUser
from app.core.security import create_access_token, hash_password, verify_password
from app.models import User
from app.schemas.user import Token, UserCreate, UserLogin, UserOut

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=Token, status_code=status.HTTP_201_CREATED)
def register(data: UserCreate, db: DB) -> Token:
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
    return Token(access_token=create_access_token(str(user.id)), user=UserOut.model_validate(user))


def _authenticate(db, email: str, password: str) -> User:
    user = db.scalar(select(User).where(User.email == email))
    if not user or not verify_password(password, user.hashed_password):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid credentials")
    return user


@router.post("/login", response_model=Token)
def login(form: Annotated[OAuth2PasswordRequestForm, Depends()], db: DB) -> Token:
    """OAuth2 form login (used by Swagger UI)."""
    user = _authenticate(db, form.username, form.password)
    return Token(access_token=create_access_token(str(user.id)), user=UserOut.model_validate(user))


@router.post("/login/json", response_model=Token)
def login_json(data: UserLogin, db: DB) -> Token:
    """JSON login (used by the mobile app)."""
    user = _authenticate(db, data.email, data.password)
    return Token(access_token=create_access_token(str(user.id)), user=UserOut.model_validate(user))


@router.get("/me", response_model=UserOut)
def me(user: CurrentUser) -> User:
    return user
