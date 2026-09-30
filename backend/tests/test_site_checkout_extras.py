"""Tips and bonuses at the website's checkout — the same choices the app has,
as plain form fields."""

import re
import secrets

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select

from app.db.session import SessionLocal
from app.main import app
from app.models import LoyaltyEntry, Order, Restaurant, User


@pytest.fixture
def web(client):
    return TestClient(app)


def _menu(client, rid=1):
    return client.get(f"/api/v1/restaurants/{rid}/menu").json()


def _signed_up(web) -> str:
    email = f"extras.{secrets.token_hex(3)}@food.dev"
    r = web.post(
        "/register/",
        data={"name": "Extras Guest", "email": email, "phone": "+77010000000",
              "password": "sitepass123", "next": "/"},
        follow_redirects=False,
    )
    assert r.status_code == 303, r.text
    return email


def _fill(web, item, rid=1):
    web.post("/cart/add", data={"restaurant_id": rid, "item_id": item["id"]}, follow_redirects=False)


def _placed(web, **fields) -> Order:
    r = web.post(
        "/checkout/",
        data={"address": "Abay 10", "channel": "delivery", "pay_method": "cash",
              "comment": "", "promo_code": "", **fields},
        follow_redirects=False,
    )
    assert r.status_code == 303, r.text
    oid = int(re.search(r"/orders/(\d+)/", r.headers["location"]).group(1))
    with SessionLocal() as db:
        return db.get(Order, oid)


class TestTips:
    def test_the_page_offers_the_round_amounts(self, client, web):
        _fill(web, _menu(client)[0])
        _signed_up(web)

        page = web.get("/checkout/").text

        assert "Чаевые курьеру" in page
        for amount in (200, 500, 1000):
            assert f'name="tip" value="{amount}"' in page

    def test_a_tip_lands_on_the_order(self, client, web):
        _fill(web, _menu(client)[0])
        _signed_up(web)

        order = _placed(web, tip="500")

        assert order.tip == 500
        assert order.total == order.subtotal + order.delivery_fee + 500
        assert "Чаевые курьеру" in web.get(f"/orders/{order.id}/").text

    def test_pickup_takes_no_tip(self, client, web):
        _fill(web, _menu(client)[0])
        _signed_up(web)

        order = _placed(web, channel="pickup", address="", tip="500")

        assert order.tip == 0

    def test_an_amount_the_page_did_not_offer_is_ignored(self, client, web):
        _fill(web, _menu(client)[0])
        _signed_up(web)

        assert _placed(web, tip="49999").tip == 0
        _fill(web, _menu(client)[0])
        assert _placed(web, tip="-5").tip == 0


class TestBonuses:
    @pytest.fixture
    def premium_venue(self, client, admin):
        rid = client.post(
            "/api/v1/admin/restaurants",
            json={"name": f"Site Bonus {secrets.token_hex(2)}", "cuisine": "Test"},
            headers=admin,
        ).json()["id"]
        client.patch(f"/api/v1/admin/restaurants/{rid}", json={"plan_code": "premium"}, headers=admin)
        client.post(f"/api/v1/admin/restaurants/{rid}/menu",
                    json={"name": "Plov", "price": 2000, "category": "Main"}, headers=admin)
        client.put(f"/api/v1/admin/restaurants/{rid}/loyalty",
                   json={"percent": 10, "max_share": 0.5}, headers=admin)
        return rid

    def _give(self, email: str, rid: int, amount: float) -> None:
        with SessionLocal() as db:
            user = db.scalar(select(User).where(User.email == email))
            db.add(LoyaltyEntry(user_id=user.id, restaurant_id=rid, kind="earn", amount=amount))
            db.commit()

    def test_no_balance_no_checkbox(self, client, web, premium_venue):
        _fill(web, _menu(client, premium_venue)[0], premium_venue)
        _signed_up(web)

        assert "Оплатить бонусами" not in web.get("/checkout/").text

    def test_with_a_balance_the_diner_can_pay_with_it(self, client, web, premium_venue):
        _fill(web, _menu(client, premium_venue)[0], premium_venue)
        email = _signed_up(web)
        self._give(email, premium_venue, 300)

        page = web.get("/checkout/").text

        assert "Оплатить бонусами (до 300 ₸, на счёте 300 ₸)" in page  # capped by 50 % of 2000 → 1000
        order = _placed(web, use_loyalty="1", channel="pickup", address="")
        assert order.loyalty_spent == 300
        assert order.total == order.subtotal - 300
        assert "Оплачено бонусами" in web.get(f"/orders/{order.id}/").text

    def test_not_ticking_it_keeps_the_balance(self, client, web, premium_venue):
        _fill(web, _menu(client, premium_venue)[0], premium_venue)
        email = _signed_up(web)
        self._give(email, premium_venue, 300)

        order = _placed(web, channel="pickup", address="")

        assert order.loyalty_spent == 0

    def test_a_venue_without_a_programme_shows_nothing(self, client, web):
        _fill(web, _menu(client)[0])
        _signed_up(web)

        assert "Оплатить бонусами" not in web.get("/checkout/").text
        with SessionLocal() as db:
            assert db.get(Restaurant, 1).loyalty_percent == 0


