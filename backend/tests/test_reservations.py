from datetime import UTC, datetime, timedelta


def _when(hours=3):
    return (datetime.now(UTC) + timedelta(hours=hours)).isoformat()


def _floor(client, admin, restaurant_id=1, name="Book Hall"):
    r = client.post(
        f"/api/v1/admin/restaurants/{restaurant_id}/floors",
        json={"name": name, "template": "cafe"},
        headers=admin,
    )
    assert r.status_code == 201, r.text
    return r.json()


def _object(client, admin, floor_id, table_id):
    layout = client.get(f"/api/v1/admin/floors/{floor_id}", headers=admin).json()
    return next(o for o in layout["objects"] if o["id"] == table_id)


def _first_table(floor):
    return next(o["id"] for o in floor["objects"] if str(o.get("kind", "")).startswith("table_"))


def test_restaurant_flag_follows_plan(client, admin):
    listed = client.get("/api/v1/restaurants").json()
    bao = next(r for r in listed if r["id"] == 1)
    assert bao["reservations"] is True
    client.patch("/api/v1/admin/restaurants/1", json={"plan_code": "basic"}, headers=admin)
    assert client.get("/api/v1/restaurants/1").json()["reservations"] is False
    client.patch("/api/v1/admin/restaurants/1", json={"plan_code": "pro"}, headers=admin)


def test_book_table_confirms_and_blocks_overlap(client, auth, admin):
    floor = _floor(client, admin)
    tid = _first_table(floor)
    listed = client.get("/api/v1/restaurants/1/tables")
    assert listed.status_code == 200, listed.text
    assert any(t["id"] == tid for t in listed.json())
    when = _when()
    first = client.post(
        "/api/v1/reservations",
        json={
            "restaurant_id": 1,
            "table_object_id": tid,
            "name": "Aida",
            "phone": "+77001230000",
            "guests": 2,
            "starts_at": when,
        },
        headers=auth,
    )
    assert first.status_code == 201, first.text
    body = first.json()
    assert body["status"] == "confirmed"
    assert body["table_object_id"] == tid

    clash = client.post(
        "/api/v1/reservations",
        json={
            "restaurant_id": 1,
            "table_object_id": tid,
            "name": "Bek",
            "guests": 2,
            "starts_at": when,
        },
        headers=auth,
    )
    assert clash.status_code == 409
    assert _object(client, admin, floor["id"], tid)["status"] == "reserved"

    cancelled = client.post(f"/api/v1/reservations/{body['id']}/cancel", headers=auth)
    assert cancelled.status_code == 200, cancelled.text
    assert cancelled.json()["status"] == "cancelled"
    assert _object(client, admin, floor["id"], tid)["status"] == "available"


def test_hold_without_table_stays_requested(client, auth, admin):
    _floor(client, admin, name="Hold Hall")
    r = client.post(
        "/api/v1/reservations",
        json={"restaurant_id": 1, "name": "Dana", "guests": 4, "starts_at": _when(4)},
        headers=auth,
    )
    assert r.status_code == 201, r.text
    assert r.json()["status"] == "requested"
    assert r.json()["table_object_id"] is None


def test_too_soon_rejected(client, auth):
    soon = (datetime.now(UTC) + timedelta(minutes=5)).isoformat()
    r = client.post(
        "/api/v1/reservations",
        json={"restaurant_id": 1, "name": "Aida", "guests": 2, "starts_at": soon},
        headers=auth,
    )
    assert r.status_code == 400


def test_basic_plan_blocks_booking(client, auth, admin):
    created = client.post(
        "/api/v1/admin/restaurants",
        json={"name": "Solo Tables", "cuisine": "Cafe", "delivery_fee": 0, "delivery_time_min": 15},
        headers=admin,
    )
    assert created.status_code == 201, created.text
    rid = created.json()["id"]
    client.patch(f"/api/v1/admin/restaurants/{rid}", json={"plan_code": "basic"}, headers=admin)
    blocked = client.post(
        "/api/v1/reservations",
        json={"restaurant_id": rid, "name": "Aida", "guests": 2, "starts_at": _when()},
        headers=auth,
    )
    assert blocked.status_code == 403
    assert client.get(f"/api/v1/restaurants/{rid}/tables").status_code == 403


def test_kitchen_seats_guest(client, auth, admin):
    floor = _floor(client, admin, name="Seat Hall")
    tid = _first_table(floor)
    when = _when(5)
    booked = client.post(
        "/api/v1/reservations",
        json={
            "restaurant_id": 1,
            "table_object_id": tid,
            "name": "Aida",
            "guests": 2,
            "starts_at": when,
        },
        headers=auth,
    )
    assert booked.status_code == 201, booked.text
    rid = booked.json()["id"]
    seated = client.patch(
        f"/api/v1/admin/reservations/{rid}",
        json={"status": "seated"},
        headers=admin,
    )
    assert seated.status_code == 200, seated.text
    assert seated.json()["status"] == "seated"
    assert _object(client, admin, floor["id"], tid)["status"] == "occupied"

    client.patch(f"/api/v1/admin/reservations/{rid}", json={"status": "cancelled"}, headers=admin)
    assert _object(client, admin, floor["id"], tid)["status"] == "occupied"


def test_admin_walk_in_skips_lead(client, admin):
    _floor(client, admin, name="Walk Hall")
    now = datetime.now(UTC).isoformat()
    r = client.post(
        "/api/v1/admin/restaurants/1/reservations",
        json={"restaurant_id": 1, "name": "Walk-in", "guests": 2, "starts_at": now},
        headers=admin,
    )
    assert r.status_code == 201, r.text
    assert r.json()["status"] == "confirmed"
    mine = client.get("/api/v1/admin/restaurants/1/reservations", headers=admin)
    assert mine.status_code == 200
    assert any(row["id"] == r.json()["id"] for row in mine.json())
