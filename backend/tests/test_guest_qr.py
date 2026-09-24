"""Ordering at a table without an account.

Making a diner register before they can order at a table they are already
sitting at loses the order. These pin down that a scan is enough — and that
"enough" stops exactly there.
"""

import pytest

from app.core.qr import table_token

GUEST = "/api/v1/auth/guest"


@pytest.fixture
def table(client, admin) -> dict:
    created = client.post(
        "/api/v1/admin/restaurants/1/floors",
        json={"name": "Guest Hall", "template": "cafe"},
        headers=admin,
    )
    assert created.status_code == 201, created.text
    floor = created.json()
    obj = next(o for o in floor["objects"] if o["kind"].startswith("table"))
    return {"token": table_token(1, obj["id"]), "id": obj["id"], "name": obj["name"]}


def _guest(client, token: str) -> dict:
    r = client.post(GUEST, json={"qr_token": token})
    assert r.status_code == 201, r.text
    body = r.json()
    return {"Authorization": f"Bearer {body['access_token']}"}


class TestGettingIn:
    def test_a_scan_is_enough_to_get_a_session(self, client, table):
        r = client.post(GUEST, json={"qr_token": table["token"]})

        assert r.status_code == 201, r.text
        assert r.json()["access_token"]

    def test_the_session_is_marked_as_a_guest(self, client, table):
        headers = _guest(client, table["token"])

        me = client.get("/api/v1/auth/me", headers=headers).json()

        assert me["is_guest"] is True
        # Named after the table, so the kitchen board reads a place, not an id.
        assert table["name"] in me["name"]

    def test_a_made_up_token_gets_nothing(self, client):
        """Otherwise this is an open account factory."""
        r = client.post(GUEST, json={"qr_token": "1.2.deadbeefdeadbeef"})

        assert r.status_code == 404

    def test_a_signed_token_for_nothing_gets_nothing(self, client):
        """The signature proves the numbers were ours, not that they point at
        a table that exists."""
        r = client.post(GUEST, json={"qr_token": table_token(1, 999_999)})

        assert r.status_code == 404

    def test_a_token_for_something_that_is_not_a_table_gets_nothing(
        self, client, admin, table
    ):
        floors = client.get("/api/v1/admin/restaurants/1/floors", headers=admin).json()
        objects = [
            o
            for floor in floors
            for o in client.get(
                f"/api/v1/admin/floors/{floor['id']}", headers=admin
            ).json()["objects"]
            if not o["kind"].startswith("table")
        ]
        if not objects:
            pytest.skip("this floor template has only tables")

        r = client.post(GUEST, json={"qr_token": table_token(1, objects[0]["id"])})

        assert r.status_code == 404

    def test_a_token_pointing_at_the_wrong_restaurant_gets_nothing(
        self, client, table
    ):
        forged = table_token(2, table["id"])

        r = client.post(GUEST, json={"qr_token": forged})

        assert r.status_code == 404

    def test_each_scan_is_its_own_session(self, client, table):
        """Two diners at two tables must not share an order history."""
        first = _guest(client, table["token"])
        second = _guest(client, table["token"])

        a = client.get("/api/v1/auth/me", headers=first).json()["id"]
        b = client.get("/api/v1/auth/me", headers=second).json()["id"]

        assert a != b


class TestWhatAGuestCanDo:
    def test_a_guest_orders_at_the_table(self, client, table):
        headers = _guest(client, table["token"])
        menu = client.get("/api/v1/restaurants/1/menu").json()

        r = client.post(
            "/api/v1/orders",
            json={
                "restaurant_id": 1,
                "qr_token": table["token"],
                "items": [{"menu_item_id": menu[0]["id"], "quantity": 1}],
            },
            headers=headers,
        )

        assert r.status_code == 201, r.text
        order = r.json()
        assert order["channel"] == "qr_table"
        assert order["delivery_fee"] == 0

    def test_a_guest_follows_their_own_order(self, client, table):
        headers = _guest(client, table["token"])
        menu = client.get("/api/v1/restaurants/1/menu").json()
        oid = client.post(
            "/api/v1/orders",
            json={
                "restaurant_id": 1,
                "qr_token": table["token"],
                "items": [{"menu_item_id": menu[0]["id"], "quantity": 1}],
            },
            headers=headers,
        ).json()["id"]

        assert client.get(f"/api/v1/orders/{oid}", headers=headers).status_code == 200

    def test_one_guest_cannot_read_anothers_order(self, client, table):
        first = _guest(client, table["token"])
        second = _guest(client, table["token"])
        menu = client.get("/api/v1/restaurants/1/menu").json()
        oid = client.post(
            "/api/v1/orders",
            json={
                "restaurant_id": 1,
                "qr_token": table["token"],
                "items": [{"menu_item_id": menu[0]["id"], "quantity": 1}],
            },
            headers=first,
        ).json()["id"]

        assert client.get(f"/api/v1/orders/{oid}", headers=second).status_code == 404

    def test_a_guest_is_not_staff(self, client, table):
        headers = _guest(client, table["token"])

        assert client.get("/api/v1/platform/overview", headers=headers).status_code == 403
        assert (
            client.get("/api/v1/admin/restaurants/1/stats", headers=headers).status_code
            in (403, 404)
        )

    def test_a_guest_cannot_take_deliveries(self, client, table):
        headers = _guest(client, table["token"])

        assert client.get("/api/v1/orders/available", headers=headers).status_code == 403

    def test_the_guest_account_cannot_be_logged_into(self, client, table):
        """No password anyone knows, and the address it carries is on a domain
        that cannot receive mail — the login form will not even take it."""
        headers = _guest(client, table["token"])
        email = client.get("/api/v1/auth/me", headers=headers).json()["email"]
        assert email.endswith("@qr.invalid")

        r = client.post(
            "/api/v1/auth/login/json", json={"email": email, "password": "guest"}
        )

        assert r.status_code != 200
        assert "access_token" not in r.text
