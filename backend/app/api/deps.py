from typing import Annotated

from fastapi import Depends, Header, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session

from app.core.sessions import user_for_token
from app.db.session import get_db
from app.models import User, UserRole

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")

DB = Annotated[Session, Depends(get_db)]


def get_current_user(db: DB, token: Annotated[str, Depends(oauth2_scheme)]) -> User:
    user = user_for_token(db, token)
    if not user:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid token")
    return user


CurrentUser = Annotated[User, Depends(get_current_user)]


def get_optional_user(db: DB, authorization: Annotated[str | None, Header()] = None) -> User | None:
    """Who is asking, if they said — for public reads that answer differently to
    someone signed in (is this code good for *me*?). A missing or bad token is
    simply no one, never an error: the endpoint stays public."""
    if not authorization or not authorization.lower().startswith("bearer "):
        return None
    return user_for_token(db, authorization[7:].strip())


OptionalUser = Annotated[User | None, Depends(get_optional_user)]


def require_admin(user: CurrentUser) -> User:
    if user.role != UserRole.admin:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Admin only")
    return user


AdminUser = Annotated[User, Depends(require_admin)]


def require_courier(user: CurrentUser) -> User:
    if user.role not in (UserRole.courier, UserRole.admin):
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Courier only")
    return user


CourierUser = Annotated[User, Depends(require_courier)]
