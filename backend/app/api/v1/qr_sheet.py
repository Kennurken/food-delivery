"""Printable sheet of table QR codes: a signed link from the app, a page for the printer."""

from fastapi import APIRouter, HTTPException, status
from fastapi.responses import HTMLResponse
from sqlalchemy import select

from app.api.deps import DB, CurrentUser
from app.core.access import require_restaurant
from app.core.config import settings
from app.models.floor_plan import Floor, FloorObject
from app.services import qr_sheet

router = APIRouter(tags=["qr"])

_HEADERS = {
    "Cache-Control": "no-store",
    "X-Robots-Tag": "noindex",
    "Referrer-Policy": "no-referrer",
}


@router.post("/admin/floors/{floor_id}/qr-sheet")
def sheet_link(floor_id: int, db: DB, user: CurrentUser) -> dict:
    floor = db.get(Floor, floor_id)
    if not floor:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Floor not found")
    require_restaurant(db, user, floor.restaurant_id, "tables.read")
    token = qr_sheet.sign(floor.id)
    base = settings.public_site_url.rstrip("/")
    return {
        "url": f"{base}/api/v1/qr-sheet/{token}",
        "expires_in": int(qr_sheet.TTL.total_seconds()),
    }


@router.get("/qr-sheet/{token}", response_class=HTMLResponse)
def sheet(token: str, db: DB) -> HTMLResponse:
    """Public: the signed token is the credential. Anything wrong looks the same."""
    floor_id = qr_sheet.verify(token)
    floor = db.get(Floor, floor_id) if floor_id is not None else None
    if floor is None:
        raise HTTPException(
            status.HTTP_404_NOT_FOUND, "This link has expired. Open it again from the app."
        )
    objects = db.scalars(
        select(FloorObject)
        .where(FloorObject.floor_id == floor.id, FloorObject.kind.startswith("table"))
        .order_by(FloorObject.name, FloorObject.id)
    )
    tables = [(o.id, o.name or f"Table {o.id}") for o in objects]
    html = qr_sheet.render(floor.restaurant.name, floor.restaurant_id, tables)
    return HTMLResponse(html, headers=_HEADERS)
