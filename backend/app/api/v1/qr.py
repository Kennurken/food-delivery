from fastapi import APIRouter, HTTPException, status

from app.api.deps import DB
from app.core.qr import parse_table_token
from app.models.floor_plan import FloorObject

router = APIRouter(prefix="/qr", tags=["qr"])


@router.get("/{token}")
def resolve_qr(token: str, db: DB) -> dict:
    """Public: scan a table QR, get the restaurant + table without logging in."""
    parsed = parse_table_token(token)
    if not parsed:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Unknown QR")
    restaurant_id, object_id = parsed
    obj = db.get(FloorObject, object_id)
    if not obj or not obj.kind.startswith("table"):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Unknown QR")
    floor = obj.floor
    if floor.restaurant_id != restaurant_id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Unknown QR")
    restaurant = floor.restaurant
    zone = next((z for z in floor.zones if z.id == obj.zone_id), None) if obj.zone_id else None
    return {
        "token": token,
        "channel": "qr_table",
        "restaurant_id": restaurant.id,
        "restaurant_name": restaurant.name,
        "is_open": restaurant.is_open,
        "floor": {"id": floor.id, "name": floor.name},
        "zone": {"id": zone.id, "name": zone.name} if zone else None,
        "table": {
            "id": obj.id,
            "name": obj.name or f"Table {obj.id}",
            "capacity": obj.capacity,
        },
    }
