"""A venue's bonus programme.

What must hold: bonuses arrive only for food that was delivered and paid for,
spending them can't exceed what the venue allows, a cancelled order gives back
what it spent, and none of it happens at a venue that doesn't pay for it.
"""

import itertools

import pytest

from app.db.session import SessionLocal
from app.models import Order
from app.services import loyalty

_names = itertools.count(1)
PRICE = 2000


@pytest.fixture
def venue(client, admin) -> dict:
    """A fresh Premium venue with a 10 % programme and one 2000 ₸ dish."""
    r = client.post(
        "/api/v1/admin/restaurants",
        json={"name": f"Bonus Cafe {next(_names)}", "cuisine": "Test"},
        headers=admin,
    )
    assert r.status_code == 201, r.text
    rid = r.json()["id"]
    client.patch(f"/api/v1/admin/restaurants/{rid}", json={"plan_code": "premium"}, headers=admin)
    dish = client.post(
        f"/api/v1/admin/restaurants/{rid}/menu",
        json={"name": "Lagman", "price": PRICE, "category": "Main"},
        headers=admin,
    ).json()["id"]
    on = client.put(
        f"/api/v1/admin/restaurants/{rid}/loyalty",
        json={"percent": 10, "max_share": 0.5},
        headers=admin,
    )
    assert on.status_code == 200, on.text
    assert on.json()["active"] is True
    return {"id": rid, "dish": dish}


def _order(client, auth, venue, **extra) -> dict:
    r = client.post(
        "/api/v1/orders",
        json={
            "restaurant_id": venue["id"],
            "channel": "pickup",
            "items": [{"menu_item_id": venue["dish"], "quantity": 1}],
            **extra,
        },
        headers=auth,
    )
    assert r.status_code == 201, r.text
    return r.json()


def _serve(client, admin, order_id: int) -> None:
    for step in ("confirmed", "preparing", "on_the_way", "delivered"):
        r = client.patch(f"/api/v1/orders/{order_id}/status", json={"status": step}, headers=admin)
        assert r.status_code == 200, r.text


def _balance(client, auth, venue, **params) -> dict:
    r = client.get(f"/api/v1/me/loyalty/{venue['id']}", params=params, headers=auth)
    assert r.status_code == 200, r.text
    return r.json()


class TestEarning:
    def test_nothing_is_earned_until_the_food_is_delivered(self, client, auth, admin, venue):
        order = _order(client, auth, venue)
        assert _balance(client, auth, venue)["balance"] == 0

        _serve(client, admin, order["id"])

        assert _balance(client, auth, venue)["balance"] == 200  # 10 % of 2000

    def test_a_delivered_order_earns_once(self, client, auth, admin, venue):
        order = _order(client, auth, venue)
        _serve(client, admin, order["id"])

        with SessionLocal() as db:
            again = loyalty.earn(db, db.get(Order, order["id"]))
            db.commit()

        assert again == 0
        assert _balance(client, auth, venue)["balance"] == 200

    def test_a_cancelled_order_earns_nothing(self, client, auth, admin, venue):
        order = _order(client, auth, venue)
        client.patch(f"/api/v1/orders/{order['id']}/status", json={"status": "cancelled"}, headers=admin)

        assert _balance(client, auth, venue)["balance"] == 0

    def test_the_card_shows_the_rate(self, client, venue):
        assert client.get(f"/api/v1/restaurants/{venue['id']}").json()["loyalty_percent"] == 10


class TestSpending:
    @pytest.fixture
    def holding_200(self, client, auth, admin, venue) -> dict:
        _serve(client, admin, _order(client, auth, venue)["id"])
        assert _balance(client, auth, venue)["balance"] == 200
        return venue

    def test_the_cart_is_told_how_much_it_may_use(self, client, auth, holding_200):
        body = _balance(client, auth, holding_200, subtotal=PRICE)

        assert body == {"balance": 200, "percent": 10, "max_share": 0.5, "usable": 200}

    def test_bonuses_come_off_the_total(self, client, auth, holding_200):
        order = _order(client, auth, holding_200, use_loyalty=True)

        assert order["loyalty_spent"] == 200
        assert order["total"] == PRICE - 200
        assert _balance(client, auth, holding_200)["balance"] == 0

    def test_paying_with_bonuses_does_not_earn_on_the_bonuses(self, client, auth, admin, holding_200):
        order = _order(client, auth, holding_200, use_loyalty=True)
        _serve(client, admin, order["id"])

        # 10 % of the 1800 actually paid, not of 2000.
        assert _balance(client, auth, holding_200)["balance"] == 180

    def test_a_cancelled_order_gives_its_bonuses_back(self, client, auth, admin, holding_200):
        order = _order(client, auth, holding_200, use_loyalty=True)
        client.patch(f"/api/v1/orders/{order['id']}/status", json={"status": "cancelled"}, headers=admin)

        assert _balance(client, auth, holding_200)["balance"] == 200

    def test_not_asking_to_use_them_keeps_them(self, client, auth, holding_200):
        order = _order(client, auth, holding_200)

        assert order["loyalty_spent"] == 0
        assert order["total"] == PRICE

    def test_the_share_cap_holds(self, client, auth, admin, holding_200):
        client.put(
            f"/api/v1/admin/restaurants/{holding_200['id']}/loyalty",
            json={"percent": 10, "max_share": 0.05},
            headers=admin,
        )

        order = _order(client, auth, holding_200, use_loyalty=True)

        assert order["loyalty_spent"] == 100  # 5 % of 2000, though 200 are held

    def test_the_diner_sees_their_balances(self, client, auth, holding_200):
        mine = client.get("/api/v1/me/loyalty", headers=auth).json()

        assert {"restaurant_id": holding_200["id"], "balance": 200} in [
            {"restaurant_id": row["restaurant_id"], "balance": row["balance"]} for row in mine
        ]


class TestWhoMaySwitchItOn:
    def test_a_plan_without_the_feature_cannot(self, client, admin):
        rid = client.post(
            "/api/v1/admin/restaurants",
            json={"name": f"Basic Cafe {next(_names)}", "cuisine": "Test"},
            headers=admin,
        ).json()["id"]
        client.patch(f"/api/v1/admin/restaurants/{rid}", json={"plan_code": "pro"}, headers=admin)

        on = client.put(f"/api/v1/admin/restaurants/{rid}/loyalty", json={"percent": 5}, headers=admin)
        off = client.put(f"/api/v1/admin/restaurants/{rid}/loyalty", json={"percent": 0}, headers=admin)

        assert on.status_code == 403
        assert "Premium" in on.json()["detail"]
        assert off.status_code == 200

    def test_a_diner_cannot(self, client, auth, venue):
        r = client.put(f"/api/v1/admin/restaurants/{venue['id']}/loyalty", json={"percent": 5}, headers=auth)

        assert r.status_code == 403

    def test_a_silly_rate_is_refused(self, client, admin, venue):
        r = client.put(f"/api/v1/admin/restaurants/{venue['id']}/loyalty", json={"percent": 80}, headers=admin)

        assert r.status_code == 422

    def test_a_venue_that_stops_paying_stops_giving(self, client, auth, admin, venue):
        client.patch(f"/api/v1/admin/restaurants/{venue['id']}", json={"plan_code": "pro"}, headers=admin)
        order = _order(client, auth, venue)
        _serve(client, admin, order["id"])

        assert client.get(f"/api/v1/restaurants/{venue['id']}").json()["loyalty_percent"] == 0
        assert _balance(client, auth, venue)["balance"] == 0
