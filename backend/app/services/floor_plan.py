"""Templates and layout snapshots. Kept out of the HTTP layer so tests can use them."""

from __future__ import annotations

from datetime import datetime

from app.models.floor_plan import Floor, FloorObject, FloorVersion, FloorZone

ZONE_KINDS = (
    "hall",
    "vip",
    "terrace",
    "bar",
    "banquet",
    "outdoor",
    "smoking",
    "private",
)

TABLE_KINDS = ("table_round", "table_square", "table_rect", "table_large", "table_custom")
FURNITURE_KINDS = ("chair", "sofa", "booth", "stool", "reception", "counter")
STRUCTURE_KINDS = ("wall", "door", "window", "column", "stairs", "elevator")
INFRA_KINDS = ("bar", "kitchen", "toilet", "entrance", "exit")
OBJECT_KINDS = TABLE_KINDS + FURNITURE_KINDS + STRUCTURE_KINDS + INFRA_KINDS
TABLE_STATUSES = ("available", "reserved", "occupied", "cleaning", "disabled")


def snapshot_of(floor: Floor) -> dict:
    return {
        "name": floor.name,
        "width_cm": floor.width_cm,
        "height_cm": floor.height_cm,
        "grid_cm": floor.grid_cm,
        "zones": [
            {
                "name": z.name,
                "kind": z.kind,
                "color": z.color,
                "capacity": z.capacity,
                "description": z.description,
                "x": z.x,
                "y": z.y,
                "width": z.width,
                "height": z.height,
            }
            for z in floor.zones
        ],
        "objects": [
            {
                "kind": o.kind,
                "name": o.name,
                "x": o.x,
                "y": o.y,
                "width": o.width,
                "height": o.height,
                "rotation": o.rotation,
                "z_index": o.z_index,
                "capacity": o.capacity,
                "min_guests": o.min_guests,
                "max_guests": o.max_guests,
                "status": o.status,
                "mergeable": o.mergeable,
                "merge_group": o.merge_group,
                "extra": o.extra or {},
            }
            for o in floor.objects
        ],
    }


def apply_template(floor: Floor, name: str) -> None:
    if name != "cafe":
        return
    floor.zones.append(
        FloorZone(
            name="Main Hall",
            kind="hall",
            color="#D9CDB8",
            capacity=24,
            x=80,
            y=80,
            width=1400,
            height=1000,
        )
    )
    floor.zones.append(
        FloorZone(name="Bar", kind="bar", color="#C9B29A", x=80, y=1120, width=1400, height=200)
    )
    tables = [
        ("12", "table_round", 220, 260, 120, 120, 4),
        ("13", "table_round", 420, 260, 120, 120, 4),
        ("14", "table_square", 220, 520, 140, 140, 4),
        ("15", "table_rect", 480, 520, 200, 120, 6),
        ("16", "table_large", 900, 280, 240, 160, 8),
        ("17", "table_round", 1180, 560, 120, 120, 4),
    ]
    for name_, kind, x, y, w, h, cap in tables:
        floor.objects.append(
            FloorObject(
                kind=kind,
                name=name_,
                x=x,
                y=y,
                width=w,
                height=h,
                capacity=cap,
                min_guests=1,
                max_guests=cap,
                status="available",
            )
        )
    floor.objects.extend(
        [
            FloorObject(kind="wall", name="", x=80, y=80, width=1400, height=16),
            FloorObject(kind="wall", name="", x=80, y=80, width=16, height=1240),
            FloorObject(kind="wall", name="", x=1464, y=80, width=16, height=1240),
            FloorObject(kind="wall", name="", x=80, y=1304, width=1400, height=16),
            FloorObject(kind="door", name="Entrance", x=720, y=1288, width=120, height=32),
            FloorObject(kind="bar", name="Bar", x=160, y=1140, width=720, height=120),
            FloorObject(kind="kitchen", name="Kitchen", x=1520, y=160, width=360, height=400),
            FloorObject(kind="toilet", name="WC", x=1520, y=600, width=200, height=180),
            FloorObject(kind="sofa", name="Lounge", x=1080, y=900, width=280, height=100),
        ]
    )


def record_version(floor: Floor, label: str = "") -> FloorVersion:
    return FloorVersion(
        floor_id=floor.id,
        label=label or datetime.utcnow().strftime("%Y-%m-%d %H:%M"),  # noqa: DTZ003
        snapshot=snapshot_of(floor),
    )
