"""A welcome offer: a promo that only someone new to the venue can use.

The venue pays for every promo, so the rule that matters is that "new" means
new — no order at this venue that wasn't cancelled — and that the answer is the
same whether asked in the cart or at checkout.
"""

import itertools
import secrets

import pytest

_n = itertools.count(1)


@pytest.fixture
def venue(client, admin) -> dict:
    rid = client.post(
        "/api/v1/admin/restaurants",
        json={"name": f"Welcome Cafe {next(_n)}", "cuisine": "Test"},
        headers=admin,
    ).json()["id"]
    client.patch(f"/api/v1/admin/restaurants/{rid}", json={"plan_code": "premium"}, headers=admin)
    dish = client.post(
        f"/api/v1/admin/restaurants/{rid}/menu",
        json={"name": "Beshbarmak", "price": 3000, "category": "Main"},
        headers=admin,
    ).json()["id"]
    made = client.post(
        f"/api/v1/admin/restaurants/{rid}/promos",
        json={"code": "WELCOME", "kind": "percent", "value": 20, "new_customers_only": True},
        headers=admin,
    )
    assert made.status_code == 201, made.text
    assert made.json()["new_customers_only"] is True
    return {"id": rid, "dish": dish}


def _diner(client) -> dict:
    r = client.post(
        "/api/v1/auth/register",
        json={"email": f"new.{secrets.token_hex(3)}@food.dev", "password": "newdiner123", "name": "New"},
    )
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _order(client, venue, who, **extra):
    return client.post(
        "/api/v1/orders",
        json={
            "restaurant_id": venue["id"],
            "channel": "pickup",
            "items": [{"menu_item_id": venue["dish"], "quantity": 1}],
            **extra,
        },
        headers=who,
    )


def _preview(client, venue, who=None):
    return client.get(
        f"/api/v1/restaurants/{venue['id']}/promo",
        params={"code": "WELCOME", "subtotal": 3000},
        headers=who or {},
    )


class TestPreview:
    def test_a_new_guest_is_offered_it(self, client, venue):
        r = _preview(client, venue, _diner(client))

        assert r.status_code == 200
        assert r.json()["discount"] == 600

    def test_someone_not_signed_in_is_asked_to_sign_in(self, client, venue):
        r = _preview(client, venue)

        assert r.status_code == 400
        assert "Sign in" in r.json()["detail"]

    def test_a_returning_guest_is_told_it_is_not_for_them(self, client, venue):
        diner = _diner(client)
        _order(client, venue, diner)

        r = _preview(client, venue, diner)

        assert r.status_code == 400
        assert "haven't ordered here yet" in r.json()["detail"]


class TestCheckout:
    def test_a_new_guest_gets_the_discount(self, client, venue):
        order = _order(client, venue, _diner(client), promo_code="WELCOME").json()

        assert order["discount"] == 600
        assert order["total"] == 2400

    def test_the_second_order_cannot_use_it_again(self, client, venue):
        diner = _diner(client)
        assert _order(client, venue, diner, promo_code="WELCOME").status_code == 201

        r = _order(client, venue, diner, promo_code="WELCOME")

        assert r.status_code == 400

    def test_a_cancelled_first_order_leaves_them_new(self, client, venue):
        diner = _diner(client)
        first = _order(client, venue, diner).json()
        client.post(f"/api/v1/orders/{first['id']}/cancel", headers=diner)

        assert _order(client, venue, diner, promo_code="WELCOME").status_code == 201

    def test_ordering_elsewhere_does_not_make_them_old_here(self, client, venue):
        diner = _diner(client)
        menu = client.get("/api/v1/restaurants/1/menu").json()
        client.post(
            "/api/v1/orders",
            json={"restaurant_id": 1, "channel": "pickup",
                  "items": [{"menu_item_id": menu[0]["id"], "quantity": 1}]},
            headers=diner,
        )

        assert _order(client, venue, diner, promo_code="WELCOME").status_code == 201

    def test_an_ordinary_promo_is_unchanged(self, client, admin, venue):
        client.post(
            f"/api/v1/admin/restaurants/{venue['id']}/promos",
            json={"code": "EVERYONE", "kind": "amount", "value": 500},
            headers=admin,
        )
        diner = _diner(client)
        _order(client, venue, diner)

        assert _order(client, venue, diner, promo_code="EVERYONE").status_code == 201
