"""Ordering from the website.

Every step here is a form POST with scripts switched off — that is the point of
the flow, so the tests drive it the same way a browser without JavaScript would.
"""

import secrets

import pytest
from fastapi.testclient import TestClient

from app.main import app


@pytest.fixture
def web(client):
    """A separate cookie jar per test.

    Deliberately not a `with` block: entering TestClient re-runs the lifespan,
    which rebinds the WebSocket hub to a loop that is closed again on exit and
    breaks every later test that publishes an event. The session-scoped `client`
    fixture already started the app; this only needs its own cookies.
    """
    return TestClient(app)


def _menu(client, restaurant_id: int = 1) -> list[dict]:
    return client.get(f"/api/v1/restaurants/{restaurant_id}/menu").json()


def _add(web, item: dict, restaurant_id: int = 1):
    return web.post(
        "/cart/add",
        data={"restaurant_id": restaurant_id, "item_id": item["id"]},
        follow_redirects=False,
    )


def _sign_up(web, *, next_url: str = "/") -> str:
    email = f"site.{secrets.token_hex(3)}@food.dev"
    r = web.post(
        "/register/",
        data={
            "name": "Site Guest",
            "email": email,
            "phone": "+77010000000",
            "password": "sitepass123",
            "next": next_url,
        },
        follow_redirects=False,
    )
    assert r.status_code == 303, r.text
    return email


class TestCart:
    def test_adding_a_dish_puts_it_in_the_basket(self, client, web):
        item = _menu(client)[0]

        assert _add(web, item).status_code == 303
        page = web.get("/cart/")

        assert item["name"] in page.text
        assert "Корзина · 1" in web.get("/").text

    def test_adding_twice_raises_the_quantity(self, client, web):
        item = _menu(client)[0]
        _add(web, item)
        _add(web, item)

        assert "Корзина · 2" in web.get("/").text

    def test_switching_restaurant_replaces_the_basket(self, client, web):
        """One order cannot span two kitchens, so the second choice wins rather
        than quietly mixing into something nobody can cook."""
        first = _menu(client, 1)[0]
        second = _menu(client, 2)[0]
        _add(web, first, restaurant_id=1)

        _add(web, second, restaurant_id=2)
        page = web.get("/cart/")

        assert second["name"] in page.text
        assert first["name"] not in page.text

    def test_quantity_can_be_lowered_and_removed(self, client, web):
        item = _menu(client)[0]
        _add(web, item)
        _add(web, item)

        web.post("/cart/update", data={"item_id": item["id"], "quantity": 1},
                 follow_redirects=False)
        assert "Корзина · 1" in web.get("/").text

        web.post("/cart/update", data={"item_id": item["id"], "quantity": 0},
                 follow_redirects=False)
        assert "Пока пусто" in web.get("/cart/").text

    def test_clearing_empties_the_basket(self, client, web):
        _add(web, _menu(client)[0])

        web.post("/cart/clear", follow_redirects=False)

        assert "Пока пусто" in web.get("/cart/").text

    def test_a_forged_cookie_is_an_empty_basket_not_an_error(self, web):
        """The visitor did nothing wrong; show them an empty cart, not a 500."""
        web.cookies.set("fd_cart", "bm90LWEtcmVhbC1jYXJ0.AAAA")

        page = web.get("/cart/")

        assert page.status_code == 200
        assert "Пока пусто" in page.text

    def test_a_dish_from_another_restaurant_is_refused(self, client, web):
        stranger = _menu(client, 2)[0]

        r = web.post(
            "/cart/add",
            data={"restaurant_id": 1, "item_id": stranger["id"]},
            follow_redirects=False,
        )

        assert r.status_code == 404

    def test_the_basket_totals_come_from_the_database(self, client, web):
        """The cookie carries ids and counts only — never a price."""
        item = _menu(client)[0]
        _add(web, item)
        _add(web, item)

        page = web.get("/cart/").text

        assert str(int(item["price"] * 2)) in page.replace(" ", "")


