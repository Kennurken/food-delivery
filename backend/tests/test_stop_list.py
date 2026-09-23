"""Who may stop a dish, and what stopping it actually does.

Menu endpoints used to be platform-admin only: the permission `menu.write`
existed in the model and was checked nowhere, so a restaurant's own owner could
not edit their own menu. These pin the tenant-scoped behaviour down.
"""

import secrets

import pytest

STOP = "/api/v1/admin/restaurants/1/stop-list"


def _login(client, email: str, password: str) -> dict:
    r = client.post("/api/v1/auth/login/json", json={"email": email, "password": password})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


@pytest.fixture
def owner(client):
    """Seeded owner of restaurant 1."""
    return _login(client, "owner.bao@food.dev", "owner123")


@pytest.fixture
def cook(client, admin):
    """A kitchen-role member of restaurant 1."""
    email = f"cook.{secrets.token_hex(3)}@food.dev"
    client.post(
        "/api/v1/auth/register",
        json={"email": email, "name": "Cook", "password": "cookpass1"},
    )
    r = client.post(
        "/api/v1/admin/restaurants/1/staff",
        json={"email": email, "role": "kitchen"},
        headers=admin,
    )
    assert r.status_code in (200, 201), r.text
    return _login(client, email, "cookpass1")


@pytest.fixture
def dish(client, admin):
    return client.get("/api/v1/restaurants/1/menu").json()[0]


@pytest.fixture(autouse=True)
def _restore(client, admin, dish):
    """Never leave the shared menu on stop — other tests order from it."""
    yield
    client.post(
        STOP, json={"item_ids": [dish["id"]], "available": True}, headers=admin
    )


class TestWhoMayEditTheMenu:
    def test_the_owner_can_edit_their_own_menu(self, client, owner, dish):
        r = client.patch(
            f"/api/v1/admin/menu/{dish['id']}", json={"price": 1600}, headers=owner
        )

        assert r.status_code == 200, r.text
        client.patch(
            f"/api/v1/admin/menu/{dish['id']}",
            json={"price": dish["price"]},
            headers=owner,
        )

    def test_the_owner_cannot_touch_another_venues_menu(self, client, owner):
        stranger = client.get("/api/v1/restaurants/2/menu").json()[0]

        r = client.patch(
            f"/api/v1/admin/menu/{stranger['id']}", json={"price": 1}, headers=owner
        )

        assert r.status_code == 403

    def test_a_customer_cannot_edit_any_menu(self, client, auth, dish):
        r = client.patch(
            f"/api/v1/admin/menu/{dish['id']}", json={"price": 1}, headers=auth
        )

        assert r.status_code in (403, 404)


class TestKitchenCanStopButNotRewrite:
    def test_a_cook_can_stop_a_dish(self, client, cook, dish):
        r = client.patch(
            f"/api/v1/admin/menu/{dish['id']}",
            json={"is_available": False},
            headers=cook,
        )

        assert r.status_code == 200, r.text
        assert r.json()["is_available"] is False

    def test_a_cook_cannot_change_the_price(self, client, cook, dish):
        """Stopping a dish is a shift action; repricing it is not."""
        r = client.patch(
            f"/api/v1/admin/menu/{dish['id']}", json={"price": 1}, headers=cook
        )

        assert r.status_code == 403

    def test_a_cook_cannot_smuggle_a_price_in_beside_availability(self, client, cook, dish):
        r = client.patch(
            f"/api/v1/admin/menu/{dish['id']}",
            json={"is_available": False, "price": 1},
            headers=cook,
        )

        assert r.status_code == 403
        assert client.get("/api/v1/restaurants/1/menu").json()[0]["price"] == dish["price"]

    def test_a_cook_cannot_delete_a_dish(self, client, cook, dish):
        r = client.delete(f"/api/v1/admin/menu/{dish['id']}", headers=cook)

        assert r.status_code == 403


class TestStopList:
    def test_it_lists_only_what_is_off(self, client, admin, dish):
        assert client.get(STOP, headers=admin).json() == []

        client.post(STOP, json={"item_ids": [dish["id"]], "available": False}, headers=admin)

        off = client.get(STOP, headers=admin).json()
        assert [row["id"] for row in off] == [dish["id"]]

    def test_a_whole_menu_comes_back_in_one_call(self, client, admin):
        """Restoring one dish at a time is how something stays off for a week."""
        menu = client.get("/api/v1/restaurants/1/menu").json()
        ids = [row["id"] for row in menu]
        client.post(STOP, json={"item_ids": ids, "available": False}, headers=admin)
        assert len(client.get(STOP, headers=admin).json()) == len(ids)

        client.post(STOP, json={"item_ids": ids, "available": True}, headers=admin)

        assert client.get(STOP, headers=admin).json() == []

    def test_an_id_from_another_menu_is_ignored(self, client, admin):
        """Never silently flip a dish that belongs to someone else."""
        stranger = client.get("/api/v1/restaurants/2/menu").json()[0]

        touched = client.post(
            STOP, json={"item_ids": [stranger["id"]], "available": False}, headers=admin
        ).json()

        assert touched == []
        assert client.get("/api/v1/restaurants/2/menu").json()[0]["is_available"] is True

    def test_a_cook_may_restore_the_menu(self, client, cook, admin, dish):
        client.post(STOP, json={"item_ids": [dish["id"]], "available": False}, headers=admin)

        r = client.post(
            STOP, json={"item_ids": [dish["id"]], "available": True}, headers=cook
        )

        assert r.status_code == 200, r.text

    def test_a_courier_may_not(self, client, courier, dish):
        r = client.post(
            STOP, json={"item_ids": [dish["id"]], "available": False}, headers=courier
        )

        assert r.status_code in (403, 404)


class TestAStoppedDishIsReallyGone:
    def test_it_cannot_be_ordered(self, client, admin, auth, dish):
        client.post(STOP, json={"item_ids": [dish["id"]], "available": False}, headers=admin)

        r = client.post(
            "/api/v1/orders",
            json={
                "restaurant_id": 1,
                "address": "Abay 10",
                "items": [{"menu_item_id": dish["id"], "quantity": 1}],
                "pay_method": "cash",
            },
            headers=auth,
        )

        assert r.status_code == 400
        assert "unavailable" in r.text.lower()

    def test_it_disappears_from_the_public_page(self, client, admin, dish):
        client.post(STOP, json={"item_ids": [dish["id"]], "available": False}, headers=admin)

        page = client.get("/r/bao-bar/").text

        assert dish["name"] not in page
