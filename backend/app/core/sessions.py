"""Turning a token into a person, and taking that back.

A JWT cannot be recalled once issued, so each user carries a session version
and every token the version it was minted with. Resetting a password or
deleting the account bumps the version, and every token issued before that
stops resolving to anyone — on every device, at once.
"""

from __future__ import annotations

from sqlalchemy.orm import Session

from app.core.security import TokenType, parse_subject
from app.models import User


def user_for_token(db: Session, token: str, expected: TokenType = "access") -> User | None:
    parsed = parse_subject(token, expected)
    if parsed is None:
        return None
    user_id, version = parsed
    user = db.get(User, user_id)
    if user is None or (user.token_version or 0) != version:
        return None
    return user


def sign_out_everywhere(user: User) -> None:
    user.token_version = (user.token_version or 0) + 1
