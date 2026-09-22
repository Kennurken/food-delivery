def _place(client, auth, restaurant_id=2):
    menu = client.get(f"/api/v1/restaurants/{restaurant_id}/menu").json()
    r = client.post(
        "/api/v1/orders",
        json={
            "restaurant_id": restaurant_id,
            "address": "Abay 10",
            "items": [{"menu_item_id": menu[0]["id"], "quantity": 1}],
        },
        headers=auth,
    )
    assert r.status_code == 201, r.text
    return r.json()["id"]


def _other_user(client):
    r = client.post(
        "/api/v1/auth/register",
        json={"email": "chat-stranger@x.com", "name": "Stranger", "password": "secret1"},
    )
    assert r.status_code == 201
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def test_customer_and_kitchen_chat(client, auth, admin):
    oid = _place(client, auth, restaurant_id=1)
    empty = client.get(f"/api/v1/orders/{oid}/messages", headers=auth)
    assert empty.status_code == 200
    assert empty.json() == []

    sent = client.post(
        f"/api/v1/orders/{oid}/messages",
        json={"body": "  extra napkins  "},
        headers=auth,
    )
    assert sent.status_code == 201, sent.text
    assert sent.json()["body"] == "extra napkins"
    assert sent.json()["sender_name"] == "Test User"
    assert sent.json()["order_id"] == oid

    cook = client.post(
        "/api/v1/auth/register",
        json={"email": "cook-chat@x.com", "name": "Cook", "password": "secret1"},
    )
    kitchen = {"Authorization": f"Bearer {cook.json()['access_token']}"}
    assert client.get(f"/api/v1/orders/{oid}/messages", headers=kitchen).status_code == 404
    added = client.post(
        "/api/v1/admin/restaurants/1/staff",
        json={"email": "cook-chat@x.com", "role": "kitchen"},
        headers=admin,
    )
    assert added.status_code == 201, added.text
    thread = client.get(f"/api/v1/orders/{oid}/messages", headers=kitchen)
    assert thread.status_code == 200
    assert thread.json()[0]["body"] == "extra napkins"
    reply = client.post(
        f"/api/v1/orders/{oid}/messages",
        json={"body": "on it"},
        headers=kitchen,
    )
    assert reply.status_code == 201
    assert [m["body"] for m in client.get(f"/api/v1/orders/{oid}/messages", headers=auth).json()] == [
        "extra napkins",
        "on it",
    ]


def test_chat_hidden_from_strangers_and_unassigned_couriers(client, auth, courier):
    oid = _place(client, auth)
    stranger = _other_user(client)
    assert client.get(f"/api/v1/orders/{oid}/messages", headers=stranger).status_code == 404
    assert (
        client.post(
            f"/api/v1/orders/{oid}/messages",
            json={"body": "hi"},
            headers=stranger,
        ).status_code
        == 404
    )
    assert client.get(f"/api/v1/orders/{oid}/messages", headers=courier).status_code == 404
    assert (
        client.post(
            f"/api/v1/orders/{oid}/messages",
            json={"body": "on my way"},
            headers=courier,
        ).status_code
        == 404
    )


def test_assigned_courier_can_chat(client, auth, courier, admin):
    oid = _place(client, auth)
    client.patch(f"/api/v1/orders/{oid}/status", json={"status": "confirmed"}, headers=admin)
    assert client.post(f"/api/v1/orders/{oid}/accept", headers=courier).status_code == 200
    r = client.post(
        f"/api/v1/orders/{oid}/messages",
        json={"body": "gate code 12"},
        headers=courier,
    )
    assert r.status_code == 201, r.text
    assert r.json()["sender_name"] == "Courier Bek"


def test_chat_closes_when_order_is_done(client, auth, admin):
    oid = _place(client, auth)
    client.patch(f"/api/v1/orders/{oid}/status", json={"status": "confirmed"}, headers=admin)
    client.patch(f"/api/v1/orders/{oid}/status", json={"status": "preparing"}, headers=admin)
    client.patch(f"/api/v1/orders/{oid}/status", json={"status": "on_the_way"}, headers=admin)
    client.patch(f"/api/v1/orders/{oid}/status", json={"status": "delivered"}, headers=admin)
    r = client.post(
        f"/api/v1/orders/{oid}/messages",
        json={"body": "thanks"},
        headers=auth,
    )
    assert r.status_code == 409
    listed = client.get(f"/api/v1/orders/{oid}/messages", headers=auth)
    assert listed.status_code == 200


def test_empty_chat_rejected(client, auth):
    oid = _place(client, auth)
    assert (
        client.post(
            f"/api/v1/orders/{oid}/messages",
            json={"body": "   "},
            headers=auth,
        ).status_code
        == 422
    )


def test_ws_receives_chat(client, auth):
    token = auth["Authorization"].split()[1]
    with client.websocket_connect(f"/api/v1/ws?token={token}") as ws:
        oid = _place(client, auth)
        assert ws.receive_json()["type"] == "order.updated"
        client.post(
            f"/api/v1/orders/{oid}/messages",
            json={"body": "hello kitchen"},
            headers=auth,
        )
        evt = ws.receive_json()
        assert evt["type"] == "order.chat"
        assert evt["order_id"] == oid
        assert evt["message"]["body"] == "hello kitchen"
