"""Geocoding and routing behind one provider — same idea as billing.

Photon + Nominatim + OSRM work without a paid key. `GEO_PROVIDER=fixture`
keeps tests offline. Never call OSM from the Flutter client; this module
is the only User-Agent they see.
"""

from __future__ import annotations

import math
import time
from dataclasses import dataclass

from app.core.config import settings

# Almaty — Republic Square. Default camera when we have no pin yet.
ALMATY = (43.238949, 76.945465)

UA = "food-delivery/0.7 (https://github.com/Kennurken/food-delivery)"

_CACHE: dict[str, tuple[float, object]] = {}
_CACHE_TTL = 180.0
_CACHE_MAX = 256


@dataclass(frozen=True)
class Place:
    lat: float
    lng: float
    line: str
    subtitle: str = ""


@dataclass(frozen=True)
class Route:
    distance_m: float
    duration_s: float
    points: list[tuple[float, float]]  # (lat, lng)


def _cached(key: str, ttl: float, build):
    now = time.monotonic()
    hit = _CACHE.get(key)
    if hit and hit[0] > now:
        return hit[1]
    value = build()
    if len(_CACHE) >= _CACHE_MAX:
        _CACHE.clear()
    _CACHE[key] = (now + ttl, value)
    return value


def valid_coord(lat: float | None, lng: float | None) -> bool:
    return (
        lat is not None
        and lng is not None
        and -90 <= lat <= 90
        and -180 <= lng <= 180
        and not (lat == 0 and lng == 0)
    )


def haversine_m(a_lat: float, a_lng: float, b_lat: float, b_lng: float) -> float:
    r = 6371000.0
    p1, p2 = math.radians(a_lat), math.radians(b_lat)
    dphi = math.radians(b_lat - a_lat)
    dlmb = math.radians(b_lng - a_lng)
    h = math.sin(dphi / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dlmb / 2) ** 2
    return 2 * r * math.asin(min(1.0, math.sqrt(h)))


def _straight(a: tuple[float, float], b: tuple[float, float]) -> Route:
    dist = haversine_m(a[0], a[1], b[0], b[1])
    # City driving ~22 km/h plus a minute of faff.
    eta = dist / 6.1 + 60
    n = max(2, min(8, int(dist / 400) + 2))
    pts = [
        (a[0] + (b[0] - a[0]) * i / (n - 1), a[1] + (b[1] - a[1]) * i / (n - 1)) for i in range(n)
    ]
    return Route(distance_m=round(dist, 1), duration_s=round(eta, 1), points=pts)


class GeoProvider:
    def search(
        self, q: str, *, lat: float | None = None, lng: float | None = None, lang: str = "en"
    ) -> list[Place]:
        raise NotImplementedError

    def reverse(self, lat: float, lng: float, *, lang: str = "en") -> Place | None:
        raise NotImplementedError

    def route(self, a: tuple[float, float], b: tuple[float, float]) -> Route:
        raise NotImplementedError


class FixtureProvider(GeoProvider):
    """Deterministic Almaty pins. Used in pytest and as a last-resort fallback."""

    PLACES = (
        Place(43.238949, 76.945465, "Abay 10", "Almaty"),
        Place(43.25654, 76.92812, "Dostyk 1", "Almaty"),
        Place(43.21670, 76.88280, "Al-Farabi 77", "Almaty"),
        Place(43.22251, 76.85133, "Satpayev 30", "Almaty"),
        Place(43.24062, 76.90580, "Tole Bi 83", "Almaty"),
    )

    def search(
        self, q: str, *, lat: float | None = None, lng: float | None = None, lang: str = "en"
    ) -> list[Place]:
        needle = q.strip().lower()
        if not needle:
            return []
        return [p for p in self.PLACES if needle in p.line.lower() or needle in p.subtitle.lower()]

    def reverse(self, lat: float, lng: float, *, lang: str = "en") -> Place | None:
        best = min(self.PLACES, key=lambda p: haversine_m(lat, lng, p.lat, p.lng))
        return Place(lat, lng, best.line, best.subtitle)

    def route(self, a: tuple[float, float], b: tuple[float, float]) -> Route:
        return _straight(a, b)


