"""A printable page of table QR codes, opened by a signed link."""

from datetime import UTC, datetime, timedelta

import pytest

from app.core.qr import parse_table_token
from app.services import qr_sheet


@pytest.fixture
def floor(client, admin) -> dict:
    r = client.post(
        "/api/v1/admin/restaurants/1/floors",
        json={"name": "QR Hall", "template": "cafe"},
        headers=admin,
    )
    assert r.status_code == 201, r.text
    body = r.json()
    yield body
    client.delete(f"/api/v1/admin/floors/{body['id']}", headers=admin)


def _tables(floor: dict) -> list[dict]:
    return [o for o in floor["objects"] if o["kind"].startswith("table")]


def _link(client, admin, floor_id: int) -> str:
    r = client.post(f"/api/v1/admin/floors/{floor_id}/qr-sheet", headers=admin)
    assert r.status_code == 200, r.text
    assert r.json()["expires_in"] == 600
    return r.json()["url"]


def _path(url: str) -> str:
    return url[url.index("/api/v1/qr-sheet/") :]


def test_the_page_has_a_code_per_table(client, admin, floor):
    page = client.get(_path(_link(client, admin, floor["id"])))

    assert page.status_code == 200
    assert page.headers["content-type"].startswith("text/html")
    assert page.text.count("<svg") == len(_tables(floor)) > 0
    for t in _tables(floor):
        assert (t["name"] or f"Table {t['id']}") in page.text


def test_it_is_not_cached_or_indexed(client, admin, floor):
    page = client.get(_path(_link(client, admin, floor["id"])))

    assert page.headers["cache-control"] == "no-store"
    assert page.headers["x-robots-tag"] == "noindex"


def test_its_style_is_allowed_by_hash_and_nothing_else(client, admin, floor):
    import base64
    import hashlib
    import re

    page = client.get(_path(_link(client, admin, floor["id"])))
    csp = page.headers["content-security-policy"]
    style = re.search(r"<style>(.*?)</style>", page.text, re.DOTALL).group(1)
    digest = base64.b64encode(hashlib.sha256(style.encode()).digest()).decode()

    assert f"'sha256-{digest}'" in csp
    assert "unsafe-inline" not in csp and "script-src" not in csp
    assert csp.startswith("default-src 'none'")


def test_the_rest_of_the_site_keeps_its_policy(client):
    csp = client.get("/").headers["content-security-policy"]

    assert "sha256-" not in csp and csp.startswith("default-src 'none'")


def test_a_customer_cannot_get_a_link(client, auth, floor):
    r = client.post(f"/api/v1/admin/floors/{floor['id']}/qr-sheet", headers=auth)

    assert r.status_code in (403, 404)


def test_an_unknown_floor_is_404(client, admin):
    assert client.post("/api/v1/admin/floors/999999/qr-sheet", headers=admin).status_code == 404


def test_a_tampered_link_is_404(client, admin, floor):
    path = _path(_link(client, admin, floor["id"]))
    forged = path[:-1] + ("0" if path[-1] != "0" else "1")

    assert client.get(forged).status_code == 404
    assert client.get("/api/v1/qr-sheet/1.2").status_code == 404
    assert client.get("/api/v1/qr-sheet/garbage").status_code == 404


def test_a_link_dies_after_ten_minutes():
    issued = datetime(2026, 10, 2, 12, 0, tzinfo=UTC)
    token = qr_sheet.sign(7, now=issued)

    assert qr_sheet.verify(token, now=issued + timedelta(minutes=9)) == 7
    assert qr_sheet.verify(token, now=issued + timedelta(minutes=11)) is None


def test_the_code_opens_the_app_at_that_table():
    url = qr_sheet.table_url(1, 42)

    assert "/#/t/" in url
    assert parse_table_token(url.split("/#/t/")[1]) == (1, 42)


def test_a_table_name_cannot_inject_markup(client, admin, floor):
    loaded = client.get(f"/api/v1/admin/floors/{floor['id']}", headers=admin).json()
    table = next(o for o in loaded["objects"] if o["kind"].startswith("table"))
    table["name"] = "<script>alert(1)</script>"
    saved = client.put(
        f"/api/v1/admin/floors/{floor['id']}/layout",
        json={"updated_at": loaded["updated_at"], "zones": loaded["zones"], "objects": loaded["objects"]},
        headers=admin,
    )
    assert saved.status_code == 200, saved.text

    page = client.get(_path(_link(client, admin, floor["id"]))).text

    assert "<script>alert(1)</script>" not in page
    assert "&lt;script&gt;" in page


def test_an_empty_floor_still_prints_a_page():
    html = qr_sheet.render("Bao Bar", 1, [])

    assert "No tables on this floor yet." in html and "<svg" not in html


def test_the_single_table_link_carries_the_public_url(client, admin, floor):
    table = _tables(floor)[0]
    r = client.get(f"/api/v1/admin/floors/{floor['id']}/objects/{table['id']}/qr", headers=admin)

    assert r.json()["url"] == qr_sheet.table_url(1, table["id"])
