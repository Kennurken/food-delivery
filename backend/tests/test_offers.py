"""Campaign pages.

The rule worth defending: a campaign is public exactly while it runs. An offer
that has ended, has not started, or was switched off must not be on the landing
page, must not answer 200, and must not be in the sitemap — each of those keeps
advertising something the checkout will refuse.
"""

from datetime import datetime, timedelta

import pytest

from app.db.session import SessionLocal
from app.models import Offer, Promo


def _now() -> datetime:
    return datetime.now()  # noqa: DTZ005


@pytest.fixture
def make_offer(client):
    made: list[int] = []

    def build(**fields) -> Offer:
        with SessionLocal() as db:
            offer = Offer(
                restaurant_id=fields.pop("restaurant_id", 1),
                slug=fields.pop("slug", f"probe-{len(made)}"),
                title=fields.pop("title", "Проба"),
                subtitle=fields.pop("subtitle", "Подзаголовок"),
                body=fields.pop("body", "Текст акции"),
                **fields,
            )
            db.add(offer)
            db.commit()
            db.refresh(offer)
            made.append(offer.id)
            return offer

    yield build

    with SessionLocal() as db:
        for oid in made:
            row = db.get(Offer, oid)
            if row:
                db.delete(row)
        db.commit()


class TestWhatThePublicSees:
    def test_a_running_campaign_has_its_own_page(self, client, make_offer):
        offer = make_offer(slug="live-one", title="Живая акция")

        page = client.get(f"/actions/{offer.slug}")

        assert page.status_code == 200
        assert "Живая акция" in page.text

    def test_it_is_listed_and_linked_from_the_landing_page(self, client, make_offer):
        make_offer(slug="listed-one", title="Видимая акция")

        assert "Видимая акция" in client.get("/actions/").text
        assert "/actions/listed-one" in client.get("/").text

    def test_a_finished_campaign_is_gone(self, client, make_offer):
        """Not stale — gone. A 200 here keeps the promise alive."""
        offer = make_offer(slug="over", ends_at=_now() - timedelta(days=1))

        assert client.get(f"/actions/{offer.slug}").status_code == 404
        assert "over" not in client.get("/actions/").text

    def test_a_campaign_that_has_not_started_is_not_shown(self, client, make_offer):
        offer = make_offer(slug="later", starts_at=_now() + timedelta(days=2))

        assert client.get(f"/actions/{offer.slug}").status_code == 404

    def test_a_switched_off_campaign_is_not_shown(self, client, make_offer):
        offer = make_offer(slug="paused", is_active=False)

        assert client.get(f"/actions/{offer.slug}").status_code == 404

    def test_an_open_ended_campaign_runs(self, client, make_offer):
        """No dates means no bounds, not "never".ceil"""
        offer = make_offer(slug="forever", starts_at=None, ends_at=None)

        assert client.get(f"/actions/{offer.slug}").status_code == 200

    def test_an_unknown_slug_is_a_page_not_a_json_blob(self, client):
        r = client.get("/actions/nothing-here")

        assert r.status_code == 404
        assert r.headers["content-type"].startswith("text/html")

    def test_a_campaign_page_carries_its_own_tags(self, client, make_offer):
        offer = make_offer(slug="tagged", title="С мета-тегами")

        body = client.get(f"/actions/{offer.slug}").text

        assert 'rel="canonical"' in body
        assert f"/actions/{offer.slug}" in body
        assert 'property="og:title"' in body


class TestTheCodeItAdvertises:
    def test_a_usable_code_is_printed(self, client, admin, make_offer):
        promos = client.get("/api/v1/admin/restaurants/1/promos", headers=admin).json()
        if not promos:
            pytest.skip("no seeded promo for restaurant 1")
        offer = make_offer(slug="with-code", promo_code=promos[0]["code"])

        assert promos[0]["code"] in client.get(f"/actions/{offer.slug}").text

    def test_a_code_the_checkout_would_refuse_is_not_printed(self, client, make_offer):
        """Printing a dead code sends someone to a till that turns them away."""
        offer = make_offer(slug="dead-code", promo_code="NOSUCHCODE")

        body = client.get(f"/actions/{offer.slug}").text

        assert "NOSUCHCODE" not in body

    def test_an_exhausted_code_is_not_printed(self, client, make_offer):
        with SessionLocal() as db:
            promo = Promo(
                restaurant_id=1,
                code="SPENT",
                kind="amount",
                value=100,
                is_active=True,
                max_uses=1,
                used_count=1,
            )
            db.add(promo)
            db.commit()
            promo_id = promo.id
        offer = make_offer(slug="spent-code", promo_code="SPENT")
        try:
            assert "SPENT" not in client.get(f"/actions/{offer.slug}").text
        finally:
            with SessionLocal() as db:
                db.delete(db.get(Promo, promo_id))
                db.commit()


class TestTheSitemap:
    def test_it_lists_running_campaigns(self, client, make_offer):
        make_offer(slug="crawlable")

        body = client.get("/sitemap.xml").text

        assert "/actions/" in body
        assert "/actions/crawlable" in body

    def test_it_leaves_out_finished_ones(self, client, make_offer):
        """A sitemap entry that 404s spends a crawler's budget on nothing."""
        make_offer(slug="expired-one", ends_at=_now() - timedelta(days=3))

        assert "/actions/expired-one" not in client.get("/sitemap.xml").text


class TestEditing:
    def test_an_owner_creates_a_campaign_and_gets_a_readable_url(self, client, admin):
        r = client.post(
            "/api/v1/admin/restaurants/1/offers",
            json={"title": "Скидка на роллы", "subtitle": "По выходным"},
            headers=admin,
        )

        assert r.status_code == 201, r.text
        body = r.json()
        assert body["slug"] == "skidka-na-rolly"
        assert body["url"] == "/actions/skidka-na-rolly"
        client.delete(f"/api/v1/admin/offers/{body['id']}", headers=admin)

    def test_a_customer_cannot_create_one(self, client, auth):
        r = client.post(
            "/api/v1/admin/restaurants/1/offers",
            json={"title": "Моя акция"},
            headers=auth,
        )

        assert r.status_code in (403, 404)

    def test_a_campaign_cannot_end_before_it_starts(self, client, admin):
        r = client.post(
            "/api/v1/admin/restaurants/1/offers",
            json={
                "title": "Задом наперёд",
                "starts_at": _now().isoformat(),
                "ends_at": (_now() - timedelta(days=1)).isoformat(),
            },
            headers=admin,
        )

        assert r.status_code == 422

    def test_switching_one_off_removes_it_from_the_site(self, client, admin, make_offer):
        offer = make_offer(slug="to-be-paused", title="Скоро выключим")
        assert client.get(f"/actions/{offer.slug}").status_code == 200

        client.patch(
            f"/api/v1/admin/offers/{offer.id}", json={"is_active": False}, headers=admin
        )

        assert client.get(f"/actions/{offer.slug}").status_code == 404

    def test_the_editor_shows_campaigns_the_public_cannot_see(
        self, client, admin, make_offer
    ):
        """An owner has to be able to find the one they switched off."""
        offer = make_offer(slug="hidden-one", is_active=False)

        rows = client.get("/api/v1/admin/restaurants/1/offers", headers=admin).json()

        assert any(row["id"] == offer.id for row in rows)
