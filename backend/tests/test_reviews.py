"""Written reviews.

They are public text under a diner's name, so the rules that matter: only a
delivered order can be reviewed, once; the author is shown as a first name and
an initial; the venue can answer but not delete; the platform can remove the
text without touching the score.
"""

import itertools

import pytest

_n = itertools.count(1)


@pytest.fixture
def venue(client, admin) -> dict:
    rid = client.post(
        "/api/v1/admin/restaurants",
        json={"name": f"Review Cafe {next(_n)}", "cuisine": "Test"},
        headers=admin,
    ).json()["id"]
    dish = client.post(
        f"/api/v1/admin/restaurants/{rid}/menu",
        json={"name": "Manty", "price": 1500, "category": "Main"},
        headers=admin,
    ).json()["id"]
    return {"id": rid, "dish": dish}


def _delivered(client, auth, admin, venue) -> int:
    oid = client.post(
        "/api/v1/orders",
        json={
            "restaurant_id": venue["id"],
            "channel": "pickup",
            "items": [{"menu_item_id": venue["dish"], "quantity": 1}],
        },
        headers=auth,
    ).json()["id"]
    for step in ("confirmed", "preparing", "on_the_way", "delivered"):
        client.patch(f"/api/v1/orders/{oid}/status", json={"status": step}, headers=admin)
    return oid


def _rate(client, auth, oid, **body):
    return client.post(f"/api/v1/orders/{oid}/rate", json={"rating": 5, **body}, headers=auth)


def _reviews(client, venue, **params) -> dict:
    r = client.get(f"/api/v1/restaurants/{venue['id']}/reviews", params=params)
    assert r.status_code == 200, r.text
    return r.json()


class TestWriting:
    def test_a_review_appears_on_the_venue(self, client, auth, admin, venue):
        oid = _delivered(client, auth, admin, venue)

        r = _rate(client, auth, oid, review="  Very tasty manty!  ")

        assert r.status_code == 200
        assert r.json()["review"] == "Very tasty manty!"
        row = _reviews(client, venue)["items"][0]
        assert row["order_id"] == oid and row["rating"] == 5
        assert row["text"] == "Very tasty manty!"
        assert row["reply"] is None

    def test_a_rating_without_text_is_not_listed(self, client, auth, admin, venue):
        oid = _delivered(client, auth, admin, venue)

        _rate(client, auth, oid)

        assert _reviews(client, venue)["items"] == []

    def test_blank_text_counts_as_none(self, client, auth, admin, venue):
        oid = _delivered(client, auth, admin, venue)

        assert _rate(client, auth, oid, review="   ").json()["review"] is None

    def test_only_a_delivered_order_can_be_reviewed(self, client, auth, venue):
        oid = client.post(
            "/api/v1/orders",
            json={
                "restaurant_id": venue["id"],
                "channel": "pickup",
                "items": [{"menu_item_id": venue["dish"], "quantity": 1}],
            },
            headers=auth,
        ).json()["id"]

        assert _rate(client, auth, oid, review="never arrived").status_code == 409

    def test_one_review_per_order(self, client, auth, admin, venue):
        oid = _delivered(client, auth, admin, venue)
        _rate(client, auth, oid, review="first")

        assert _rate(client, auth, oid, review="second").status_code == 409
        assert _reviews(client, venue)["items"][0]["text"] == "first"

    def test_a_novel_is_refused(self, client, auth, admin, venue):
        oid = _delivered(client, auth, admin, venue)

        assert _rate(client, auth, oid, review="x" * 1001).status_code == 422

    def test_the_author_is_a_first_name_and_an_initial(self, client, auth, admin, venue):
        oid = _delivered(client, auth, admin, venue)
        _rate(client, auth, oid, review="ok")

        author = _reviews(client, venue)["items"][0]["author"]

        full = client.get("/api/v1/auth/me", headers=auth).json()["name"].split()
        assert author.split()[0] == full[0]
        assert len(author.split()) <= 2
        if len(full) > 1:
            assert author == f"{full[0]} {full[1][0]}."


