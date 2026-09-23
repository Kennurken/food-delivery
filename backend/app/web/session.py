"""Who the site is talking to.

The API authenticates with a bearer token; a server-rendered page cannot hold
one. So the site keeps the same token in an httpOnly cookie: one identity
system, one set of claims, no second notion of a user.

httpOnly matters — page scripts must not be able to read the token, so an
injected script cannot walk off with someone's session.
"""

from __future__ import annotations

from fastapi import Response
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.security import parse_subject_id
from app.models import User

COOKIE = "fd_session"


def remember(response: Response, token: str) -> None:
    response.set_cookie(
        COOKIE,
        token,
        max_age=settings.access_token_expire_minutes * 60,
        httponly=True,
        samesite="lax",
        secure=settings.is_prod,
        path="/",
    )


def forget(response: Response) -> None:
    response.delete_cookie(COOKIE, path="/")


def current_user(db: Session, cookie: str | None) -> User | None:
    """None for a visitor, a User for a signed-in one. An expired or forged
    cookie is simply a visitor — the site stays readable either way."""
    if not cookie:
        return None
    user_id = parse_subject_id(cookie)
    return db.get(User, user_id) if user_id is not None else None
