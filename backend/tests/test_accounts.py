"""Leaving, changing a password, and being let back in by the platform."""

import secrets

import pytest

from app.db.session import SessionLocal
from app.models import Order, OrderStatus, User


def _signup(client) -> dict:
    email = f"leaver.{secrets.token_hex(3)}@food.dev"
    r = client.post(
        "/api/v1/auth/register", json={"email": email, "name": "Leaver", "password": "secret123"}
    )
    body = r.json()
    return {
        "email": email,
        "id": body["user"]["id"],
        "headers": {"Authorization": f"Bearer {body['access_token']}"},
        "refresh": body["refresh_token"],
    }


def _login(client, email, password):
    return client.post("/api/v1/auth/login/json", json={"email": email, "password": password})


@pytest.fixture
def person(client) -> dict:
    return _signup(client)


class TestDeleting:
    def test_it_needs_the_password(self, client, person):
        r = client.request("DELETE", "/api/v1/me", json={"password": "nope"}, headers=person["headers"])

        assert r.status_code == 400

    def test_it_signs_out_and_the_login_stops_working(self, client, person):
        r = client.request(
            "DELETE", "/api/v1/me", json={"password": "secret123"}, headers=person["headers"]
        )

        assert r.status_code == 204
        assert client.get("/api/v1/auth/me", headers=person["headers"]).status_code == 401
        assert client.post("/api/v1/auth/refresh", json={"refresh_token": person["refresh"]}).status_code == 401
        assert _login(client, person["email"], "secret123").status_code == 401

    def test_orders_stay_but_the_person_is_gone(self, client, person):
        menu = client.get("/api/v1/restaurants/1/menu").json()
        oid = client.post(
            "/api/v1/orders",
            json={"restaurant_id": 1, "channel": "pickup",
                  "items": [{"menu_item_id": menu[0]["id"], "quantity": 1}]},
            headers=person["headers"],
        ).json()["id"]
        client.post(f"/api/v1/orders/{oid}/messages", json={"body": "без лука"}, headers=person["headers"])
        with SessionLocal() as db:
            db.get(Order, oid).status = OrderStatus.delivered
            db.commit()
        client.post("/api/v1/me/addresses", json={"line": "Abay 1"}, headers=person["headers"])

        r = client.request(
            "DELETE", "/api/v1/me", json={"password": "secret123"}, headers=person["headers"]
        )

        assert r.status_code == 204
        with SessionLocal() as db:
            user = db.get(User, person["id"])
            assert user.name == "Deleted user" and user.phone is None
            assert user.email.endswith("@deleted.invalid")
            assert not user.addresses
            order = db.get(Order, oid)
            assert order is not None and order.user_id == person["id"]
            from app.models.message import OrderMessage

            names = {m.sender_name for m in db.query(OrderMessage).filter_by(order_id=oid)}
            assert names == {"Deleted user"}

    def test_not_while_an_order_is_in_progress(self, client, person):
        menu = client.get("/api/v1/restaurants/1/menu").json()
        client.post(
            "/api/v1/orders",
            json={"restaurant_id": 1, "channel": "pickup",
                  "items": [{"menu_item_id": menu[0]["id"], "quantity": 1}]},
            headers=person["headers"],
        )

        r = client.request(
            "DELETE", "/api/v1/me", json={"password": "secret123"}, headers=person["headers"]
        )

        assert r.status_code == 409 and "in progress" in r.json()["detail"]

    def test_not_while_owning_a_restaurant(self, client):
        applied = client.post(
            "/api/v1/partners/apply",
            json={
                "venue_name": f"Owned {secrets.token_hex(2)}", "cuisine": "Kazakh",
                "contact_name": "Owner Name", "email": f"own.{secrets.token_hex(3)}@cafe.kz",
                "phone": "+77011234567", "password": "ownerpass123", "has_couriers": False,
            },
        ).json()
        headers = {"Authorization": f"Bearer {applied['access_token']}"}

        r = client.request("DELETE", "/api/v1/me", json={"password": "ownerpass123"}, headers=headers)

        assert r.status_code == 409 and "restaurant" in r.json()["detail"]

    def test_a_platform_admin_cannot(self, client, admin):
        r = client.request("DELETE", "/api/v1/me", json={"password": "admin123"}, headers=admin)

        assert r.status_code == 409


class TestResettingByHand:
    def test_the_platform_hands_out_a_temporary_password(self, client, admin, person):
        r = client.post(
            "/api/v1/platform/users/reset-password", json={"email": person["email"]}, headers=admin
        )

        assert r.status_code == 200
        temporary = r.json()["temporary_password"]
        assert _login(client, person["email"], temporary).status_code == 200
        assert _login(client, person["email"], "secret123").status_code == 401

    def test_old_sessions_end(self, client, admin, person):
        client.post("/api/v1/platform/users/reset-password", json={"email": person["email"]}, headers=admin)

        assert client.get("/api/v1/auth/me", headers=person["headers"]).status_code == 401

    def test_only_the_platform_may(self, client, auth, person):
        r = client.post(
            "/api/v1/platform/users/reset-password", json={"email": person["email"]}, headers=auth
        )

        assert r.status_code == 403

    def test_unknown_and_admin_accounts_are_refused(self, client, admin):
        unknown = client.post(
            "/api/v1/platform/users/reset-password", json={"email": "nobody@x.kz"}, headers=admin
        )
        boss = client.post(
            "/api/v1/platform/users/reset-password", json={"email": "admin@food.dev"}, headers=admin
        )

        assert (unknown.status_code, boss.status_code) == (404, 409)


class TestSessions:
    def test_a_token_from_before_a_reset_is_dead_everywhere(self, client, admin, person):
        client.post("/api/v1/platform/users/reset-password", json={"email": person["email"]}, headers=admin)

        assert client.get("/api/v1/me/addresses", headers=person["headers"]).status_code == 401
        assert client.post("/api/v1/auth/refresh", json={"refresh_token": person["refresh"]}).status_code == 401

    def test_a_token_without_a_version_still_works_until_the_first_bump(self, client, person):
        from datetime import timedelta

        from app.core.security import _encode

        old_style = _encode(str(person["id"]), "access", timedelta(minutes=5))  # ver=0 by default
        r = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {old_style}"})

        assert r.status_code == 200

    def test_changing_your_own_password_keeps_you_signed_in(self, client, person):
        r = client.post(
            "/api/v1/me/password",
            json={"current_password": "secret123", "new_password": "secret456"},
            headers=person["headers"],
        )

        assert r.status_code == 204
        assert client.get("/api/v1/auth/me", headers=person["headers"]).status_code == 200


def test_meta_tells_the_app_where_the_legal_pages_are(client):
    body = client.get("/api/v1/meta").json()

    assert body["privacy_url"].endswith("/privacy/") and body["terms_url"].endswith("/terms/")
    assert body["support_email"] is None and body["support_phone"] is None