class TestTheLiveOrderPage:
    """The order page is where a website customer waits, so it has to be enough
    to finish the delivery: the handover code, fresh status, no scripts."""

    def _delivery(self, client, web):
        _fill(web, _menu(client)[0])
        _signed_up(web)
        return _placed(web)

    def _progress(self, client, admin, courier, oid, *steps):
        client.patch(f"/api/v1/orders/{oid}/status", json={"status": "confirmed"}, headers=admin)
        client.post(f"/api/v1/orders/{oid}/accept", headers=courier)
        for step in steps:
            if step == "preparing":
                client.patch(f"/api/v1/orders/{oid}/status", json={"status": "preparing"}, headers=admin)
            else:
                client.post(f"/api/v1/orders/{oid}/advance", headers=courier)

    def test_a_live_order_refreshes_itself(self, client, web):
        order = self._delivery(client, web)

        assert '<meta http-equiv="refresh"' in web.get(f"/orders/{order.id}/").text

    def test_no_code_before_a_courier_has_it(self, client, web):
        order = self._delivery(client, web)

        assert "Код для курьера" not in web.get(f"/orders/{order.id}/").text

    def test_the_customer_sees_the_code_once_a_courier_takes_it(self, client, web, admin, courier):
        order = self._delivery(client, web)
        self._progress(client, admin, courier, order.id, "preparing", "advance")
        client.post("/api/v1/courier/location", json={"lat": 43.24, "lng": 76.9}, headers=courier)

        page = web.get(f"/orders/{order.id}/").text

        with SessionLocal() as db:
            code = db.get(Order, order.id).handover_code
        assert code and f'class="code">{code}<' in page
        assert "Курьер на связи" in page

    def test_the_code_closes_the_delivery(self, client, web, admin, courier):
        """The end-to-end reason the code is on the page."""
        order = self._delivery(client, web)
        self._progress(client, admin, courier, order.id, "preparing", "advance")
        code = re.search(r'class="code">(\d+)<', web.get(f"/orders/{order.id}/").text).group(1)

        r = client.post(f"/api/v1/orders/{order.id}/advance", json={"code": code}, headers=courier)

        assert r.status_code == 200 and r.json()["status"] == "delivered"

    def test_a_finished_order_stops_refreshing_and_hides_the_code(self, client, web, admin, courier):
        order = self._delivery(client, web)
        self._progress(client, admin, courier, order.id, "preparing", "advance")
        code = re.search(r'class="code">(\d+)<', web.get(f"/orders/{order.id}/").text).group(1)
        client.post(f"/api/v1/orders/{order.id}/advance", json={"code": code}, headers=courier)

        page = web.get(f"/orders/{order.id}/").text

        assert '<meta http-equiv="refresh"' not in page
        assert "Код для курьера" not in page

    def test_nobody_else_sees_it(self, client, web, admin, courier):
        order = self._delivery(client, web)
        self._progress(client, admin, courier, order.id, "preparing", "advance")

        stranger = TestClient(app)
        _signed_up(stranger)

        assert stranger.get(f"/orders/{order.id}/").status_code == 404