class PhotonProvider(GeoProvider):
    def search(
        self, q: str, *, lat: float | None = None, lng: float | None = None, lang: str = "en"
    ) -> list[Place]:
        q = q.strip()
        if len(q) < 2:
            return []

        def build() -> list[Place]:
            params: dict = {"q": q, "limit": 8, "lang": lang, "osm_tag": "!place:country"}
            if valid_coord(lat, lng):
                params["lat"] = lat
                params["lon"] = lng
            data = _get("https://photon.komoot.io/api/", params)
            out = _features(data)
            if out:
                return out
            nom = _get(
                "https://nominatim.openstreetmap.org/search",
                {
                    "q": q,
                    "format": "jsonv2",
                    "addressdetails": 1,
                    "limit": 8,
                    "countrycodes": "kz",
                    "accept-language": lang,
                },
            )
            return _nominatim_search(nom)

        return _cached(f"s:{lang}:{q}:{lat}:{lng}", _CACHE_TTL, build)

    def reverse(self, lat: float, lng: float, *, lang: str = "en") -> Place | None:
        def build() -> Place | None:
            data = _get(
                "https://photon.komoot.io/reverse",
                {"lon": lng, "lat": lat, "lang": lang},
            )
            feats = _features(data)
            if feats:
                hit = feats[0]
                return Place(lat, lng, hit.line, hit.subtitle)
            nom = _get(
                "https://nominatim.openstreetmap.org/reverse",
                {
                    "lat": lat,
                    "lon": lng,
                    "format": "jsonv2",
                    "zoom": 18,
                    "addressdetails": 1,
                    "accept-language": lang,
                },
            )
            place = _nominatim_one(nom, lat, lng)
            return place

        return _cached(f"r:{lang}:{round(lat, 5)}:{round(lng, 5)}", 60.0, build)

    def route(self, a: tuple[float, float], b: tuple[float, float]) -> Route:
        def build() -> Route:
            url = (
                "https://router.project-osrm.org/route/v1/driving/"
                f"{a[1]},{a[0]};{b[1]},{b[0]}"
            )
            data = _get(url, {"overview": "full", "geometries": "geojson"})
            routes = (data or {}).get("routes") or []
            if not routes:
                return _straight(a, b)
            r0 = routes[0]
            coords = (r0.get("geometry") or {}).get("coordinates") or []
            pts = [(lat, lng) for lng, lat in coords]
            if len(pts) > 180:
                step = max(1, len(pts) // 160)
                pts = pts[::step]
                if pts[-1] != (coords[-1][1], coords[-1][0]):
                    pts.append((coords[-1][1], coords[-1][0]))
            if len(pts) < 2:
                return _straight(a, b)
            return Route(
                distance_m=round(float(r0.get("distance") or 0), 1),
                duration_s=round(float(r0.get("duration") or 0), 1),
                points=pts,
            )

        key = f"rt:{round(a[0], 4)}:{round(a[1], 4)}:{round(b[0], 4)}:{round(b[1], 4)}"
        return _cached(key, 120.0, build)


def _get(url: str, params: dict) -> dict | list | None:
    import httpx

    try:
        with httpx.Client(timeout=5.0, headers={"User-Agent": UA}) as client:
            r = client.get(url, params=params)
            if r.status_code != 200:
                return None
            return r.json()
    except Exception:  # noqa: BLE001 — network/JSON; callers fall back
        return None


def _features(data: dict | list | None) -> list[Place]:
    if not isinstance(data, dict):
        return []
    out: list[Place] = []
    for feat in data.get("features") or []:
        geom = feat.get("geometry") or {}
        coords = geom.get("coordinates") or []
        if len(coords) < 2:
            continue
        lng, lat = float(coords[0]), float(coords[1])
        if not valid_coord(lat, lng):
            continue
        props = feat.get("properties") or {}
        line, subtitle = _label(props)
        if not line:
            continue
        out.append(Place(lat, lng, line, subtitle))
    return out


def _label(props: dict) -> tuple[str, str]:
    number = str(props.get("housenumber") or "").strip()
    street = str(props.get("street") or "").strip()
    name = str(props.get("name") or "").strip()
    city = str(props.get("city") or props.get("locality") or props.get("county") or "").strip()
    if street and number:
        line = f"{street} {number}"
    elif name and street and name.lower() != street.lower():
        line = f"{name}, {street}"
    elif street:
        line = street
    elif name:
        line = name
    else:
        line = ""
    return line, city


def _nominatim_search(data: dict | list | None) -> list[Place]:
    if not isinstance(data, list):
        return []
    out: list[Place] = []
    for row in data:
        place = _nominatim_one(row, None, None)
        if place:
            out.append(place)
    return out


def _nominatim_one(row: dict | None, lat: float | None, lng: float | None) -> Place | None:
    if not isinstance(row, dict):
        return None
    try:
        plat = float(row.get("lat") if lat is None else lat)
        plng = float(row.get("lon") if lng is None else lng)
    except (TypeError, ValueError):
        return None
    if not valid_coord(plat, plng):
        return None
    addr = row.get("address") if isinstance(row.get("address"), dict) else {}
    number = str(addr.get("house_number") or "").strip()
    street = str(addr.get("road") or addr.get("pedestrian") or "").strip()
    name = str(row.get("name") or addr.get("building") or "").strip()
    city = str(addr.get("city") or addr.get("town") or addr.get("village") or "").strip()
    if street and number:
        line = f"{street} {number}"
    elif street:
        line = street
    elif name:
        line = name
    else:
        line = str(row.get("display_name") or "").split(",")[0].strip()
    if not line:
        return None
    return Place(plat, plng, line, city)


_FIXTURE = FixtureProvider()
_PHOTON = PhotonProvider()


def provider() -> GeoProvider:
    if settings.geo_provider == "fixture":
        return _FIXTURE
    return _PHOTON


def resolve_point(q: str, *, lat: float | None = None, lng: float | None = None) -> Place | None:
    hits = provider().search(q, lat=lat, lng=lng)
    return hits[0] if hits else None


def lang_for(code: str | None) -> str:
    if (code or "").startswith("ru") or (code or "").startswith("kk"):
        return "ru"
    return "en"