class TestPaging:
    def test_newest_first_and_pages_do_not_repeat(self, client, auth, admin, venue):
        ids = []
        for i in range(3):
            oid = _delivered(client, auth, admin, venue)
            _rate(client, auth, oid, review=f"review {i}")
            ids.append(oid)

        first = _reviews(client, venue, limit=2)
        second = _reviews(client, venue, limit=2, before=first["next_before"])

        assert [r["order_id"] for r in first["items"]] == [ids[2], ids[1]]
        assert first["next_before"] == ids[1]
        assert [r["order_id"] for r in second["items"]] == [ids[0]]
        assert second["next_before"] is None

    def test_an_unknown_venue_is_404(self, client):
        assert client.get("/api/v1/restaurants/999999/reviews").status_code == 404


class TestReplyAndRemoval:
    @pytest.fixture
    def reviewed(self, client, auth, admin, venue) -> int:
        oid = _delivered(client, auth, admin, venue)
        _rate(client, auth, oid, review="cold food")
        return oid

    def test_the_venue_answers_and_it_shows(self, client, admin, venue, reviewed):
        r = client.post(
            f"/api/v1/admin/orders/{reviewed}/review-reply",
            json={"text": "Sorry! Come again."},
            headers=admin,
        )

        assert r.status_code == 200
        assert _reviews(client, venue)["items"][0]["reply"] == "Sorry! Come again."

    def test_a_diner_cannot_answer_for_the_venue(self, client, auth, reviewed):
        r = client.post(
            f"/api/v1/admin/orders/{reviewed}/review-reply", json={"text": "hi"}, headers=auth
        )

        assert r.status_code == 403

    def test_answering_a_review_that_is_not_there_is_404(self, client, admin):
        r = client.post(
            "/api/v1/admin/orders/999999/review-reply", json={"text": "hi"}, headers=admin
        )

        assert r.status_code == 404

    def test_the_platform_removes_the_text_but_the_stars_stay(
        self, client, auth, admin, venue, reviewed
    ):
        before = client.get(f"/api/v1/restaurants/{venue['id']}").json()["rating_count"]

        r = client.delete(f"/api/v1/admin/orders/{reviewed}/review", headers=admin)

        assert r.status_code == 204
        assert _reviews(client, venue)["items"] == []
        assert client.get(f"/api/v1/restaurants/{venue['id']}").json()["rating_count"] == before

    def test_only_the_platform_removes(self, client, auth, reviewed):
        assert client.delete(f"/api/v1/admin/orders/{reviewed}/review", headers=auth).status_code == 403


def _page(client, venue) -> str:
    from app.db.session import SessionLocal
    from app.models import Restaurant

    with SessionLocal() as db:
        return client.get(f"/r/{db.get(Restaurant, venue['id']).slug}/").text


class TestOnTheSite:
    def test_the_review_and_the_answer_are_on_the_page(self, client, auth, admin, venue):
        oid = _delivered(client, auth, admin, venue)
        _rate(client, auth, oid, review="Great place")
        client.post(
            f"/api/v1/admin/orders/{oid}/review-reply", json={"text": "Thank you!"}, headers=admin
        )

        html = _page(client, venue)

        assert "Great place" in html
        assert "Ответ заведения" in html and "Thank you!" in html

    def test_html_in_a_review_is_text_not_markup(self, client, auth, admin, venue):
        oid = _delivered(client, auth, admin, venue)
        _rate(client, auth, oid, review="<script>alert(1)</script> & <b>bold</b>")

        html = _page(client, venue)

        assert "<script>alert(1)</script>" not in html
        assert "<b>bold</b>" not in html
        assert "&lt;b&gt;bold&lt;/b&gt;" in html

    def test_structured_data_stays_valid_json_with_awkward_text(self, client, auth, admin, venue):
        import json
        import re

        oid = _delivered(client, auth, admin, venue)
        _rate(client, auth, oid, review='He said "wow" </script> \\ end')

        html = _page(client, venue)

        block = re.search(r'<script type="application/ld\+json">(.*?)</script>', html, re.DOTALL)
        data = json.loads(block.group(1))
        assert data["review"][0]["reviewBody"] == 'He said "wow" </script> \\ end'

    def test_a_venue_with_no_reviews_has_no_section(self, client, venue):
        html = _page(client, venue)

        assert 'id="reviews"' not in html
        assert '"review"' not in html