class TestRepeatingAnOrder:
    """One button to put a past order back in the basket — as the menu stands
    today, and never a dish that is gone or one with options the site's basket
    can't carry."""

    def _done(self, client, web, admin):
        _fill(web, _menu(client)[0])
        _signed_up(web)
        order = _placed(web, channel="pickup", address="")
        for step in ("confirmed", "preparing", "on_the_way", "delivered"):
            client.patch(f"/api/v1/orders/{order.id}/status", json={"status": step}, headers=admin)
        return order

    def test_a_finished_order_offers_it(self, client, web, admin):
        order = self._done(client, web, admin)

        assert "Повторить заказ" in web.get(f"/orders/{order.id}/").text

    def test_a_live_order_does_not(self, client, web):
        _fill(web, _menu(client)[0])
        _signed_up(web)
        order = _placed(web)

        assert "Повторить заказ" not in web.get(f"/orders/{order.id}/").text

    def test_it_refills_the_basket(self, client, web, admin):
        order = self._done(client, web, admin)

        r = web.post(f"/orders/{order.id}/repeat", follow_redirects=False)

        assert r.status_code == 303 and r.headers["location"] == "/cart/"
        assert _menu(client)[0]["name"] in web.get("/cart/").text

    def test_a_dish_that_left_the_menu_is_dropped(self, client, web, admin):
        order = self._done(client, web, admin)
        item = _menu(client)[0]
        client.patch(f"/api/v1/admin/menu/{item['id']}", json={"is_available": False}, headers=admin)
        try:
            r = web.post(f"/orders/{order.id}/repeat", follow_redirects=False)

            assert r.headers["location"] == f"/orders/{order.id}/?gone=1"
            assert "Этих блюд сейчас нет" in web.get(r.headers["location"]).text
        finally:
            client.patch(f"/api/v1/admin/menu/{item['id']}", json={"is_available": True}, headers=admin)

    def test_someone_elses_order_is_not_repeatable(self, client, web, admin):
        order = self._done(client, web, admin)
        stranger = TestClient(app)
        _signed_up(stranger)

        assert stranger.post(f"/orders/{order.id}/repeat", follow_redirects=False).status_code == 404

    def test_signed_out_goes_to_sign_in(self, client):
        r = TestClient(app).post("/orders/1/repeat", follow_redirects=False)

        assert r.status_code == 303 and r.headers["location"].startswith("/login/")


class TestRepeatAndOptions:
    """The site's basket carries no options, so it only repeats what it can
    reproduce exactly."""

    @pytest.fixture
    def venue(self, client, admin):
        rid = client.post(
            "/api/v1/admin/restaurants",
            json={"name": f"Options Cafe {secrets.token_hex(2)}", "cuisine": "Test"},
            headers=admin,
        ).json()["id"]
        dish = client.post(
            f"/api/v1/admin/restaurants/{rid}/menu",
            json={"name": "Coffee", "price": 1000, "category": "Drinks"},
            headers=admin,
        ).json()["id"]
        made = client.put(
            f"/api/v1/admin/menu/{dish}/modifiers",
            json=[{"name": "Size", "required": True, "min_select": 1, "max_select": 1,
                   "options": [{"name": "Small", "is_default": True},
                               {"name": "Large", "price_delta": 300}]}],
            headers=admin,
        )
        assert made.status_code == 200, made.text
        options = {o["name"]: o["id"] for g in made.json()["modifier_groups"] for o in g["options"]}
        return {"id": rid, "dish": dish, "options": options}

    def _order_with(self, client, admin, venue, option_ids):
        user = TestClient(app)
        email = _signed_up(user)
        with SessionLocal() as db:
            uid = db.scalar(select(User.id).where(User.email == email))
        token = client.post(
            "/api/v1/auth/login/json", json={"email": email, "password": "sitepass123"}
        ).json()["access_token"]
        oid = client.post(
            "/api/v1/orders",
            json={"restaurant_id": venue["id"], "channel": "pickup",
                  "items": [{"menu_item_id": venue["dish"], "quantity": 1, "option_ids": option_ids}]},
            headers={"Authorization": f"Bearer {token}"},
        ).json()["id"]
        for step in ("confirmed", "preparing", "on_the_way", "delivered"):
            client.patch(f"/api/v1/orders/{oid}/status", json={"status": step}, headers=admin)
        assert uid
        return user, oid

    def test_default_options_can_be_repeated(self, client, admin, venue):
        user, oid = self._order_with(client, admin, venue, [venue["options"]["Small"]])

        assert "Повторить заказ" in user.get(f"/orders/{oid}/").text

    def test_a_different_choice_cannot_be_reproduced_so_it_is_not_offered(self, client, admin, venue):
        user, oid = self._order_with(client, admin, venue, [venue["options"]["Large"]])

        assert "Повторить заказ" not in user.get(f"/orders/{oid}/").text
        r = user.post(f"/orders/{oid}/repeat", follow_redirects=False)
        assert r.headers["location"] == f"/orders/{oid}/?gone=1"
