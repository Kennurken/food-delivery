"""A menu pasted from a spreadsheet: preview first, then the write."""

import secrets

import pytest

from app.services import menu_import


@pytest.fixture
def venue(client, admin) -> int:
    return client.post(
        "/api/v1/admin/restaurants",
        json={"name": f"Import Cafe {secrets.token_hex(2)}", "cuisine": "Test"},
        headers=admin,
    ).json()["id"]


def _import(client, admin, rid, text, *, dry_run=True):
    r = client.post(
        f"/api/v1/admin/restaurants/{rid}/menu/import",
        json={"text": text, "dry_run": dry_run},
        headers=admin,
    )
    assert r.status_code == 200, r.text
    return r.json()


def _menu(client, rid) -> dict:
    return {i["name"]: i for i in client.get(f"/api/v1/restaurants/{rid}/menu").json()}


class TestParsing:
    def test_rows_copied_from_a_spreadsheet_are_tab_separated(self):
        rows = menu_import.parse("Плов\t2 500\tГорячее\tС бараниной\nСамса\t800 ₸\tВыпечка")

        assert [(r.name, r.price, r.category) for r in rows] == [
            ("Плов", 2500, "Горячее"),
            ("Самса", 800, "Выпечка"),
        ]
        assert rows[0].description == "С бараниной"

    def test_a_header_row_says_which_column_is_which(self):
        rows = menu_import.parse("Категория;Цена;Название\nСалаты;1990,50;Цезарь")

        assert (rows[0].name, rows[0].price, rows[0].category, rows[0].line) == (
            "Цезарь", 1990.5, "Салаты", 2,
        )

    def test_kazakh_and_english_headers_work(self):
        assert menu_import.parse("Атауы,Баға\nБешбармақ,3500")[0].name == "Бешбармақ"
        assert menu_import.parse("name,price\nBurger,2900")[0].price == 2900

    def test_quoted_cells_can_hold_the_delimiter(self):
        rows = menu_import.parse('Лагман,1800,Супы,"Лапша, мясо, овощи"')

        assert rows[0].description == "Лапша, мясо, овощи"

    def test_bad_rows_say_why(self):
        rows = menu_import.parse("\t1000\nСуп\tбесплатно\nЧай\t-5")

        assert [r.error for r in rows] == ["no_name", "bad_price", "bad_price"]

    def test_only_web_links_are_taken_as_photos(self):
        rows = menu_import.parse("Чай\t300\tНапитки\t\tjavascript:alert(1)\nКофе\t900\tНапитки\t\thttps://x.kz/c.jpg")

        assert [r.image_url for r in rows] == [None, "https://x.kz/c.jpg"]

    def test_a_blank_category_lands_in_a_default_one(self):
        assert menu_import.parse("Хлеб\t200")[0].category == menu_import.DEFAULT_CATEGORY


class TestApplying:
    def test_the_preview_writes_nothing(self, client, admin, venue):
        body = _import(client, admin, venue, "Плов\t2500\tГорячее")

        assert (body["applied"], body["created"]) == (False, 1)
        assert _menu(client, venue) == {}

    def test_applying_creates_the_dishes(self, client, admin, venue):
        body = _import(client, admin, venue, "Плов\t2500\tГорячее\nСамса\t800\tВыпечка", dry_run=False)

        assert (body["applied"], body["created"], body["updated"]) == (True, 2, 0)
        menu = _menu(client, venue)
        assert menu["Плов"]["price"] == 2500 and menu["Самса"]["category"] == "Выпечка"

    def test_pasting_again_updates_instead_of_duplicating(self, client, admin, venue):
        _import(client, admin, venue, "Плов\t2500\tГорячее", dry_run=False)

        preview = _import(client, admin, venue, "плов \t2700\tГорячее")
        body = _import(client, admin, venue, "плов \t2700\tГорячее", dry_run=False)

        assert preview["rows"][0]["action"] == "update"
        assert (body["created"], body["updated"]) == (0, 1)
        assert list(_menu(client, venue)) == ["Плов"]
        assert _menu(client, venue)["Плов"]["price"] == 2700

    def test_bad_rows_are_skipped_and_good_ones_still_land(self, client, admin, venue):
        body = _import(client, admin, venue, "Суп\tбесплатно\nЧай\t300", dry_run=False)

        assert (body["created"], body["errors"]) == (1, 1)
        assert list(_menu(client, venue)) == ["Чай"]

    def test_a_guest_cannot(self, client, auth, venue):
        r = client.post(
            f"/api/v1/admin/restaurants/{venue}/menu/import",
            json={"text": "Чай\t300", "dry_run": False},
            headers=auth,
        )

        assert r.status_code == 403

    def test_the_row_limit_holds(self, client, admin, venue):
        text = "\n".join(f"Блюдо {i}\t100" for i in range(menu_import.MAX_ROWS + 5))

        body = _import(client, admin, venue, text)

        assert body["created"] == menu_import.MAX_ROWS
        assert body["rows"][-1]["error"] == "too_many_rows"
