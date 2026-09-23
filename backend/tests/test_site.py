"""The public site. What matters here is that a crawler with no JavaScript
sees the content — that is the whole reason these pages exist.
"""

import re

from app.services.slugs import slugify, unique_slug


def _visible(html: str) -> str:
    body = re.sub(r"<script.*?</script>", "", html, flags=re.DOTALL | re.IGNORECASE)
    body = re.sub(r"<style.*?</style>", "", body, flags=re.DOTALL | re.IGNORECASE)
    return re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", body)).strip()


def test_the_landing_page_has_real_text_without_javascript(client):
    r = client.get("/")

    assert r.status_code == 200
    assert r.headers["content-type"].startswith("text/html")
    text = _visible(r.text)
    assert "Bao Bar" in text
    assert "Pizza Roma" in text
    assert len(text) > 300  # the Flutter build renders zero here


def test_the_landing_page_carries_the_tags_a_crawler_reads(client):
    r = client.get("/")

    assert "<title>" in r.text
    assert 'name="description"' in r.text
    assert 'rel="canonical"' in r.text
    assert 'property="og:title"' in r.text


def test_a_restaurant_page_lists_its_menu(client):
    r = client.get("/r/bao-bar/")

    assert r.status_code == 200
    text = _visible(r.text)
    assert "Bao Bar" in text
    assert "Pork Bao" in text
    assert "1500" in text  # the price, readable without a fetch


def test_a_restaurant_page_ships_structured_data(client):
    """Rich results need the machine-readable copy, not just the prose."""
    r = client.get("/r/bao-bar/")

    assert 'application/ld+json' in r.text
    assert '"@type": "Restaurant"' in r.text


def test_an_unknown_restaurant_gets_a_page_not_a_json_blob(client):
    r = client.get("/r/no-such-place/")

    assert r.status_code == 404
    assert r.headers["content-type"].startswith("text/html")
    assert "Страница не найдена" in r.text


def test_the_api_still_answers_in_json(client):
    """The HTML 404 must not swallow the API's own error shape."""
    r = client.get("/api/v1/restaurants/999999")

    assert r.status_code == 404
    assert r.headers["content-type"].startswith("application/json")


def test_robots_points_at_the_sitemap_and_keeps_crawlers_out_of_the_api(client):
    r = client.get("/robots.txt")

    assert r.status_code == 200
    assert "Disallow: /api/" in r.text
    assert "sitemap.xml" in r.text


def test_the_sitemap_lists_every_restaurant(client):
    names = {r["id"]: r["name"] for r in client.get("/api/v1/restaurants").json()}
    body = client.get("/sitemap.xml").text

    assert body.startswith("<?xml")
    for name in names.values():
        slug = slugify(name)
        assert f"/r/{slug}/" in body


def test_static_pages_render(client):
    for path in ("/delivery/", "/about/"):
        r = client.get(path)
        assert r.status_code == 200, path
        assert len(_visible(r.text)) > 200, path


def test_the_stylesheet_is_served(client):
    r = client.get("/site/site.css")

    assert r.status_code == 200
    assert "text/css" in r.headers["content-type"]


class TestSlugs:
    def test_latin_names_become_readable_paths(self):
        assert slugify("Bao Bar") == "bao-bar"
        assert slugify("  Pizza  Roma!  ") == "pizza-roma"

    def test_cyrillic_is_transliterated_not_escaped(self):
        """A percent-encoded URL is unreadable to a human and worse for search."""
        assert slugify("Чайхана Навват") == "chaihana-navvat"

    def test_kazakh_letters_survive(self):
        assert slugify("Дәмді Ас") == "damdi-as"

    def test_a_name_with_nothing_usable_still_yields_something(self, client):
        from app.db.session import SessionLocal
        from app.models import Restaurant

        with SessionLocal() as db:
            assert unique_slug(db, Restaurant, "!!! ???") == "place"

    def test_slugs_do_not_collide(self, client):
        from app.db.session import SessionLocal
        from app.models import Restaurant

        with SessionLocal() as db:
            # "Bao Bar" is already taken by the seeded restaurant.
            assert unique_slug(db, Restaurant, "Bao Bar") == "bao-bar-2"

    def test_a_restaurant_keeps_its_own_slug_on_rename(self, client):
        from app.db.session import SessionLocal
        from app.models import Restaurant

        with SessionLocal() as db:
            bao = db.query(Restaurant).filter(Restaurant.slug == "bao-bar").one()
            assert unique_slug(db, Restaurant, "Bao Bar", skip_id=bao.id) == "bao-bar"

    def test_slugs_stay_short_enough_for_a_url(self):
        slug = slugify("Очень длинное название ресторана " * 5)

        assert len(slug) <= 60
        assert not slug.endswith("-")


def test_a_restaurant_created_in_the_admin_gets_a_public_page(client, admin):
    """Found by a full-suite run: venues added after boot had no slug, so they
    existed in the app and were invisible on the site."""
    created = client.post(
        "/api/v1/admin/restaurants",
        json={"name": "Чайхана Навват", "cuisine": "Uzbek", "delivery_fee": 0,
              "delivery_time_min": 25},
        headers=admin,
    )
    assert created.status_code == 201, created.text

    page = client.get("/r/chaihana-navvat/")
    assert page.status_code == 200
    assert "Чайхана Навват" in _visible(page.text)
    assert "/r/chaihana-navvat/" in client.get("/sitemap.xml").text
