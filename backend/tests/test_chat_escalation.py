"""A member of staff calling the venue's manager into a conversation."""

import itertools

import pytest

from app.services import chat

_n = itertools.count(1)
VENUE = 1


def _person(client) -> tuple[dict, str, int]:
    email = f"staff{next(_n)}@own.kz"
    r = client.post(
        "/api/v1/auth/register", json={"email": email, "name": "Staff", "password": "secret12"}
    )
    headers = {"Authorization": f"Bearer {r.json()['access_token']}"}
    return headers, email, client.get("/api/v1/auth/me", headers=headers).json()["id"]


def _hire(client, admin, email: str, role: str) -> None:
    r = client.post(
        f"/api/v1/admin/restaurants/{VENUE}/staff", json={"email": email, "role": role}, headers=admin
    )
    assert r.status_code == 201, r.text


@pytest.fixture
def order_id(client, auth) -> int:
    menu = client.get(f"/api/v1/restaurants/{VENUE}/menu").json()
    r = client.post(
        "/api/v1/orders",
        json={
            "restaurant_id": VENUE,
            "channel": "pickup",
            "items": [{"menu_item_id": menu[0]["id"], "quantity": 1}],
        },
        headers=auth,
    )
    assert r.status_code == 201, r.text
    return r.json()["id"]


@pytest.fixture
def cashier(client, admin):
    headers, email, uid = _person(client)
    _hire(client, admin, email, "cashier")
    return {"headers": headers, "id": uid}


@pytest.fixture
def manager(client, admin):
    headers, email, uid = _person(client)
    _hire(client, admin, email, "manager")
    return {"headers": headers, "id": uid}


@pytest.fixture
def pushed(monkeypatch):
    calls = []
    monkeypatch.setattr(
        chat, "push_fanout", lambda db, ids, **kw: calls.append((set(ids), kw))
    )
    return calls


def _escalate(client, order_id, headers):
    return client.post(f"/api/v1/orders/{order_id}/messages/escalate", headers=headers)


def test_staff_calls_the_manager_and_only_managers_are_pushed(
    client, order_id, cashier, manager, pushed
):
    r = _escalate(client, order_id, cashier["headers"])

    assert r.status_code == 201, r.text
    assert r.json()["kind"] == "escalation"
    manager_pushes = [ids for ids, kw in pushed if kw["data"]["cause"] == "escalation"]
    assert manager_pushes and manager["id"] in manager_pushes[0]
    assert cashier["id"] not in manager_pushes[0]


def test_the_line_appears_in_the_thread_for_everyone(client, auth, order_id, cashier, manager):
    _escalate(client, order_id, cashier["headers"])

    thread = client.get(f"/api/v1/orders/{order_id}/messages", headers=auth).json()

    assert [m["kind"] for m in thread] == ["escalation"]


def test_a_second_call_within_ten_minutes_is_refused(client, order_id, cashier, manager):
    assert _escalate(client, order_id, cashier["headers"]).status_code == 201

    assert _escalate(client, order_id, cashier["headers"]).status_code == 409


def test_the_customer_cannot(client, auth, order_id):
    assert _escalate(client, order_id, auth).status_code == 403


def test_a_manager_cannot_call_themselves(client, order_id, manager):
    assert _escalate(client, order_id, manager["headers"]).status_code == 409


def test_a_stranger_sees_nothing(client, order_id):
    headers, _, _ = _person(client)

    assert _escalate(client, order_id, headers).status_code == 404


def test_it_falls_back_to_the_platform_when_there_is_no_manager(
    client, admin, order_id, cashier, pushed
):
    from app.db.session import SessionLocal
    from app.models import RestaurantMember

    with SessionLocal() as db:
        held = [
            (m.id, m.role)
            for m in db.query(RestaurantMember).filter(
                RestaurantMember.restaurant_id == VENUE,
                RestaurantMember.role.in_(chat.MANAGER_ROLES),
            )
        ]
        for mid, _ in held:
            db.get(RestaurantMember, mid).is_active = False
        db.commit()
    try:
        r = _escalate(client, order_id, cashier["headers"])
        assert r.status_code == 201
        admin_id = client.get("/api/v1/auth/me", headers=admin).json()["id"]
        assert any(admin_id in ids for ids, kw in pushed if kw["data"]["cause"] == "escalation")
    finally:
        with SessionLocal() as db:
            for mid, _ in held:
                db.get(RestaurantMember, mid).is_active = True
            db.commit()
