"""What delivery costs for this basket, to this door.

Straight-line distance times a road factor, not an OSRM call: checkout must not
wait on a routing service, and the customer has to see the same number the
server will charge. The factor is the usual city fudge between crow-flight and
what a scooter actually rides.
"""

from __future__ import annotations

from dataclasses import dataclass

from app.core.geo import haversine_m, valid_coord
from app.models import Restaurant

# Almaty grid: roads run ~30% longer than the straight line.
ROAD_FACTOR = 1.3

# Nobody is ordering lunch from another continent. A point this far away is a
# geocoding miss ("Dostyk 1, office 300" lands in the wrong country), and
# billing a fantasy distance is worse than admitting we do not know.
SANE_MAX_KM = 100.0


@dataclass(frozen=True)
class DeliveryQuote:
    fee: float
    distance_km: float | None
    base_fee: float
    per_km: float
    free_km: float
    max_km: float | None
    out_of_range: bool
    # False when we had no trustworthy point and fell back to the base fee.
    precise: bool = True

    def as_dict(self) -> dict:
        return {
            "fee": self.fee,
            "distance_km": self.distance_km,
            "base_fee": self.base_fee,
            "per_km": self.per_km,
            "free_km": self.free_km,
            "max_km": self.max_km,
            "out_of_range": self.out_of_range,
            "precise": self.precise,
        }


def road_km(
    a_lat: float | None,
    a_lng: float | None,
    b_lat: float | None,
    b_lng: float | None,
) -> float | None:
    """Rough riding distance in km, or None when either end is unknown."""
    if not valid_coord(a_lat, a_lng) or not valid_coord(b_lat, b_lng):
        return None
    metres = haversine_m(a_lat, a_lng, b_lat, b_lng) * ROAD_FACTOR
    return round(metres / 1000, 2)


def quote(
    restaurant: Restaurant,
    dest_lat: float | None,
    dest_lng: float | None,
) -> DeliveryQuote:
    base = float(restaurant.delivery_fee or 0)
    per_km = float(getattr(restaurant, "delivery_fee_per_km", 0) or 0)
    free_km = float(getattr(restaurant, "delivery_free_km", 0) or 0)
    max_km = getattr(restaurant, "delivery_max_km", None)
    max_km = float(max_km) if max_km else None

    km = road_km(restaurant.lat, restaurant.lng, dest_lat, dest_lng)
    if km is not None and km > SANE_MAX_KM:
        # A bad geocode, not a customer. Quote the base and say it is a guess.
        return DeliveryQuote(
            fee=round(base, 2),
            distance_km=None,
            base_fee=round(base, 2),
            per_km=per_km,
            free_km=free_km,
            max_km=max_km,
            out_of_range=False,
            precise=False,
        )

    # No distance to price on, or a flat-fee restaurant: charge the base.
    if km is None or per_km <= 0:
        return DeliveryQuote(
            fee=round(base, 2),
            distance_km=km,
            base_fee=round(base, 2),
            per_km=per_km,
            free_km=free_km,
            max_km=max_km,
            out_of_range=bool(max_km and km is not None and km > max_km),
            precise=km is not None,
        )

    billable = max(0.0, km - free_km)
    fee = base + billable * per_km
    return DeliveryQuote(
        # Tenge has no coins in practice; round to something a courier can take.
        fee=float(round(fee / 10) * 10),
        distance_km=km,
        base_fee=round(base, 2),
        per_km=per_km,
        free_km=free_km,
        max_km=max_km,
        out_of_range=bool(max_km and km > max_km),
    )
