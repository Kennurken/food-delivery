from fastapi import APIRouter
from pydantic import BaseModel, ConfigDict

from app.api.deps import DB
from app.services import cities

router = APIRouter(prefix="/cities", tags=["cities"])


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
