from datetime import datetime

from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select

from app.api.deps import DB, CurrentUser
from app.core.access import require_restaurant
from app.core.features import entitlements
from app.core.qr import table_token
from app.models import Restaurant
from app.models.floor_plan import Floor, FloorObject, FloorVersion, FloorZone
from app.schemas.floor_plan import (
    FloorCreate,
    FloorDetail,
    FloorOut,
    FloorUpdate,
    LayoutSave,
    VersionOut,
)
from app.services.floor_plan import (
    OBJECT_KINDS,
    TABLE_KINDS,
    TABLE_STATUSES,
    apply_template,
    record_version,
)

router = APIRouter(prefix="/admin", tags=["floor-plan"])


def _floor(db, floor_id: int) -> Floor:
    floor = db.get(Floor, floor_id)
    if not floor:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Floor not found")
    return floor


def _read(db, user, restaurant_id: int) -> Restaurant:
    return require_restaurant(db, user, restaurant_id, "tables.read")


def _write(db, user, restaurant_id: int) -> Restaurant:
    return require_restaurant(db, user, restaurant_id, "tables.write")


@router.get("/restaurants/{restaurant_id}/floors", response_model=list[FloorOut])
def list_floors(restaurant_id: int, db: DB, user: CurrentUser) -> list[Floor]:
    _read(db, user, restaurant_id)
    stmt = select(Floor).where(Floor.restaurant_id == restaurant_id).order_by(Floor.sort_order, Floor.id)
    return list(db.scalars(stmt))


@router.post("/restaurants/{restaurant_id}/floors", response_model=FloorDetail, status_code=status.HTTP_201_CREATED)
def create_floor(restaurant_id: int, data: FloorCreate, db: DB, user: CurrentUser) -> Floor:
    restaurant = _write(db, user, restaurant_id)
    if not entitlements(db, restaurant).enabled("floor_plan"):
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Floor plans are not on this plan")
    last = db.scalar(
        select(Floor.sort_order).where(Floor.restaurant_id == restaurant_id).order_by(Floor.sort_order.desc())
    )
    floor = Floor(
        restaurant_id=restaurant_id,
        name=data.name,
        width_cm=data.width_cm,
        height_cm=data.height_cm,
        grid_cm=data.grid_cm,
        sort_order=(last or 0) + 1,
    )
    if data.template:
        apply_template(floor, data.template)
    db.add(floor)
    db.commit()
    db.refresh(floor)
    return floor


@router.get("/floors/{floor_id}", response_model=FloorDetail)
def get_floor(floor_id: int, db: DB, user: CurrentUser) -> Floor:
    floor = _floor(db, floor_id)
    _read(db, user, floor.restaurant_id)
    return floor


@router.patch("/floors/{floor_id}", response_model=FloorOut)
def update_floor(floor_id: int, data: FloorUpdate, db: DB, user: CurrentUser) -> Floor:
    floor = _floor(db, floor_id)
    _write(db, user, floor.restaurant_id)
    for k, v in data.model_dump(exclude_unset=True).items():
        setattr(floor, k, v)
    db.commit()
    db.refresh(floor)
    return floor


