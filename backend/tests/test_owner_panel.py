"""A restaurant's own owner runs its panel — not only the platform.

Owners and staff are ordinary accounts with a membership. Every venue-level
endpoint the app's panel calls must let them in for their own venue, keep them
out of anyone else's, and keep what the platform decides (plan, billing) the
platform's.
"""

import secrets

import pytest


@pytest.fixture
def owner(client) -> dict:
    r = client.post(
        "/api/v1/partners/apply",
        json={
            "venue_name": f"Owner Panel {secrets.token_hex(2)}", "cuisine": "Kazakh",
            "contact_name": "Owner Name", "email": f"panel.{secrets.token_hex(3)}@cafe.kz",
            "phone": "+77011234567", "password": "ownerpass123", "has_couriers": True,
        },
    )
    body = r.json()
    return {"id": body["restaurant_id"], "headers": {"Authorization": f"Bearer {body['access_token']}"}}


def test_the_owner_opens_their_venue(client, owner):
    r = client.get(f"/api/v1/admin/restaurants/{owner['id']}", headers=owner["headers"])

    assert r.status_code == 200 and r.json()["id"] == owner["id"]


def test_but_not_someone_elses(client, owner):
    assert client.get("/api/v1/admin/restaurants/1", headers=owner["headers"]).status_code in (403, 404)


def test_the_owner_edits_their_settings(client, owner):
    r = client.patch(
        f"/api/v1/admin/restaurants/{owner['id']}",
        json={"description": "Семейное кафе", "delivery_time_min": 40},
        headers=owner["headers"],
    )

    assert r.status_code == 200, r.text


def test_the_owner_cannot_change_their_own_plan_or_billing(client, owner):
    for field, value in (("plan_code", "premium"), ("billing_status", "active")):
        r = client.patch(
            f"/api/v1/admin/restaurants/{owner['id']}", json={field: value}, headers=owner["headers"]
        )
        assert r.status_code == 403, field


def test_a_guest_cannot_edit_a_venue(client, auth, owner):
    r = client.patch(f"/api/v1/admin/restaurants/{owner['id']}", json={"name": "Mine"}, headers=auth)

    assert r.status_code in (403, 404)


def test_the_owner_runs_promo_codes_on_a_plan_with_them(client, admin, owner):
    # Approval starts the Pro trial, which includes promotions.
    client.post(f"/api/v1/admin/restaurants/{owner['id']}/approval", json={"approve": True}, headers=admin)
    base = f"/api/v1/admin/restaurants/{owner['id']}/promos"

    made = client.post(base, json={"code": "HELLO10", "kind": "percent", "value": 10}, headers=owner["headers"])
    assert made.status_code == 201, made.text
    pid = made.json()["id"]
    assert [p["code"] for p in client.get(base, headers=owner["headers"]).json()] == ["HELLO10"]
    assert client.patch(f"/api/v1/admin/promos/{pid}", json={"value": 15}, headers=owner["headers"]).status_code == 200
    assert client.delete(f"/api/v1/admin/promos/{pid}", headers=owner["headers"]).status_code == 204


def test_nobody_else_touches_those_promo_codes(client, admin, auth, owner):
    client.post(f"/api/v1/admin/restaurants/{owner['id']}/approval", json={"approve": True}, headers=admin)
    pid = client.post(
        f"/api/v1/admin/restaurants/{owner['id']}/promos",
        json={"code": "MINE20", "kind": "percent", "value": 20},
        headers=owner["headers"],
    ).json()["id"]

    assert client.patch(f"/api/v1/admin/promos/{pid}", json={"value": 90}, headers=auth).status_code in (403, 404)
    assert client.delete(f"/api/v1/admin/promos/{pid}", headers=auth).status_code in (403, 404)
    assert client.get(f"/api/v1/admin/restaurants/{owner['id']}/promos", headers=auth).status_code in (403, 404)
