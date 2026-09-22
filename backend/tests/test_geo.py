from app.core.geo import FixtureProvider, haversine_m, valid_coord


def test_haversine_almaty_block_is_short():
    metres = haversine_m(43.2389, 76.9455, 43.2565, 76.9281)
    assert 2000 < metres < 4000


def test_geo_search_and_reverse_offline(client):
    hits = client.get("/api/v1/geo/search", params={"q": "Abay"}).json()
    assert hits
    assert hits[0]["line"] == "Abay 10"
    assert hits[0]["lat"] == 43.238949
    pin = client.get(
        "/api/v1/geo/reverse",
        params={"lat": 43.239, "lng": 76.945},
    ).json()
    assert pin["line"] == "Abay 10"
    route = client.get(
        "/api/v1/geo/route",
        params={
            "from_lat": 43.25654,
            "from_lng": 76.92812,
            "to_lat": 43.238949,
            "to_lng": 76.945465,
        },
    ).json()
    assert route["distance_m"] > 1000
    assert len(route["points"]) >= 2
    assert client.get("/api/v1/geo/search", params={"q": "zzzz"}).json() == []


def test_restaurants_have_pins(client):
    listed = client.get("/api/v1/restaurants").json()
    bao = next(r for r in listed if r["name"] == "Bao Bar")
    assert bao["lat"] == 43.25654
    assert bao["lng"] == 76.92812


def test_delivery_order_keeps_dropoff_and_courier_ping(client, auth, admin, courier):
    menu = client.get("/api/v1/restaurants/1/menu").json()
    r = client.post(
        "/api/v1/orders",
        json={
            "restaurant_id": 1,
            "address": "Abay 10",
            "dest_lat": 43.238949,
            "dest_lng": 76.945465,
            "items": [{"menu_item_id": menu[0]["id"], "quantity": 1}],
        },
        headers=auth,
    )
    assert r.status_code == 201, r.text
    order = r.json()
    assert order["dest_lat"] == 43.238949
    assert order["pickup_lat"] == 43.25654
    assert order["courier_lat"] is None

    oid = order["id"]
    assert client.patch(
        f"/api/v1/orders/{oid}/status", json={"status": "confirmed"}, headers=admin
    ).status_code == 200
    assert client.post(f"/api/v1/orders/{oid}/accept", headers=courier).status_code == 200
    ping = client.post(
        "/api/v1/courier/location",
        json={"lat": 43.24, "lng": 76.93, "heading": 90},
        headers=courier,
    )
    assert ping.status_code == 204, ping.text
    live = client.get(f"/api/v1/orders/{oid}", headers=auth).json()
    assert live["courier_lat"] == 43.24
    assert live["courier_lng"] == 76.93
    assert live["courier_heading"] == 90
    assert client.post(
        "/api/v1/courier/location",
        json={"lat": 43.24, "lng": 76.93},
        headers=auth,
    ).status_code == 403


def test_saved_address_keeps_pin(client, auth):
    r = client.post(
        "/api/v1/me/addresses",
        json={"label": "Home", "line": "Abay 10", "lat": 43.238949, "lng": 76.945465},
        headers=auth,
    )
    assert r.status_code == 201, r.text
    assert r.json()["lat"] == 43.238949


def test_fixture_provider_unit():
    geo = FixtureProvider()
    assert geo.search("dostyk")[0].line == "Dostyk 1"
    assert valid_coord(43.2, 76.9)
    assert not valid_coord(0, 0)
    assert not valid_coord(None, 76.9)
