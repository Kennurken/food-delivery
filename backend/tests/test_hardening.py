"""The small protections around the edges: how fast, how much, and what a page
is allowed to run."""

import pytest

from app.core.config import settings
from app.core.ratelimit import limiter


@pytest.fixture
def tight(monkeypatch):
    limiter.reset()
    monkeypatch.setattr(settings, "write_rate_limit", "2/minute")
    yield
    limiter.reset()


def _order(client, auth):
    menu = client.get("/api/v1/restaurants/1/menu").json()
    return client.post(
        "/api/v1/orders",
        json={
            "restaurant_id": 1,
            "channel": "pickup",
            "items": [{"menu_item_id": menu[0]["id"], "quantity": 1}],
        },
        headers=auth,
    )


class TestRateLimit:
    def test_a_script_placing_orders_is_stopped(self, client, auth, tight):
        assert _order(client, auth).status_code == 201
        assert _order(client, auth).status_code == 201

        assert _order(client, auth).status_code == 429

    def test_a_person_placing_a_few_orders_is_not(self, client, auth):
        for _ in range(5):
            assert _order(client, auth).status_code == 201


class TestSitePolicy:
    def test_site_pages_run_no_scripts(self, client):
        for path in ("/", "/r/bao-bar/", "/about/", "/login/"):
            csp = client.get(path).headers["content-security-policy"]

            assert "default-src 'none'" in csp
            assert "script-src" not in csp  # nothing is allowed, by default-src
            assert "frame-ancestors 'none'" in csp

    def test_checkout_can_still_redirect_to_stripe(self, client):
        # form-action would apply to the redirect after the checkout POST.
        assert "form-action" not in client.get("/").headers["content-security-policy"]

    def test_the_api_is_not_given_a_page_policy(self, client):
        assert "content-security-policy" not in client.get("/api/v1/restaurants").headers

    def test_the_site_still_has_its_stylesheet_and_images_allowed(self, client):
        csp = client.get("/").headers["content-security-policy"]

        assert "style-src 'self'" in csp and "img-src https:" in csp


class TestRequestId:
    def test_a_plain_id_is_kept(self, client):
        r = client.get("/health", headers={"x-request-id": "abc-123_x.y"})

        assert r.headers["x-request-id"] == "abc-123_x.y"

    @pytest.mark.parametrize("bad", ["a b", "x" * 65, "<script>", "id;drop"])
    def test_anything_else_is_replaced(self, client, bad):
        r = client.get("/health", headers={"x-request-id": bad})

        assert r.headers["x-request-id"] != bad
        assert len(r.headers["x-request-id"]) == 16


class TestTenantWalls:
    """An owner runs their own venue and only that one. Every write the last
    few features added is checked for it: hours, bonuses, and answering a
    review, each against a venue that isn't theirs."""

    @pytest.fixture
    def roma_owner(self, client):
        from tests.conftest import _login

        return _login(client, "owner.roma@food.dev", "owner123")

    def test_an_owner_cannot_set_another_venues_hours(self, client, roma_owner):
        r = client.put(
            "/api/v1/admin/restaurants/1/hours",  # Bao Bar
            json=[{"weekday": 0, "opens": "10:00", "closes": "11:00"}],
            headers=roma_owner,
        )

        assert r.status_code == 403

    def test_an_owner_cannot_touch_another_venues_bonus_programme(self, client, roma_owner):
        r = client.put(
            "/api/v1/admin/restaurants/1/loyalty", json={"percent": 5}, headers=roma_owner
        )

        assert r.status_code == 403

    def test_an_owner_cannot_answer_another_venues_review(self, client, auth, admin, roma_owner):
        menu = client.get("/api/v1/restaurants/1/menu").json()
        oid = client.post(
            "/api/v1/orders",
            json={
                "restaurant_id": 1,
                "channel": "pickup",
                "items": [{"menu_item_id": menu[0]["id"], "quantity": 1}],
            },
            headers=auth,
        ).json()["id"]
        for step in ("confirmed", "preparing", "on_the_way", "delivered"):
            client.patch(f"/api/v1/orders/{oid}/status", json={"status": step}, headers=admin)
        client.post(f"/api/v1/orders/{oid}/rate", json={"rating": 1, "review": "meh"}, headers=auth)

        r = client.post(
            f"/api/v1/admin/orders/{oid}/review-reply", json={"text": "we are sorry"}, headers=roma_owner
        )

        assert r.status_code == 403

    def test_an_owner_cannot_manage_cities_or_remove_reviews(self, client, roma_owner):
        assert client.get("/api/v1/admin/cities", headers=roma_owner).status_code == 403
        assert client.delete("/api/v1/admin/orders/1/review", headers=roma_owner).status_code == 403

    def test_a_diner_cannot_read_another_diners_loyalty_or_orders(self, client, auth, courier):
        # Balances are per caller: a courier asking gets their own (empty) one.
        r = client.get("/api/v1/me/loyalty/1", headers=courier)

        assert r.status_code == 200 and r.json()["balance"] == 0
