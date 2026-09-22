"""Delivery priced by distance: the cart quotes it, the server charges it."""

import pytest

from app.services.delivery_pricing import ROAD_FACTOR, quote, road_km


class _Venue:
    """Minimal stand-in; the pricer only reads tariff fields and coordinates."""

    def __init__(self, **kw):
        self.lat = kw.get("lat", 43.2389)
        self.lng = kw.get("lng", 76.9454)
        self.delivery_fee = kw.get("delivery_fee", 500.0)
        self.delivery_fee_per_km = kw.get("delivery_fee_per_km", 0.0)
        self.delivery_free_km = kw.get("delivery_free_km", 0.0)
        self.delivery_max_km = kw.get("delivery_max_km")


def test_a_flat_fee_restaurant_is_untouched_by_distance():
    """per_km = 0 must behave exactly as the flat fee always did."""
    venue = _Venue(delivery_fee=700, delivery_fee_per_km=0)
    near = quote(venue, 43.2400, 76.9460)
    far = quote(venue, 43.3500, 77.0500)
    assert near.fee == 700 and far.fee == 700


def test_distance_is_billed_past_the_included_kilometres():
    venue = _Venue(delivery_fee=500, delivery_fee_per_km=100, delivery_free_km=2)
    q = quote(venue, 43.2700, 76.9454)
    assert q.distance_km is not None and q.distance_km > 2
    expected = 500 + (q.distance_km - 2) * 100
    assert q.fee == pytest.approx(round(expected / 10) * 10, abs=10)


def test_inside_the_free_radius_costs_only_the_base():
    venue = _Venue(delivery_fee=500, delivery_fee_per_km=100, delivery_free_km=5)
    q = quote(venue, 43.2395, 76.9460)  # a few hundred metres away
    assert q.fee == 500


def test_an_address_without_coordinates_falls_back_to_the_base_fee():
    venue = _Venue(delivery_fee=500, delivery_fee_per_km=100)
    q = quote(venue, None, None)
    assert q.fee == 500 and q.distance_km is None and q.out_of_range is False


def test_out_of_range_is_flagged_but_still_quoted():
    venue = _Venue(delivery_fee_per_km=100, delivery_max_km=5)
    q = quote(venue, 43.4000, 77.1000)
    assert q.out_of_range is True
    assert q.distance_km > 5


def test_road_km_applies_the_road_factor_not_the_crow_line():
    straight = road_km(43.2389, 76.9454, 43.2489, 76.9454) / ROAD_FACTOR
    assert straight == pytest.approx(1.11, abs=0.05)  # ~0.01 degree of latitude


def test_quote_endpoint_answers_before_the_order_exists(client):
    r = client.get("/api/v1/restaurants/1/delivery-quote?lat=43.2700&lng=76.9454")
    assert r.status_code == 200
    body = r.json()
    assert {"fee", "distance_km", "base_fee", "per_km", "out_of_range"} <= set(body)
    assert body["fee"] >= body["base_fee"]


def test_quote_endpoint_404s_for_a_restaurant_that_is_not_there(client):
    assert client.get("/api/v1/restaurants/9999/delivery-quote?lat=43.2&lng=76.9").status_code == 404


def test_the_server_charges_what_it_quoted(client, auth):
    """A customer must not be able to talk the fee down by sending their own."""
    quoted = client.get(
        "/api/v1/restaurants/1/delivery-quote?lat=43.2700&lng=76.9454"
    ).json()
    menu = client.get("/api/v1/restaurants/1/menu").json()
    placed = client.post(
        "/api/v1/orders",
        json={
            "restaurant_id": 1,
            "address": "Somewhere north",
            "dest_lat": 43.2700,
            "dest_lng": 76.9454,
            "items": [{"menu_item_id": menu[0]["id"], "quantity": 1}],
            "pay_method": "cash",
        },
        headers=auth,
    )
    assert placed.status_code == 201, placed.text
    assert placed.json()["delivery_fee"] == quoted["fee"]


def test_an_admin_can_retune_the_tariff(client, admin):
    r = client.patch(
        "/api/v1/admin/restaurants/1",
        json={"delivery_fee_per_km": 250, "delivery_free_km": 1, "delivery_max_km": 9},
        headers=admin,
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["delivery_fee_per_km"] == 250
    assert body["delivery_free_km"] == 1
    assert body["delivery_max_km"] == 9
    # and the quote immediately follows the new tariff
    q = client.get("/api/v1/restaurants/1/delivery-quote?lat=43.2700&lng=76.9454").json()
    assert q["per_km"] == 250 and q["max_km"] == 9


def test_an_address_beyond_the_radius_is_refused_with_the_numbers(client, auth, admin):
    set_radius = client.patch(
        "/api/v1/admin/restaurants/1",
        json={"delivery_max_km": 5},
        headers=admin,
    )
    assert set_radius.status_code == 200
    assert set_radius.json()["delivery_max_km"] == 5
    menu = client.get("/api/v1/restaurants/1/menu").json()
    r = client.post(
        "/api/v1/orders",
        json={
            "restaurant_id": 1,
            "address": "Too far",
            "dest_lat": 43.4000,
            "dest_lng": 77.1000,
            "items": [{"menu_item_id": menu[0]["id"], "quantity": 1}],
            "pay_method": "cash",
        },
        headers=auth,
    )
    assert r.status_code == 400
    assert "km" in r.json()["detail"]


def test_a_wild_geocode_is_not_billed_as_a_long_ride():
    """'Dostyk 1, office 300' once geocoded 15000 km away and quoted 1.8M ₸."""
    venue = _Venue(delivery_fee=500, delivery_fee_per_km=120, delivery_free_km=2)
    q = quote(venue, -23.5, -46.6)  # São Paulo
    assert q.fee == 500
    assert q.distance_km is None
    assert q.precise is False
    assert q.out_of_range is False  # we do not know where they are, so we do not refuse


def test_a_point_inside_the_sane_bound_is_still_precise():
    venue = _Venue(delivery_fee=500, delivery_fee_per_km=120, delivery_free_km=2)
    q = quote(venue, 43.2700, 76.9454)
    assert q.precise is True and q.distance_km is not None


def test_a_missing_point_is_not_claimed_as_precise():
    venue = _Venue(delivery_fee=500, delivery_fee_per_km=120)
    assert quote(venue, None, None).precise is False


def test_the_quote_endpoint_reports_whether_it_could_be_sure(client):
    body = client.get(
        "/api/v1/restaurants/1/delivery-quote?lat=43.2700&lng=76.9454"
    ).json()
    assert body["precise"] is True
