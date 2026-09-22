"""HMAC table tokens. Identify restaurant + table without a guessable open id."""

import hmac
from hashlib import sha256

from app.core.config import settings


def table_token(restaurant_id: int, object_id: int) -> str:
    payload = f"{restaurant_id}.{object_id}"
    sig = hmac.new(settings.secret_key.encode(), payload.encode(), sha256).hexdigest()[:16]
    return f"{payload}.{sig}"


def parse_table_token(token: str) -> tuple[int, int] | None:
    parts = (token or "").strip().split(".")
    if len(parts) != 3:
        return None
    try:
        restaurant_id, object_id = int(parts[0]), int(parts[1])
    except ValueError:
        return None
    expected = table_token(restaurant_id, object_id)
    if not hmac.compare_digest(expected, f"{restaurant_id}.{object_id}.{parts[2]}"):
        return None
    return restaurant_id, object_id
