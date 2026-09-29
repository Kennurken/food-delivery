from fastapi import APIRouter, HTTPException, Request, status
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import func, select

from app.api.deps import DB, AdminUser
from app.core import audit
from app.models import City, Restaurant
from app.services import cities

router = APIRouter(prefix="/cities", tags=["cities"])
admin_router = APIRouter(prefix="/admin/cities", tags=["cities"])


class CityOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    slug: str
    name: str
    lat: float | None = None
    lng: float | None = None


@router.get("", response_model=list[CityOut])
def list_cities(db: DB) -> list:
    """Cities the service runs in. Public: it is how a visitor picks one."""
    return cities.active(db)


# ------------------------------------------------------------ platform admin


class CityAdminOut(CityOut):
    id: int
    name_in: str | None = None
    utc_offset_min: int
    is_active: bool
    sort_order: int
    venues: int = 0


class CityCreate(BaseModel):
    # Lowercase latin, digits and dashes: it is a URL segment (/shymkent/).
    slug: str = Field(pattern=r"^[a-z][a-z0-9-]{1,39}$")
    name: str = Field(min_length=1, max_length=80)
    name_in: str | None = Field(default=None, max_length=80)
    lat: float | None = Field(default=None, ge=-90, le=90)
    lng: float | None = Field(default=None, ge=-180, le=180)
    utc_offset_min: int = Field(default=300, ge=-720, le=840)
    is_active: bool = True
    sort_order: int = 0


class CityUpdate(BaseModel):
    # No slug: it is a public URL already shared and indexed. A city that needs
    # a different address is a new city.
    name: str | None = Field(default=None, min_length=1, max_length=80)
    name_in: str | None = Field(default=None, max_length=80)
    lat: float | None = Field(default=None, ge=-90, le=90)
    lng: float | None = Field(default=None, ge=-180, le=180)
    utc_offset_min: int | None = Field(default=None, ge=-720, le=840)
    is_active: bool | None = None
    sort_order: int | None = None


def _out(db, city: City) -> CityAdminOut:
    venues = db.scalar(select(func.count(Restaurant.id)).where(Restaurant.city_id == city.id)) or 0
    return CityAdminOut.model_validate(city).model_copy(update={"venues": int(venues)})


@admin_router.get("", response_model=list[CityAdminOut])
def all_cities(db: DB, _: AdminUser) -> list[CityAdminOut]:
    """Every city, switched off ones included: the admin must find a city to
    switch it back on."""
    rows = db.scalars(select(City).order_by(City.sort_order, City.name))
    return [_out(db, c) for c in rows]


@admin_router.post("", response_model=CityAdminOut, status_code=status.HTTP_201_CREATED)
def create_city(body: CityCreate, db: DB, user: AdminUser, request: Request) -> CityAdminOut:
    try:
        cities.check_slug(body.slug)
    except cities.ReservedSlugError as e:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, str(e)) from e
    if db.scalar(select(City.id).where(City.slug == body.slug)):
        raise HTTPException(status.HTTP_409_CONFLICT, "A city with this address exists")
    city = City(**body.model_dump())
    db.add(city)
    db.flush()
    audit.record(
        db,
        actor_id=user.id,
        restaurant_id=None,
        action="city.create",
        resource=f"city:{city.id}",
        payload={"slug": city.slug},
        request_id=getattr(request.state, "request_id", None),
    )
    db.commit()
    db.refresh(city)
    return _out(db, city)


@admin_router.patch("/{city_id}", response_model=CityAdminOut)
def update_city(
    city_id: int, body: CityUpdate, db: DB, user: AdminUser, request: Request
) -> CityAdminOut:
    city = db.get(City, city_id)
    if city is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "City not found")
    changes = body.model_dump(exclude_unset=True)
    for key, value in changes.items():
        setattr(city, key, value)
    audit.record(
        db,
        actor_id=user.id,
        restaurant_id=None,
        action="city.update",
        resource=f"city:{city.id}",
        payload=changes,
        request_id=getattr(request.state, "request_id", None),
    )
    db.commit()
    db.refresh(city)
    return _out(db, city)
