def test_default_modifiers_keep_base_price(client, auth):
    menu = client.get("/api/v1/restaurants/1/menu").json()
    bao = next(i for i in menu if i["name"] == "Pork Bao")
    assert bao["modifier_groups"]
    r = client.post(
        "/api/v1/orders",
        json={
            "restaurant_id": 1,
            "address": "Abay 10",
            "items": [{"menu_item_id": bao["id"], "quantity": 1}],
        },
        headers=auth,
    )
    assert r.status_code == 201, r.text
    order = r.json()
    assert order["subtotal"] == bao["price"]
    assert order["pay_method"] == "cash"
    assert order["pay_status"] == "unpaid"
    names = [m["name"] for m in order["items"][0]["modifiers"]]
    assert "Regular" in names


def test_size_and_extras_add_to_line(client, auth):
    menu = client.get("/api/v1/restaurants/1/menu").json()
    bao = next(i for i in menu if i["name"] == "Pork Bao")
    size = next(g for g in bao["modifier_groups"] if g["name"] == "Size")
    extras = next(g for g in bao["modifier_groups"] if g["name"] == "Extras")
    large = next(o for o in size["options"] if o["name"] == "Large")
    egg = next(o for o in extras["options"] if o["name"] == "Egg")
    r = client.post(
        "/api/v1/orders",
        json={
            "restaurant_id": 1,
            "address": "Abay 10",
            "items": [
                {
                    "menu_item_id": bao["id"],
                    "quantity": 2,
                    "option_ids": [large["id"], egg["id"]],
                }
            ],
        },
        headers=auth,
    )
    assert r.status_code == 201, r.text
    unit = bao["price"] + large["price_delta"] + egg["price_delta"]
    assert r.json()["subtotal"] == unit * 2
    assert r.json()["items"][0]["price"] == unit


def test_missing_required_size_rejected_when_defaults_cleared(client, admin, auth):
    menu = client.get("/api/v1/restaurants/1/menu").json()
    bao = next(i for i in menu if i["name"] == "Pork Bao")
    r = client.put(
        f"/api/v1/admin/menu/{bao['id']}/modifiers",
        json=[
            {
                "name": "Size",
                "required": True,
                "min_select": 1,
                "max_select": 1,
                "options": [{"name": "Large", "price_delta": 400, "is_default": False}],
            }
        ],
        headers=admin,
    )
    assert r.status_code == 200, r.text
    miss = client.post(
        "/api/v1/orders",
        json={
            "restaurant_id": 1,
            "address": "Abay 10",
            "items": [{"menu_item_id": bao["id"], "quantity": 1, "option_ids": []}],
        },
        headers=auth,
    )
    assert miss.status_code == 400
    # restore seed-like defaults so later tests stay stable
    client.put(
        f"/api/v1/admin/menu/{bao['id']}/modifiers",
        json=[
            {
                "name": "Size",
                "required": True,
                "min_select": 1,
                "max_select": 1,
                "options": [
                    {"name": "Regular", "price_delta": 0, "is_default": True},
                    {"name": "Large", "price_delta": 400, "is_default": False},
                ],
            },
            {
                "name": "Extras",
                "required": False,
                "min_select": 0,
                "max_select": 3,
                "options": [
                    {"name": "Egg", "price_delta": 200},
                    {"name": "Chili oil", "price_delta": 100},
                ],
            },
        ],
        headers=admin,
    )


def test_card_checkout_stays_honest(client, auth):
    menu = client.get("/api/v1/restaurants/1/menu").json()
    r = client.post(
        "/api/v1/orders",
        json={
            "restaurant_id": 1,
            "address": "Abay 10",
            "pay_method": "online",
            "items": [{"menu_item_id": menu[0]["id"], "quantity": 1}],
        },
        headers=auth,
    )
    assert r.status_code == 409
    assert "cash" in r.json()["detail"].lower()


def test_unknown_modifier_rejected(client, auth):
    menu = client.get("/api/v1/restaurants/1/menu").json()
    bao = next(i for i in menu if i["name"] == "Pork Bao")
    size = next(g for g in bao["modifier_groups"] if g["name"] == "Size")
    regular = next(o for o in size["options"] if o["name"] == "Regular")
    r = client.post(
        "/api/v1/orders",
        json={
            "restaurant_id": 1,
            "address": "Abay 10",
            "items": [
                {
                    "menu_item_id": bao["id"],
                    "quantity": 1,
                    "option_ids": [regular["id"], 9_999_999],
                }
            ],
        },
        headers=auth,
    )
    assert r.status_code == 400


def test_push_is_noop_without_key():
    from app.core.push import send

    assert send(["token-long-enough"], title="Order", body="Hi", data={}) == 0


def test_device_token_roundtrip(client, auth):
    r = client.put(
        "/api/v1/me/devices",
        json={"token": "fcm-token-example-1", "platform": "android"},
        headers=auth,
    )
    assert r.status_code == 204
    r = client.delete(
        "/api/v1/me/devices",
        params={"token": "fcm-token-example-1"},
        headers=auth,
    )
    assert r.status_code == 204
