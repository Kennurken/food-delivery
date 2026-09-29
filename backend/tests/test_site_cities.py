"""City pages on the public site.

A city page must show that city's venues and only those, must say which city
it is about in words a Russian reader expects ("в Астане", not "в Астана"),
and — being a one-segment catch-all — must never swallow a real page.
"""

import itertools
import json
import re

import pytest
from sqlalchemy import select

from app.db.session import SessionLocal
from app.models import City, Restaurant

_names = itertools.count(1)


def _visible(html: str) -> str:
    body = re.sub(r"<script.*?</script>", "", html, flags=re.DOTALL | re.IGNORECASE)
    body = re.sub(r"<style.*?</style>", "", body, flags=re.DOTALL | re.IGNORECASE)
    return re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", body)).strip()


def _canonical(html: str) -> str:
    match = re.search(r'<link rel="canonical" href="([^"]*)"', html)
    assert match, "no canonical link"
    return match.group(1)


@pytest.fixture
def astana_venue(client, admin) -> dict:
    """A fresh venue in Astana, with its site slug. Each test gets its own, so
    none depends on what another test left behind."""
    name = f"Astana Noodles {next(_names)}"
    r = client.post(
        "/api/v1/admin/restaurants",
        json={"name": name, "cuisine": "Test", "city_slug": "astana"},
        headers=admin,
    )
    assert r.status_code == 201, r.text
    with SessionLocal() as db:
        slug = db.get(Restaurant, r.json()["id"]).slug
    return {"name": name, "slug": slug}


@pytest.fixture
def city(client):
    """Make a throwaway city; switched off again afterwards so the switcher and
    the sitemap other tests see are unchanged."""
    made: list[str] = []

    def make(slug: str, name: str, *, active: bool = True) -> None:
        with SessionLocal() as db:
            row = db.scalar(select(City).where(City.slug == slug))
            if row is None:
                row = City(slug=slug, name=name, sort_order=50)
                db.add(row)
            row.is_active = active
            db.commit()
        made.append(slug)

    yield make
    with SessionLocal() as db:
        for slug in made:
            db.scalar(select(City).where(City.slug == slug)).is_active = False
        db.commit()


class TestCityLanding:
    def test_the_default_city_has_one_url_and_it_is_the_root(self, client):
        r = client.get("/almaty/", follow_redirects=False)

        assert r.status_code == 301
        assert r.headers["location"] == "/"

    def test_a_city_page_shows_its_venues_and_only_those(self, client, astana_venue):
        r = client.get("/astana/")

        assert r.status_code == 200
        text = _visible(r.text)
        assert astana_venue["name"] in text
        assert "Bao Bar" not in text
        assert "Доставка еды в Астане" in text
        assert _canonical(r.text).endswith("/astana/")

    def test_the_root_stays_the_default_citys(self, client, astana_venue):
        text = _visible(client.get("/").text)

        assert "Bao Bar" in text
        assert astana_venue["name"] not in text
        assert "Доставка еды в Алматы" in text

    def test_an_unknown_city_is_the_site_404(self, client):
        r = client.get("/atlantis/")

        assert r.status_code == 404
        assert r.headers["content-type"].startswith("text/html")
        assert "Страница не найдена" in r.text

    def test_a_switched_off_city_is_gone(self, client, city):
        city("oral", "Орал", active=False)

        assert client.get("/oral/").status_code == 404

    def test_a_city_with_no_venues_says_so_and_stays_out_of_the_index(self, client, city):
        city("taraz", "Тараз")

        r = client.get("/taraz/")

        assert r.status_code == 200
        assert "Пока нет ресторанов в Тараз" in _visible(r.text)
        assert '<meta name="robots" content="noindex">' in r.text
        assert "/taraz/" not in client.get("/sitemap.xml").text

    def test_a_city_with_venues_is_indexable(self, client, astana_venue):
        assert 'name="robots"' not in client.get("/astana/").text


class TestSitemap:
    def test_lists_a_city_once_it_has_a_venue_but_never_the_default(
        self, client, astana_venue
    ):
        body = client.get("/sitemap.xml").text

        assert "/astana/</loc>" in body
        assert "/almaty/</loc>" not in body


class TestRestaurantPage:
    def test_names_the_venues_own_city(self, client, astana_venue):
        r = client.get(f"/r/{astana_venue['slug']}/")

        assert r.status_code == 200
        title = re.search(r"<title>(.*?)</title>", r.text).group(1)
        assert "доставка в Астане" in title
        assert "Test · Астана" in _visible(r.text)

    def test_structured_data_carries_the_city(self, client, astana_venue):
        r = client.get(f"/r/{astana_venue['slug']}/")

        block = re.search(
            r'<script type="application/ld\+json">(.*?)</script>', r.text, re.DOTALL
        )
        assert block, "no JSON-LD"
        assert json.loads(block.group(1))["address"]["addressLocality"] == "Астана"

    def test_an_almaty_venue_still_says_almaty(self, client):
        r = client.get("/r/bao-bar/")

        assert "доставка в Алматы" in re.search(r"<title>(.*?)</title>", r.text).group(1)


class TestSwitcher:
    def test_every_live_city_is_linked_and_the_current_one_is_marked(self, client):
        html = client.get("/").text

        nav = re.search(r'<nav class="cities".*?</nav>', html, re.DOTALL)
        assert nav, "no city switcher"
        links = {
            text.strip(): (href, "aria-current" in attrs)
            for href, attrs, text in re.findall(
                r'<a href="([^"]*)"([^>]*)>([^<]*)</a>', nav.group(0)
            )
        }
        assert links["Алматы"] == ("/", True)
        assert links["Астана"] == ("/astana/", False)

    def test_on_a_city_page_that_city_is_marked(self, client):
        nav = re.search(r'<nav class="cities".*?</nav>', client.get("/astana/").text, re.DOTALL)

        assert re.search(r'href="/astana/" aria-current="page">Астана<', nav.group(0))

    def test_a_switched_off_city_is_not_offered(self, client, city):
        city("oral", "Орал", active=False)

        assert 'href="/oral/"' not in client.get("/").text


class TestNothingElseMoved:
    @pytest.mark.parametrize("path", ["/cart/", "/actions/", "/about/", "/delivery/", "/login/"])
    def test_real_pages_are_not_taken_for_cities(self, client, path):
        assert client.get(path).status_code == 200

    def test_pages_about_the_whole_service_name_every_city(self, client):
        assert "Сервис доставки еды в Алматы и Астане" in _visible(client.get("/about/").text)
        assert "Доставка еды в Алматы и Астане" in _visible(client.get("/delivery/").text)

    @pytest.mark.parametrize("path", ["/", "/about/", "/delivery/", "/astana/"])
    def test_no_page_still_says_almaty_regardless(self, client, path):
        assert "в г. Алматы" not in _visible(client.get(path).text)
