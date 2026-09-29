"""Cities: every venue lives in one, and a city's list shows only its own.

The failure these guard against is quiet: a venue with no city, or in the
wrong one, still exists and still takes orders through a direct link — it just
never appears where a diner in that city is looking.
"""

import pytest
from sqlalchemy import select

from app.db.seed import ensure_cities
from app.db.session import SessionLocal
from app.main import app
from app.models import City, Restaurant
from app.services import cities

CITIES = "/api/v1/cities"
LIST = "/api/v1/restaurants"
ADMIN = "/api/v1/admin/restaurants"


def _ids(client, city: str | None = None) -> set[int]:
    params = {"city": city} if city else None
    r = client.get(LIST, params=params)
    assert r.status_code == 200, r.text
    return {x["id"] for x in r.json()}


def _create(client, admin, name: str, **extra) -> dict:
    r = client.post(ADMIN, json={"name": name, "cuisine": "Test", **extra}, headers=admin)
    assert r.status_code == 201, r.text
    return r.json()


class TestTheList:
    def test_lists_both_launch_cities_default_first(self, client):
        r = client.get(CITIES)

        assert r.status_code == 200
        slugs = [c["slug"] for c in r.json()]
        assert slugs[:2] == ["almaty", "astana"]
        almaty = r.json()[0]
        assert almaty["name"] == "Алматы"
        assert almaty["lat"] and almaty["lng"]

    def test_a_switched_off_city_leaves_the_list_and_its_venues_with_it(self, client):
        with SessionLocal() as db:
            astana = db.scalar(select(City).where(City.slug == "astana"))
            astana.is_active = False
            db.commit()
        try:
            assert "astana" not in [c["slug"] for c in client.get(CITIES).json()]
            assert client.get(LIST, params={"city": "astana"}).json() == []
        finally:
            with SessionLocal() as db:
                db.scalar(select(City).where(City.slug == "astana")).is_active = True
                db.commit()


class TestVenuesInCities:
    def test_every_seeded_venue_was_backfilled_into_the_default_city(self, client):
        for venue in client.get(LIST).json():
            if venue["name"] in {"Bao Bar", "Pizza Roma", "Burger Lab"}:
                assert venue["city_slug"] == "almaty"
                assert venue["city_name"] == "Алматы"

    def test_a_city_filter_shows_only_that_citys_venues(self, client):
        almaty = _ids(client, "almaty")

        assert almaty
        assert not almaty & _ids(client, "astana")

    def test_no_filter_still_means_every_city(self, client, admin):
        """The app predates cities and asks without one; it must keep working."""
        there = _create(client, admin, "Everywhere Test", city_slug="astana")

        assert there["id"] in _ids(client)

    def test_an_unknown_city_is_an_empty_list_not_every_venue(self, client):
        # Falling back to "everything" would show Almaty's menus under a URL
        # that claims to be some other city.
        assert client.get(LIST, params={"city": "atlantis"}).json() == []

    def test_detail_says_which_city(self, client):
        venue = next(iter(_ids(client, "almaty")))

        detail = client.get(f"{LIST}/{venue}").json()

        assert detail["city_slug"] == "almaty"


class TestAdminPlacesVenues:
    def test_a_new_venue_without_a_city_lands_in_the_default_one(self, client, admin):
        made = _create(client, admin, "Default City Cafe")

        assert made["city_slug"] == "almaty"
        assert made["id"] in _ids(client, "almaty")

    def test_a_new_venue_can_be_placed_in_another_city(self, client, admin):
        made = _create(client, admin, "Astana Cafe", city_slug="astana")

        assert made["city_slug"] == "astana"
        assert made["id"] in _ids(client, "astana")
        assert made["id"] not in _ids(client, "almaty")

    def test_an_unknown_city_is_refused_not_replaced_by_the_default(self, client, admin):
        r = client.post(
            ADMIN,
            json={"name": "Nowhere Cafe", "cuisine": "Test", "city_slug": "atlantis"},
            headers=admin,
        )

        assert r.status_code == 400
        assert "city" in r.json()["detail"].lower()

    def test_a_venue_can_move_city(self, client, admin):
        made = _create(client, admin, "Moving Cafe")

        r = client.patch(f"{ADMIN}/{made['id']}", json={"city_slug": "astana"}, headers=admin)

        assert r.status_code == 200, r.text
        assert r.json()["city_slug"] == "astana"
        assert made["id"] in _ids(client, "astana")
        assert made["id"] not in _ids(client, "almaty")

    def test_moving_to_an_unknown_city_changes_nothing(self, client, admin):
        made = _create(client, admin, "Staying Cafe", city_slug="astana")

        r = client.patch(f"{ADMIN}/{made['id']}", json={"city_slug": "atlantis"}, headers=admin)

        assert r.status_code == 400
        assert client.get(f"{LIST}/{made['id']}").json()["city_slug"] == "astana"

    def test_only_admins_place_venues(self, client, auth):
        r = client.patch(f"{ADMIN}/1", json={"city_slug": "astana"}, headers=auth)

        assert r.status_code == 403


class TestBoot:
    def test_the_boot_backfill_never_moves_a_venue_someone_placed(self, client, admin):
        made = _create(client, admin, "Placed Cafe", city_slug="astana")

        ensure_cities()

        assert client.get(f"{LIST}/{made['id']}").json()["city_slug"] == "astana"

    def test_the_boot_seed_is_idempotent(self, client):
        before = [c["slug"] for c in client.get(CITIES).json()]

        assert ensure_cities() == 0
        assert [c["slug"] for c in client.get(CITIES).json()] == before

    def test_a_venue_orphaned_by_a_deleted_city_is_picked_up_on_next_boot(self, client, admin):
        made = _create(client, admin, "Orphan Cafe")
        with SessionLocal() as db:
            db.get(Restaurant, made["id"]).city_id = None
            db.commit()

        ensure_cities()

        assert client.get(f"{LIST}/{made['id']}").json()["city_slug"] == "almaty"


def _paths(routes, prefix: str = ""):
    """Every path the app answers, through included routers too."""
    for route in routes:
        if hasattr(route, "path"):
            yield prefix + route.path
        else:  # FastAPI keeps an included router whole, with its prefix aside
            ctx = route.include_context
            yield from _paths(ctx.included_router.routes, prefix + (ctx.prefix or ""))


class TestSlugs:
    @pytest.mark.parametrize("slug", ["cart", "api", "r", "t", "sitemap.xml"])
    def test_a_city_cannot_take_a_path_the_site_already_serves(self, slug):
        with pytest.raises(cities.ReservedSlugError):
            cities.check_slug(slug)

    def test_an_ordinary_city_name_is_fine(self):
        assert cities.check_slug("shymkent") == "shymkent"

    def test_every_top_level_path_the_app_serves_is_reserved(self):
        """A new page added without reserving its name could be shadowed by, or
        shadow, a city of the same name. This catches it the day it's added."""
        served = {
            path.strip("/").split("/", 1)[0] for path in _paths(app.routes)
        } - {""}
        # The walk leans on router internals; if they change shape it must fail
        # loudly here, not pass on an empty set.
        assert {"api", "cart", "sitemap.xml"} <= served

        missing = {p for p in served if not p.startswith("{")} - cities.RESERVED_SLUGS
        assert not missing, f"add to RESERVED_SLUGS: {sorted(missing)}"

    def test_the_seeded_cities_are_not_reserved(self, client):
        for c in client.get(CITIES).json():
            assert c["slug"] not in cities.RESERVED_SLUGS
