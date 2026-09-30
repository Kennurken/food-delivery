from datetime import UTC, datetime, timedelta
from typing import Literal

import bcrypt
import jwt

from app.core.config import settings

TokenType = Literal["access", "refresh"]


def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()


def verify_password(password: str, hashed: str) -> bool:
    return bcrypt.checkpw(password.encode(), hashed.encode())


def _encode(subject: str, kind: TokenType, ttl: timedelta, version: int = 0) -> str:
    now = datetime.now(UTC)
    payload = {"sub": subject, "type": kind, "iat": now, "exp": now + ttl, "ver": version}
    return jwt.encode(payload, settings.secret_key, algorithm=settings.algorithm)


def create_access_token(subject: str, version: int = 0) -> str:
    ttl = timedelta(minutes=settings.access_token_expire_minutes)
    return _encode(subject, "access", ttl, version)


def create_refresh_token(subject: str, version: int = 0) -> str:
    return _encode(subject, "refresh", timedelta(days=settings.refresh_token_expire_days), version)


def _payload(token: str, expected: TokenType) -> dict | None:
    try:
        # A few seconds of leeway: `iat` is checked, and two hosts' clocks are never
        # exactly equal.
        payload = jwt.decode(
            token, settings.secret_key, algorithms=[settings.algorithm], leeway=10
        )
    except jwt.PyJWTError:
        return None
    if payload.get("type", "access") != expected:
        return None
    return payload


def decode_token(token: str, expected: TokenType = "access") -> str | None:
    """Return subject if token is valid and of the expected type, else None."""
    payload = _payload(token, expected)
    sub = payload.get("sub") if payload else None
    return sub if isinstance(sub, str) else None


def parse_subject(token: str, expected: TokenType = "access") -> tuple[int, int] | None:
    """(user id, session version) from a valid token. Tokens issued before
    versions existed carry none and count as version 0."""
    payload = _payload(token, expected)
    if payload is None:
        return None
    try:
        return int(payload.get("sub")), int(payload.get("ver", 0))
    except (TypeError, ValueError):
        return None


def parse_subject_id(token: str, expected: TokenType = "access") -> int | None:
    sub = decode_token(token, expected)
    if sub is None:
        return None
    try:
        return int(sub)
    except (TypeError, ValueError):
        return None
