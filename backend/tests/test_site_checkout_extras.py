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
