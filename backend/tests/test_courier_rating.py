"""Rating the courier, and what it does to their wallet.

The rule that matters: only a delivery someone carried has a courier to rate,
and the score belongs to the courier who carried it.
"""

import pytest

from tests.conftest import deliver


def _delivered(client, auth, admin, courier, *, pickup: bool = False) -> int:
    menu = client.get("/api/v1/restaurants/1/menu").json()
    body = {
        "restaurant_id": 1,
        "items": [{"menu_item_id": menu[0]["id"], "quantity": 1}],
    }
    body.update({"channel": "pickup"} if pickup else {"address": "Abay 10", "dest_lat": 43.2389, "dest_lng": 76.9455})
    oid = client.post("/api/v1/orders", json=body, headers=auth).json()["id"]
    client.patch(f"/api/v1/orders/{oid}/status", json={"status": "confirmed"}, headers=admin)
    if pickup:
        for step in ("preparing", "on_the_way", "delivered"):
            client.patch(f"/api/v1/orders/{oid}/status", json={"status": step}, headers=admin)
    else:
        client.post(f"/api/v1/orders/{oid}/accept", headers=courier)
        client.patch(f"/api/v1/orders/{oid}/status", json={"status": "preparing"}, headers=admin)
        client.post(f"/api/v1/orders/{oid}/advance", headers=courier)
        deliver(client, oid, courier, auth)
    return oid


def _rate(client, auth, oid, **body):
    return client.post(f"/api/v1/orders/{oid}/rate", json={"rating": 5, **body}, headers=auth)


def _wallet(client, courier) -> dict:
    return client.get("/api/v1/me/earnings", headers=courier).json()


class TestRating:
    def test_a_delivery_can_rate_its_courier(self, client, auth, admin, courier):
        oid = _delivered(client, auth, admin, courier)

        assert _rate(client, auth, oid, courier_rating=4).status_code == 200

    def test_the_courier_score_is_optional(self, client, auth, admin, courier):
        oid = _delivered(client, auth, admin, courier)

        assert _rate(client, auth, oid).status_code == 200

    def test_a_pickup_has_no_courier_to_rate(self, client, auth, admin, courier):
        oid = _delivered(client, auth, admin, courier, pickup=True)

        r = _rate(client, auth, oid, courier_rating=5)

        assert r.status_code == 400
        assert "no courier" in r.json()["detail"]
        # ...and the refusal didn't half-rate the venue.
        assert _rate(client, auth, oid).status_code == 200

    @pytest.mark.parametrize("bad", [0, 6, -1])
    def test_the_score_is_one_to_five(self, client, auth, admin, courier, bad):
        oid = _delivered(client, auth, admin, courier)

        assert _rate(client, auth, oid, courier_rating=bad).status_code == 422


class TestTheWallet:
    def test_the_average_moves_with_each_rating(self, client, auth, admin, courier):
        before = _wallet(client, courier)
        first = _delivered(client, auth, admin, courier)
        second = _delivered(client, auth, admin, courier)
        _rate(client, auth, first, courier_rating=5)
        _rate(client, auth, second, courier_rating=3)

        after = _wallet(client, courier)

        assert after["rated"] == before["rated"] + 2
        # Two known scores, so compare against what the wallet must now hold.
        prior_total = (before["rating"] or 0) * before["rated"]
        assert after["rating"] == round((prior_total + 8) / after["rated"], 2)

    def test_an_unrated_delivery_is_not_counted(self, client, auth, admin, courier):
        before = _wallet(client, courier)
        oid = _delivered(client, auth, admin, courier)
        _rate(client, auth, oid)  # venue only

        assert _wallet(client, courier)["rated"] == before["rated"]

    def test_a_courier_nobody_rated_has_no_score_not_a_zero(self, client, admin):
        # An admin reaches courier routes and has no deliveries of their own.
        body = client.get("/api/v1/me/earnings", headers=admin).json()

        assert body["rating"] is None and body["rated"] == 0
