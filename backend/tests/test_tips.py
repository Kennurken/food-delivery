"""A tip for the courier.

It is the diner's money for the courier and nobody else's: it rides on the
total, goes into the payout whole (the delivery fee is shared, the tip is
not), and is refused where there is no courier to give it to.
"""

import pytest

from app.core.config import settings
from tests.conftest import deliver


def _order(client, auth, **extra) -> dict:
    menu = client.get("/api/v1/restaurants/1/menu").json()
    body = {
        "restaurant_id": 1,
        "address": "Abay 10",
        "dest_lat": 43.2389,
        "dest_lng": 76.9455,
        "items": [{"menu_item_id": menu[0]["id"], "quantity": 1}],
        **extra,
    }
    return client.post("/api/v1/orders", json=body, headers=auth)


def _serve(client, admin, courier, oid: int) -> None:
    client.patch(f"/api/v1/orders/{oid}/status", json={"status": "confirmed"}, headers=admin)
    client.post(f"/api/v1/orders/{oid}/accept", headers=courier)
    client.patch(f"/api/v1/orders/{oid}/status", json={"status": "preparing"}, headers=admin)
    client.post(f"/api/v1/orders/{oid}/advance", headers=courier)


class TestPricing:
    def test_a_tip_rides_on_the_total(self, client, auth):
        plain = _order(client, auth).json()
        tipped = _order(client, auth, tip=500).json()

        assert tipped["tip"] == 500
        assert tipped["total"] == plain["total"] + 500
        assert tipped["subtotal"] == plain["subtotal"]
        assert tipped["delivery_fee"] == plain["delivery_fee"]

    def test_no_tip_is_zero(self, client, auth):
        assert _order(client, auth).json()["tip"] == 0

    def test_a_tip_is_not_discounted_by_bonuses_or_promos(self, client, auth):
        # Spending bonuses/promos lowers the food; the tip stays what was given.
        base = _order(client, auth, tip=300).json()

        assert base["total"] - 300 == base["subtotal"] + base["delivery_fee"] - base["discount"]

    @pytest.mark.parametrize("bad", [-1, 50_001])
    def test_a_negative_or_absurd_tip_is_refused(self, client, auth, bad):
        assert _order(client, auth, tip=bad).status_code == 422

    def test_pickup_has_no_courier_to_tip(self, client, auth):
        r = _order(client, auth, channel="pickup", tip=200)

        assert r.status_code == 400
        assert "only on delivery" in r.json()["detail"]


class TestPayout:
    def test_the_courier_gets_the_whole_tip_on_top_of_their_share(
        self, client, auth, admin, courier
    ):
        order = _order(client, auth, tip=700).json()
        _serve(client, admin, courier, order["id"])
        deliver(client, order["id"], courier, auth)

        row = next(
            r
            for r in client.get("/api/v1/me/earnings/history", headers=courier).json()["items"]
            if r["order_id"] == order["id"]
        )

        expected = round(order["delivery_fee"] * settings.courier_fee_share + 700, 2)
        assert row["payout"] == expected

    def test_without_a_tip_nothing_changed(self, client, auth, admin, courier):
        order = _order(client, auth).json()
        _serve(client, admin, courier, order["id"])
        deliver(client, order["id"], courier, auth)

        row = next(
            r
            for r in client.get("/api/v1/me/earnings/history", headers=courier).json()["items"]
            if r["order_id"] == order["id"]
        )

        assert row["payout"] == round(order["delivery_fee"] * settings.courier_fee_share, 2)

    def test_cash_the_courier_holds_includes_the_tip(self, client, auth, admin, courier):
        order = _order(client, auth, tip=400).json()
        _serve(client, admin, courier, order["id"])
        deliver(client, order["id"], courier, auth)

        row = next(
            r
            for r in client.get("/api/v1/me/earnings/history", headers=courier).json()["items"]
            if r["order_id"] == order["id"]
        )

        # The diner handed over the total, tip included.
        assert row["cash_held"] == order["total"]
