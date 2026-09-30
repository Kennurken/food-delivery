"""A printable page of QR codes, one per table of a floor.

The page is opened in a browser to be printed, and a browser tab carries no
bearer token. So the authenticated app asks for a link and the link itself is
the credential: signed with the server secret, naming one floor, dead after ten
minutes. Nothing is stored; a leaked link shows table codes that are printed on
the tables anyway, and only until it expires.
"""

from __future__ import annotations

import hmac
from datetime import UTC, datetime, timedelta
from hashlib import sha256
from html import escape

import segno

from app.core.config import settings
from app.core.qr import table_token

TTL = timedelta(minutes=10)


def _sig(payload: str) -> str:
    key = f"qr-sheet:{settings.secret_key}".encode()
    return hmac.new(key, payload.encode(), sha256).hexdigest()[:24]


def _now() -> datetime:
    return datetime.now(UTC)


def sign(floor_id: int, now: datetime | None = None) -> str:
    expires = int(((now or _now()) + TTL).timestamp())
    payload = f"{floor_id}.{expires}"
    return f"{payload}.{_sig(payload)}"


def verify(token: str, now: datetime | None = None) -> int | None:
    """The floor id, or None for anything forged, malformed or expired."""
    parts = (token or "").split(".")
    if len(parts) != 3:
        return None
    try:
        floor_id, expires = int(parts[0]), int(parts[1])
    except ValueError:
        return None
    if not hmac.compare_digest(_sig(f"{floor_id}.{expires}"), parts[2]):
        return None
    if (now or _now()).timestamp() > expires:
        return None
    return floor_id


def table_url(restaurant_id: int, object_id: int) -> str:
    """What a guest's camera opens: the app, straight at that table."""
    base = settings.public_app_url.rstrip("/")
    return f"{base}/#/t/{table_token(restaurant_id, object_id)}"


def _qr_svg(text: str) -> str:
    return segno.make(text, error="m").svg_inline(scale=6, border=2)


_STYLE = """
@page { size: A4; margin: 12mm; }
* { box-sizing: border-box; }
body { font-family: -apple-system, "Segoe UI", Roboto, Arial, sans-serif; margin: 0; color: #111; }
header { margin: 0 0 8mm; }
header h1 { font-size: 18pt; margin: 0; }
header p { margin: 2mm 0 0; color: #555; font-size: 10pt; }
.grid { display: grid; grid-template-columns: 1fr 1fr; gap: 8mm; }
.card { border: 1px dashed #999; border-radius: 4mm; padding: 6mm; text-align: center;
        height: 85mm; page-break-inside: avoid; break-inside: avoid;
        display: flex; flex-direction: column; align-items: center; justify-content: center; }
.card svg { width: 45mm; height: 45mm; }
.table { font-size: 22pt; font-weight: 800; margin-top: 3mm; }
.hint { font-size: 11pt; margin-top: 1mm; }
.venue { font-size: 9pt; color: #555; margin-top: 1mm; }
.empty { font-size: 14pt; color: #555; }
@media print { header p { display: none; } }
"""


def render(restaurant_name: str, restaurant_id: int, tables: list[tuple[int, str]]) -> str:
    """`tables` is (object id, display name), already in print order."""
    venue = escape(restaurant_name)
    if tables:
        cards = "".join(
            '<div class="card">'
            f"{_qr_svg(table_url(restaurant_id, oid))}"
            f'<div class="table">{escape(name)}</div>'
            '<div class="hint">Scan to order · Сканируйте, чтобы заказать</div>'
            f'<div class="venue">{venue}</div>'
            "</div>"
            for oid, name in tables
        )
        body = f'<div class="grid">{cards}</div>'
    else:
        body = '<p class="empty">No tables on this floor yet.</p>'
    return (
        "<!doctype html><html><head><meta charset=\"utf-8\">"
        '<meta name="viewport" content="width=device-width, initial-scale=1">'
        '<meta name="robots" content="noindex">'
        f"<title>{venue} — table QR codes</title><style>{_STYLE}</style></head><body>"
        f"<header><h1>{venue}</h1><p>Print this page (A4). The link expires in ten minutes."
        f"</p></header>{body}</body></html>"
    )