@router.delete("/floors/{floor_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_floor(floor_id: int, db: DB, user: CurrentUser) -> None:
    floor = _floor(db, floor_id)
    _write(db, user, floor.restaurant_id)
    db.delete(floor)
    db.commit()


@router.post("/floors/{floor_id}/duplicate", response_model=FloorDetail, status_code=status.HTTP_201_CREATED)
def duplicate_floor(floor_id: int, db: DB, user: CurrentUser) -> Floor:
    src = _floor(db, floor_id)
    _write(db, user, src.restaurant_id)
    last = db.scalar(
        select(Floor.sort_order).where(Floor.restaurant_id == src.restaurant_id).order_by(Floor.sort_order.desc())
    )
    copy = Floor(
        restaurant_id=src.restaurant_id,
        name=f"{src.name} copy",
        width_cm=src.width_cm,
        height_cm=src.height_cm,
        grid_cm=src.grid_cm,
        sort_order=(last or 0) + 1,
    )
    db.add(copy)
    db.flush()
    zone_map: dict[int, int] = {}
    for z in src.zones:
        nz = FloorZone(
            floor_id=copy.id,
            name=z.name,
            kind=z.kind,
            color=z.color,
            capacity=z.capacity,
            description=z.description,
            x=z.x,
            y=z.y,
            width=z.width,
            height=z.height,
        )
        db.add(nz)
        db.flush()
        zone_map[z.id] = nz.id
    for o in src.objects:
        db.add(
            FloorObject(
                floor_id=copy.id,
                zone_id=zone_map.get(o.zone_id) if o.zone_id else None,
                kind=o.kind,
                name=o.name,
                x=o.x,
                y=o.y,
                width=o.width,
                height=o.height,
                rotation=o.rotation,
                z_index=o.z_index,
                capacity=o.capacity,
                min_guests=o.min_guests,
                max_guests=o.max_guests,
                status=o.status,
                mergeable=o.mergeable,
                merge_group=o.merge_group,
                extra=o.extra or {},
            )
        )
    db.commit()
    db.refresh(copy)
    return copy


@router.put("/floors/{floor_id}/layout", response_model=FloorDetail)
def save_layout(floor_id: int, data: LayoutSave, db: DB, user: CurrentUser) -> Floor:
    floor = _floor(db, floor_id)
    restaurant = _write(db, user, floor.restaurant_id)
    cap = entitlements(db, restaurant).limit("tables.max")
    n_tables = sum(1 for o in data.objects if o.kind in TABLE_KINDS)
    if cap is not None and n_tables > cap:
        existing = sum(1 for o in floor.objects if o.kind in TABLE_KINDS)
        if n_tables > existing:
            raise HTTPException(
                status.HTTP_400_BAD_REQUEST, f"Plan allows at most {cap} tables"
            )
    def _naive(dt):
        return dt.replace(tzinfo=None) if getattr(dt, "tzinfo", None) else dt

    if floor.updated_at is not None and _naive(data.updated_at) != _naive(floor.updated_at):
        raise HTTPException(status.HTTP_409_CONFLICT, "Floor was edited elsewhere")
    for obj in data.objects:
        if obj.kind not in OBJECT_KINDS:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, f"Unknown object kind: {obj.kind}")
        if obj.status not in TABLE_STATUSES:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, f"Unknown status: {obj.status}")

    db.add(record_version(floor))

    keep_zones = {z.id for z in data.zones if z.id and z.id > 0}
    for z in list(floor.zones):
        if z.id not in keep_zones:
            db.delete(z)
    db.flush()

    zone_map: dict[int, int] = {}
    for z in data.zones:
        payload = z.model_dump(exclude={"id"})
        if z.id and z.id > 0:
            row = db.get(FloorZone, z.id)
            if not row or row.floor_id != floor.id:
                raise HTTPException(status.HTTP_400_BAD_REQUEST, "Invalid zone")
            for k, v in payload.items():
                setattr(row, k, v)
            zone_map[z.id] = row.id
        else:
            row = FloorZone(floor_id=floor.id, **payload)
            db.add(row)
            db.flush()
            if z.id is not None:
                zone_map[z.id] = row.id

    keep_objects = {o.id for o in data.objects if o.id and o.id > 0}
    for o in list(floor.objects):
        if o.id not in keep_objects:
            db.delete(o)
    db.flush()

    for o in data.objects:
        payload = o.model_dump(exclude={"id", "zone_id"})
        zone_id = o.zone_id
        if zone_id is not None and zone_id in zone_map:
            zone_id = zone_map[zone_id]
        elif zone_id is not None and zone_id < 0:
            zone_id = zone_map.get(zone_id)
        if o.id and o.id > 0:
            row = db.get(FloorObject, o.id)
            if not row or row.floor_id != floor.id:
                raise HTTPException(status.HTTP_400_BAD_REQUEST, "Invalid object")
            for k, v in payload.items():
                setattr(row, k, v)
            row.zone_id = zone_id
        else:
            db.add(FloorObject(floor_id=floor.id, zone_id=zone_id, **payload))

    floor.updated_at = datetime.utcnow()  # noqa: DTZ003
    db.commit()
    db.refresh(floor)
    return floor


@router.get("/floors/{floor_id}/versions", response_model=list[VersionOut])
def list_versions(floor_id: int, db: DB, user: CurrentUser) -> list[FloorVersion]:
    floor = _floor(db, floor_id)
    _read(db, user, floor.restaurant_id)
    stmt = select(FloorVersion).where(FloorVersion.floor_id == floor_id).order_by(FloorVersion.id.desc())
    return list(db.scalars(stmt))


@router.post("/floors/{floor_id}/versions/{version_id}/restore", response_model=FloorDetail)
def restore_version(floor_id: int, version_id: int, db: DB, user: CurrentUser) -> Floor:
    floor = _floor(db, floor_id)
    _write(db, user, floor.restaurant_id)
    ver = db.get(FloorVersion, version_id)
    if not ver or ver.floor_id != floor.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Version not found")
    db.add(record_version(floor, label="before restore"))
    for z in list(floor.zones):
        db.delete(z)
    for o in list(floor.objects):
        db.delete(o)
    db.flush()
    snap = ver.snapshot
    zone_keys = ("name", "kind", "color", "capacity", "description", "x", "y", "width", "height")
    obj_keys = (
        "kind",
        "name",
        "x",
        "y",
        "width",
        "height",
        "rotation",
        "z_index",
        "capacity",
        "min_guests",
        "max_guests",
        "status",
        "mergeable",
        "merge_group",
        "extra",
    )
    for z in snap.get("zones", []):
        floor.zones.append(FloorZone(**{k: z[k] for k in zone_keys if k in z}))
    for o in snap.get("objects", []):
        floor.objects.append(FloorObject(**{k: o[k] for k in obj_keys if k in o}))
    if "width_cm" in snap:
        floor.width_cm = snap["width_cm"]
        floor.height_cm = snap["height_cm"]
        floor.grid_cm = snap["grid_cm"]
    db.commit()
    db.refresh(floor)
    return floor


@router.get("/floors/{floor_id}/objects/{object_id}/qr")
def table_qr(floor_id: int, object_id: int, db: DB, user: CurrentUser) -> dict:
    floor = _floor(db, floor_id)
    _read(db, user, floor.restaurant_id)
    obj = db.get(FloorObject, object_id)
    if not obj or obj.floor_id != floor.id or not obj.kind.startswith("table"):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Table not found")
    token = table_token(floor.restaurant_id, obj.id)
    return {"token": token, "path": f"/t/{token}"}
