"""Cities, managed by the platform admin instead of in code.

A new city must be reachable on the site the moment it has a venue, must not
take a name the site already uses for a page, and must keep its address once
people have it.
"""

import itertools

ADMIN = "/api/v1/admin/cities"
_n = itertools.count(1)


def _slug() -> str:
    return f"town-{next(_n)}"


def _create(client, admin, **extra) -> dict:
    body = {"slug": _slug(), "name": "Шымкент", "name_in": "Шымкенте", **extra}
    r = client.post(ADMIN, json=body, headers=admin)
    assert r.status_code == 201, r.text
    return r.json()


def test_only_the_platform_admin_manages_cities(client, auth):
    assert client.get(ADMIN, headers=auth).status_code == 403
    assert client.post(ADMIN, json={"slug": "x-town", "name": "X"}, headers=auth).status_code == 403


def test_a_new_city_is_public_with_its_declined_name(client, admin):
    city = _create(client, admin)

    assert city["venues"] == 0 and city["utc_offset_min"] == 300
    assert city["slug"] in [c["slug"] for c in client.get("/api/v1/cities").json()]
    page = client.get(f"/{city['slug']}/")
    assert page.status_code == 200
    assert "Доставка еды в Шымкенте" in page.text


def test_a_venue_can_be_placed_in_it_and_is_counted(client, admin):
    city = _create(client, admin)
    client.post(
        "/api/v1/admin/restaurants",
        json={"name": "Shym Grill", "cuisine": "Test", "city_slug": city["slug"]},
        headers=admin,
    )

    listed = {c["slug"]: c for c in client.get(ADMIN, headers=admin).json()}

    assert listed[city["slug"]]["venues"] == 1


def test_a_name_the_site_already_uses_is_refused(client, admin):
    r = client.post(ADMIN, json={"slug": "cart", "name": "Корзина"}, headers=admin)

    assert r.status_code == 422
    assert "already a path" in r.json()["detail"]


def test_an_address_is_taken_once(client, admin):
    city = _create(client, admin)

    r = client.post(ADMIN, json={"slug": city["slug"], "name": "Другой"}, headers=admin)

    assert r.status_code == 409


def test_an_address_must_be_a_url_segment(client, admin):
    for bad in ("Shymkent", "шымкент", "a", "-x", "x/y"):
        assert client.post(ADMIN, json={"slug": bad, "name": "X"}, headers=admin).status_code == 422, bad


def test_switching_a_city_off_hides_it_but_the_admin_still_sees_it(client, admin):
    city = _create(client, admin)

    r = client.patch(f"{ADMIN}/{city['id']}", json={"is_active": False}, headers=admin)

    assert r.status_code == 200 and r.json()["is_active"] is False
    assert city["slug"] not in [c["slug"] for c in client.get("/api/v1/cities").json()]
    assert client.get(f"/{city['slug']}/").status_code == 404
    assert city["slug"] in [c["slug"] for c in client.get(ADMIN, headers=admin).json()]


def test_the_address_cannot_be_changed(client, admin):
    city = _create(client, admin)

    r = client.patch(f"{ADMIN}/{city['id']}", json={"slug": "renamed", "name": "Новое"}, headers=admin)

    assert r.status_code == 200
    assert r.json()["slug"] == city["slug"]
    assert r.json()["name"] == "Новое"


def test_an_unknown_city_is_404(client, admin):
    assert client.patch(f"{ADMIN}/999999", json={"name": "X"}, headers=admin).status_code == 404
