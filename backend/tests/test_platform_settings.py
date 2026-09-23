"""Plan, limits and per-venue feature overrides.

The point of these is the difference between "on because the plan says so" and
"on because someone forced it" — a settings screen that cannot tell them apart
cannot offer to put a flag back.
"""

FEATURES = "/api/v1/admin/restaurants/1/features"


def _feature(body: dict, key: str) -> dict:
    return next(row for row in body["features"] if row["key"] == key)


def _reset(client, admin, key: str) -> None:
    client.delete(f"{FEATURES}/{key}", headers=admin)


def test_only_the_platform_operator_sees_the_switches(client, auth, courier):
    assert client.get(FEATURES, headers=auth).status_code == 403
    assert client.get(FEATURES, headers=courier).status_code == 403


def test_every_known_flag_is_listed(client, admin):
    from app.core.features import FEATURE_KEYS

    body = client.get(FEATURES, headers=admin).json()

    assert [row["key"] for row in body["features"]] == list(FEATURE_KEYS)


def test_a_plan_feature_reads_as_inherited(client, admin):
    body = client.get(FEATURES, headers=admin).json()

    row = _feature(body, "catalog")
    assert row["in_plan"] is True
    assert row["override"] is None
    assert row["enabled"] is True


def test_forcing_a_flag_on_is_visible_as_an_override(client, admin):
    try:
        client.put(FEATURES, json={"key": "inventory", "enabled": True}, headers=admin)

        row = _feature(client.get(FEATURES, headers=admin).json(), "inventory")

        assert row["in_plan"] is False  # Pro does not include it
        assert row["override"] is True
        assert row["enabled"] is True
    finally:
        _reset(client, admin, "inventory")


def test_forcing_a_plan_feature_off_is_visible_too(client, admin):
    try:
        client.put(FEATURES, json={"key": "reservations", "enabled": False}, headers=admin)

        row = _feature(client.get(FEATURES, headers=admin).json(), "reservations")

        assert row["in_plan"] is True
        assert row["override"] is False
        assert row["enabled"] is False
    finally:
        _reset(client, admin, "reservations")


def test_clearing_an_override_returns_the_flag_to_the_plan(client, admin):
    """Without this an override is permanent and nobody can see why."""
    client.put(FEATURES, json={"key": "reservations", "enabled": False}, headers=admin)
    assert _feature(client.get(FEATURES, headers=admin).json(), "reservations")["enabled"] is False

    r = client.delete(f"{FEATURES}/reservations", headers=admin)

    assert r.status_code == 204
    row = _feature(client.get(FEATURES, headers=admin).json(), "reservations")
    assert row["override"] is None
    assert row["enabled"] is True


def test_clearing_a_flag_that_was_never_overridden_is_harmless(client, admin):
    r = client.delete(f"{FEATURES}/kds", headers=admin)

    assert r.status_code == 204


def test_an_unknown_restaurant_is_not_found(client, admin):
    assert client.get("/api/v1/admin/restaurants/99999/features",
                      headers=admin).status_code == 404


def test_the_limits_come_from_the_plan(client, admin):
    body = client.get(FEATURES, headers=admin).json()

    assert "staff.max" in body["limits"]
    assert body["plan_code"]


def test_changing_the_plan_changes_what_is_inherited(client, admin):
    before = _feature(client.get(FEATURES, headers=admin).json(), "inventory")
    assert before["in_plan"] is False

    client.patch("/api/v1/admin/restaurants/1", json={"plan_code": "premium"}, headers=admin)
    try:
        after = _feature(client.get(FEATURES, headers=admin).json(), "inventory")
        assert after["in_plan"] is True
        assert after["override"] is None
    finally:
        client.patch("/api/v1/admin/restaurants/1", json={"plan_code": "pro"}, headers=admin)


def test_an_override_survives_a_plan_change_and_still_reads_as_forced(client, admin):
    """This is exactly why clearing has to exist: the flag does not follow the
    plan until someone removes the override."""
    client.put(FEATURES, json={"key": "inventory", "enabled": True}, headers=admin)
    client.patch("/api/v1/admin/restaurants/1", json={"plan_code": "basic"}, headers=admin)
    try:
        row = _feature(client.get(FEATURES, headers=admin).json(), "inventory")
        assert row["in_plan"] is False
        assert row["override"] is True
        assert row["enabled"] is True
    finally:
        client.patch("/api/v1/admin/restaurants/1", json={"plan_code": "pro"}, headers=admin)
        _reset(client, admin, "inventory")