class TestAuth:
    def test_registering_signs_you_in(self, web):
        _sign_up(web)

        assert "Выйти" in web.get("/").text

    def test_a_wrong_password_says_nothing_about_the_account(self, web):
        email = _sign_up(web)
        web.post("/logout/", follow_redirects=False)

        wrong = web.post(
            "/login/",
            data={"email": email, "password": "nope", "next": "/"},
            follow_redirects=False,
        )
        unknown = web.post(
            "/login/",
            data={"email": "ghost@food.dev", "password": "nope", "next": "/"},
            follow_redirects=False,
        )

        assert wrong.status_code == unknown.status_code == 401
        assert "Неверная почта или пароль" in wrong.text
        assert "Неверная почта или пароль" in unknown.text

    def test_a_short_password_is_refused(self, web):
        r = web.post(
            "/register/",
            data={"name": "X", "email": f"x.{secrets.token_hex(3)}@food.dev",
                  "phone": "", "password": "short", "next": "/"},
            follow_redirects=False,
        )

        assert r.status_code == 400
        assert "8 символов" in r.text

    def test_login_only_returns_inside_this_site(self, web):
        """An open redirect on a login form is a phishing gadget."""
        email = _sign_up(web)
        web.post("/logout/", follow_redirects=False)

        r = web.post(
            "/login/",
            data={"email": email, "password": "sitepass123", "next": "//evil.example/"},
            follow_redirects=False,
        )

        assert r.headers["location"] == "/"

    def test_the_session_cookie_is_closed_to_scripts(self, web):
        r = web.post(
            "/register/",
            data={"name": "X", "email": f"x.{secrets.token_hex(3)}@food.dev",
                  "phone": "", "password": "sitepass123", "next": "/"},
            follow_redirects=False,
        )

        cookie = r.headers["set-cookie"]
        assert "fd_session" in cookie
        assert "HttpOnly" in cookie


class TestCheckout:
    def test_checkout_asks_you_to_sign_in_first(self, client, web):
        _add(web, _menu(client)[0])

        r = web.get("/checkout/", follow_redirects=False)

        assert r.status_code == 303
        assert r.headers["location"] == "/login/?next=/checkout/"

    def test_an_empty_basket_sends_you_back_to_the_cart(self, web):
        _sign_up(web)

        r = web.get("/checkout/", follow_redirects=False)

        assert r.headers["location"] == "/cart/"

    def test_a_cash_order_goes_through_end_to_end(self, client, web):
        item = _menu(client)[0]
        _add(web, item)
        _sign_up(web)

        placed = web.post(
            "/checkout/",
            data={"address": "Abay 10", "channel": "delivery", "pay_method": "cash",
                  "comment": "", "promo_code": ""},
            follow_redirects=False,
        )

        assert placed.status_code == 303, placed.text
        location = placed.headers["location"]
        assert location.startswith("/orders/")
        page = web.get(location)
        assert page.status_code == 200
        assert item["name"] in page.text
        # The basket is handed over with the order, not left behind to be
        # ordered twice.
        assert "Пока пусто" in web.get("/cart/").text

    def test_delivery_without_an_address_is_explained_not_crashed(self, client, web):
        _add(web, _menu(client)[0])
        _sign_up(web)

        r = web.post(
            "/checkout/",
            data={"address": "", "channel": "delivery", "pay_method": "cash",
                  "comment": "", "promo_code": ""},
            follow_redirects=False,
        )

        assert r.status_code == 400
        assert "адрес" in r.text.lower()

    def test_pickup_needs_no_address(self, client, web):
        _add(web, _menu(client)[0])
        _sign_up(web)

        r = web.post(
            "/checkout/",
            data={"address": "", "channel": "pickup", "pay_method": "cash",
                  "comment": "", "promo_code": ""},
            follow_redirects=False,
        )

        assert r.status_code == 303, r.text

    def test_card_is_refused_honestly_when_stripe_is_absent(self, client, web):
        """Tests run without Stripe keys, so this must read as a message, not a 500."""
        _add(web, _menu(client)[0])
        _sign_up(web)

        r = web.post(
            "/checkout/",
            data={"address": "Abay 10", "channel": "delivery", "pay_method": "online",
                  "comment": "", "promo_code": ""},
            follow_redirects=False,
        )

        assert r.status_code == 400
        assert "Card payments are not connected" in r.text


class TestOrders:
    def test_someone_elses_order_looks_like_one_that_never_existed(self, client, web):
        item = _menu(client)[0]
        _add(web, item)
        _sign_up(web)
        mine = web.post(
            "/checkout/",
            data={"address": "Abay 10", "channel": "delivery", "pay_method": "cash",
                  "comment": "", "promo_code": ""},
            follow_redirects=False,
        ).headers["location"]

        stranger = TestClient(app)
        _sign_up(stranger)
        seen = stranger.get(mine)

        assert seen.status_code == 404

    def test_the_history_needs_a_session(self, web):
        r = web.get("/orders/", follow_redirects=False)

        assert r.headers["location"] == "/login/?next=/orders/"


def test_private_pages_are_kept_out_of_the_index(client):
    robots = client.get("/robots.txt").text

    for path in ("/cart/", "/checkout/", "/orders/", "/login/"):
        assert f"Disallow: {path}" in robots
