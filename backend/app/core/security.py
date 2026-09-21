from datetime import UTC, datetime, timedelta
from typing import Literal

import bcrypt
from jose import JWTError, jwt

from app.core.config import settings

TokenType = Literal["access", "refresh"]


def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()


def verify_password(password: str, hashed: str) -> bool:
    return bcrypt.checkpw(password.encode(), hashed.encode())


def _encode(subject: str, kind: TokenType, ttl: timedelta) -> str:
    now = datetime.now(UTC)
    payload = {"sub": subject, "type": kind, "iat": now, "exp": now + ttl}
    return jwt.encode(payload, settings.secret_key, algorithm=settings.algorithm)


def create_access_token(subject: str) -> str:
    return _encode(subject, "access", timedelta(minutes=settings.access_token_expire_minutes))


def create_refresh_token(subject: str) -> str:
    return _encode(subject, "refresh", timedelta(days=settings.refresh_token_expire_days))


def decode_token(token: str, expected: TokenType = "access") -> str | None:
    """Return subject if token is valid and of the expected type, else None."""
    try:
        payload = jwt.decode(token, settings.secret_key, algorithms=[settings.algorithm])
    except JWTError:
        return None
    if payload.get("type", "access") != expected:
        return None
    sub = payload.get("sub")
    return sub if isinstance(sub, str) else None


def parse_subject_id(token: str, expected: TokenType = "access") -> int | None:
    sub = decode_token(token, expected)
    if sub is None:
        return None
    try:
        return int(sub)
    except (TypeError, ValueError):
        return None
