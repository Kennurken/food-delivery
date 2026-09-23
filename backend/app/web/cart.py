"""The site's cart, carried in a signed cookie.

Everything here works with JavaScript switched off: each change is a form POST
and the server renders the result. That keeps the ordering flow on the same
footing as the rest of the site — crawlable, linkable, and usable on a phone
with a bad connection.

The cookie is signed, not encrypted: it holds ids and quantities, nothing
private. Signing is what stops a visitor from editing quantities into a shape
the server never issued; prices are always read from the database at checkout,
never from the cookie.
"""

from __future__ import annotations

import base64
import binascii
import hashlib
import hmac
import json
from dataclasses import dataclass, field

from fastapi import Response
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models import MenuItem, Restaurant

COOKIE = "fd_cart"
MAX_QTY = 50
# A cookie is capped at ~4 KB by every browser. Nobody orders sixty different
# dishes at once, and a silently truncated cart would be worse than a refusal.
MAX_LINES = 40


@dataclass
class CartLine:
    item: MenuItem
    quantity: int

    @property
    def total(self) -> float:
        return round(self.item.price * self.quantity, 2)


@dataclass
class Cart:
    restaurant_id: int | None = None
    quantities: dict[int, int] = field(default_factory=dict)

    @property
    def count(self) -> int:
        return sum(self.quantities.values())

    def is_empty(self) -> bool:
        return not self.quantities


def _sign(raw: bytes) -> str:
    digest = hmac.new(settings.secret_key.encode(), raw, hashlib.sha256).digest()[:16]
    return f"{base64.urlsafe_b64encode(raw).decode()}.{base64.urlsafe_b64encode(digest).decode()}"


def _unsign(value: str) -> bytes | None:
    try:
        body, mac = value.split(".", 1)
        raw = base64.urlsafe_b64decode(body)
        given = base64.urlsafe_b64decode(mac)
    except (ValueError, binascii.Error):
        return None
    expected = hmac.new(settings.secret_key.encode(), raw, hashlib.sha256).digest()[:16]
    return raw if hmac.compare_digest(given, expected) else None


def read(cookie: str | None) -> Cart:
    """A cart that does not parse is an empty cart, never an error page: the
    visitor did nothing wrong and should just see an empty basket."""
    if not cookie:
        return Cart()
    raw = _unsign(cookie)
    if raw is None:
        return Cart()
    try:
        data = json.loads(raw)
        quantities = {
            int(k): min(MAX_QTY, max(0, int(v))) for k, v in (data.get("q") or {}).items()
        }
    except (ValueError, TypeError, AttributeError):
        return Cart()
    quantities = {k: v for k, v in quantities.items() if v > 0}
    restaurant_id = data.get("r")
    if not quantities or not isinstance(restaurant_id, int):
        return Cart()
    return Cart(restaurant_id=restaurant_id, quantities=dict(list(quantities.items())[:MAX_LINES]))


def save(response: Response, cart: Cart) -> None:
    if cart.is_empty():
        response.delete_cookie(COOKIE, path="/")
        return
    raw = json.dumps({"r": cart.restaurant_id, "q": cart.quantities}, separators=(",", ":"))
    response.set_cookie(
        COOKIE,
        _sign(raw.encode()),
        max_age=60 * 60 * 24 * 7,
        httponly=True,
        samesite="lax",
        secure=settings.is_prod,
        path="/",
    )


def add(cart: Cart, *, restaurant_id: int, item_id: int, quantity: int = 1) -> Cart:
    """Switching restaurants replaces the basket rather than mixing two kitchens
    into one order, which no kitchen could fulfil."""
    if cart.restaurant_id != restaurant_id:
        cart = Cart(restaurant_id=restaurant_id, quantities={})
    current = cart.quantities.get(item_id, 0)
    cart.quantities[item_id] = min(MAX_QTY, current + max(1, quantity))
    return cart


def set_quantity(cart: Cart, *, item_id: int, quantity: int) -> Cart:
    if quantity <= 0:
        cart.quantities.pop(item_id, None)
    else:
        cart.quantities[item_id] = min(MAX_QTY, quantity)
    if not cart.quantities:
        cart.restaurant_id = None
    return cart


def hydrate(db: Session, cart: Cart) -> tuple[Restaurant | None, list[CartLine], float]:
    """Turn ids into rows and money. Prices come from the database every time —
    the cookie is a list of wishes, not a receipt."""
    if cart.restaurant_id is None or not cart.quantities:
        return None, [], 0.0
    restaurant = db.get(Restaurant, cart.restaurant_id)
    if restaurant is None:
        return None, [], 0.0
    rows = db.scalars(
        select(MenuItem).where(
            MenuItem.id.in_(cart.quantities),
            MenuItem.restaurant_id == restaurant.id,
            MenuItem.is_available.is_(True),
        )
    )
    lines = [CartLine(item=row, quantity=cart.quantities[row.id]) for row in rows]
    lines.sort(key=lambda line: line.item.name)
    subtotal = round(sum(line.total for line in lines), 2)
    return restaurant, lines, subtotal
