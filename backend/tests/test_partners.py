"""A restaurant applying to join.

The promise: an applicant gets an account and can start building their menu at
once, but nobody else can see the venue — not in the list, not by id, not on
the site, not in the sitemap, not to order from — until the platform approves
it. And once it does, it behaves like any other venue.
"""

import itertools
import secrets

import pytest

APPLY = "/api/v1/partners/apply"
_n = itertools.count(1)


def _application(**extra) -> dict:
    n = next(_n)
    return {
        "venue_name": f"Applicant Cafe {n}",
        "cuisine": "Kazakh",
        "contact_name": "Aigerim S.",
        "email": f"owner.{secrets.token_hex(3)}@cafe.kz",
        "phone": "+77011234567",
        "password": "ownerpass123",
        "has_couriers": True,
        **extra,
    }


@pytest.fixture
def applied(client) -> dict:
    body = _application()
    r = client.post(APPLY, json=body)
    assert r.status_code == 201, r.text
    data = r.json()
    return {**data, "body": body, "auth": {"Authorization": f"Bearer {data['access_token']}"}}


def _slug(rid: int) -> str:
    from app.db.session import SessionLocal
    from app.models import Restaurant

    with SessionLocal() as db:
        return db.get(Restaurant, rid).slug


class TestApplying:
    def test_it_creates_an_account_and_a_pending_venue(self, applied):
        assert applied["approval"] == "pending"
        assert applied["access_token"] and applied["restaurant_id"]
        assert applied["user"]["email"] == applied["body"]["email"]

    def test_the_applicant_can_sign_in_with_their_password(self, client, applied):
        r = client.post(
            "/api/v1/auth/login/json",
            json={"email": applied["body"]["email"], "password": "ownerpass123"},
        )

        assert r.status_code == 200

    def test_an_email_already_registered_is_refused(self, client, applied):
        r = client.post(APPLY, json=_application(email=applied["body"]["email"]))

        assert r.status_code == 409

    @pytest.mark.parametrize(
        "bad",
        [{"password": "short"}, {"email": "not-an-email"}, {"venue_name": "x"}, {"phone": "1"}],
    )
    def test_incomplete_applications_are_refused(self, client, bad):
        assert client.post(APPLY, json=_application(**bad)).status_code == 422

    def test_the_courier_question_must_be_answered(self, client):
        body = _application()
        del body["has_couriers"]

        assert client.post(APPLY, json=body).status_code == 422

    def test_an_unknown_city_is_refused(self, client):
        assert client.post(APPLY, json=_application(city_slug="atlantis")).status_code == 400

    def test_a_city_can_be_chosen(self, client):
        r = client.post(APPLY, json=_application(city_slug="astana"))

        rid = r.json()["restaurant_id"]
        from app.db.session import SessionLocal
        from app.models import Restaurant

        with SessionLocal() as db:
            assert db.get(Restaurant, rid).city.slug == "astana"


class TestHiddenUntilApproved:
    def test_not_in_the_public_list(self, client, applied):
        ids = [r["id"] for r in client.get("/api/v1/restaurants").json()]

        assert applied["restaurant_id"] not in ids

    def test_not_by_search_or_cuisine(self, client, applied):
        found = client.get("/api/v1/restaurants", params={"q": applied["body"]["venue_name"]}).json()

        assert found == []
        assert "Kazakh" not in client.get("/api/v1/restaurants/cuisines").json() or not [
            r for r in client.get("/api/v1/restaurants", params={"cuisine": "Kazakh"}).json()
            if r["id"] == applied["restaurant_id"]
        ]

    def test_a_stranger_gets_404_by_id_and_for_the_menu(self, client, applied):
        rid = applied["restaurant_id"]

        assert client.get(f"/api/v1/restaurants/{rid}").status_code == 404
        assert client.get(f"/api/v1/restaurants/{rid}/menu").status_code == 404

    def test_the_owner_sees_their_own_venue(self, client, applied):
        rid = applied["restaurant_id"]

        r = client.get(f"/api/v1/restaurants/{rid}", headers=applied["auth"])

        assert r.status_code == 200 and r.json()["approval"] == "pending"

    def test_another_owner_does_not(self, client, applied):
        other = client.post(APPLY, json=_application()).json()

        r = client.get(
            f"/api/v1/restaurants/{applied['restaurant_id']}",
            headers={"Authorization": f"Bearer {other['access_token']}"},
        )

        assert r.status_code == 404

    def test_the_platform_sees_it(self, client, admin, applied):
        assert client.get(f"/api/v1/restaurants/{applied['restaurant_id']}", headers=admin).status_code == 200

    def test_the_owner_can_build_the_menu_while_it_waits(self, client, applied):
        rid = applied["restaurant_id"]

        r = client.post(
            f"/api/v1/admin/restaurants/{rid}/menu",
            json={"name": "Beshbarmak", "price": 4500, "category": "Main"},
            headers=applied["auth"],
        )

        assert r.status_code == 201

    def test_no_order_can_be_placed(self, client, auth, admin, applied):
        rid = applied["restaurant_id"]
        dish = client.post(
            f"/api/v1/admin/restaurants/{rid}/menu",
            json={"name": "Plov", "price": 2000, "category": "Main"},
            headers=applied["auth"],
        ).json()["id"]

        r = client.post(
            "/api/v1/orders",
            json={"restaurant_id": rid, "channel": "pickup", "items": [{"menu_item_id": dish, "quantity": 1}]},
            headers=auth,
        )

        assert r.status_code == 404

    def test_not_on_the_site(self, client, applied):
        slug = _slug(applied["restaurant_id"])

        assert client.get(f"/r/{slug}/").status_code == 404
        assert client.get(f"/kk/r/{slug}/").status_code == 404
        assert slug not in client.get("/").text
        assert slug not in client.get("/sitemap.xml").text


class TestTheDecision:
    def test_only_the_platform_sees_the_queue(self, client, auth, applied):
        assert client.get("/api/v1/admin/applications", headers=auth).status_code == 403
        assert client.get("/api/v1/admin/applications", headers=applied["auth"]).status_code == 403

    def test_the_queue_says_who_to_call_and_whether_they_have_couriers(self, client, admin, applied):
        rows = client.get("/api/v1/admin/applications", headers=admin).json()

        mine = next(r for r in rows if r["restaurant_id"] == applied["restaurant_id"])
        assert mine["owner_phone"] == "+77011234567"
        assert mine["owner_email"] == applied["body"]["email"]
        assert mine["has_couriers"] is True and mine["cuisine"] == "Kazakh"

    def test_approving_makes_it_a_normal_venue(self, client, auth, admin, applied):
        rid = applied["restaurant_id"]
        dish = client.post(
            f"/api/v1/admin/restaurants/{rid}/menu",
            json={"name": "Plov", "price": 2000, "category": "Main"},
            headers=applied["auth"],
        ).json()["id"]

        r = client.post(
            f"/api/v1/admin/restaurants/{rid}/approval", json={"approve": True}, headers=admin
        )

        assert r.status_code == 200 and r.json()["approval"] == "approved"
        assert rid in [x["id"] for x in client.get("/api/v1/restaurants").json()]
        assert client.get(f"/r/{_slug(rid)}/").status_code == 200
        assert _slug(rid) in client.get("/sitemap.xml").text
        order = client.post(
            "/api/v1/orders",
            json={"restaurant_id": rid, "channel": "pickup", "items": [{"menu_item_id": dish, "quantity": 1}]},
            headers=auth,
        )
        assert order.status_code == 201, order.text
        assert rid not in [
            row["restaurant_id"] for row in client.get("/api/v1/admin/applications", headers=admin).json()
        ]

    def test_rejecting_keeps_it_hidden_and_records_why(self, client, admin, applied):
        rid = applied["restaurant_id"]

        client.post(
            f"/api/v1/admin/restaurants/{rid}/approval",
            json={"approve": False, "reason": "Not a restaurant"},
            headers=admin,
        )

        assert client.get(f"/api/v1/restaurants/{rid}").status_code == 404
        seen = client.get(f"/api/v1/restaurants/{rid}", headers=applied["auth"]).json()
        assert seen["approval"] == "rejected"

    def test_a_decision_is_made_once(self, client, admin, applied):
        rid = applied["restaurant_id"]
        client.post(f"/api/v1/admin/restaurants/{rid}/approval", json={"approve": True}, headers=admin)

        r = client.post(f"/api/v1/admin/restaurants/{rid}/approval", json={"approve": False}, headers=admin)

        assert r.status_code == 409

    def test_an_owner_cannot_approve_themselves(self, client, applied):
        r = client.post(
            f"/api/v1/admin/restaurants/{applied['restaurant_id']}/approval",
            json={"approve": True},
            headers=applied["auth"],
        )

        assert r.status_code == 403
        assert client.get(f"/api/v1/restaurants/{applied['restaurant_id']}").status_code == 404


class TestCouriers:
    def _approved(self, client, admin, has_couriers: bool) -> dict:
        data = client.post(APPLY, json=_application(has_couriers=has_couriers)).json()
        auth = {"Authorization": f"Bearer {data['access_token']}"}
        dish = client.post(
            f"/api/v1/admin/restaurants/{data['restaurant_id']}/menu",
            json={"name": "Plov", "price": 2000, "category": "Main"},
            headers=auth,
        ).json()["id"]
        client.post(
            f"/api/v1/admin/restaurants/{data['restaurant_id']}/approval",
            json={"approve": True},
            headers=admin,
        )
        return {"id": data["restaurant_id"], "dish": dish}

    def test_without_couriers_delivery_is_not_offered(self, client, admin):
        v = self._approved(client, admin, has_couriers=False)

        assert "delivery" not in client.get(f"/api/v1/restaurants/{v['id']}").json()["channels"]

    def test_without_couriers_a_delivery_order_is_refused_but_pickup_works(self, client, auth, admin):
        v = self._approved(client, admin, has_couriers=False)
        item = {"menu_item_id": v["dish"], "quantity": 1}

        delivery = client.post(
            "/api/v1/orders",
            json={"restaurant_id": v["id"], "address": "Abay 10", "items": [item]},
            headers=auth,
        )
        pickup = client.post(
            "/api/v1/orders",
            json={"restaurant_id": v["id"], "channel": "pickup", "items": [item]},
            headers=auth,
        )

        assert delivery.status_code == 400 and "pickup and table orders only" in delivery.json()["detail"]
        assert pickup.status_code == 201

    def test_with_couriers_delivery_is_offered(self, client, admin):
        v = self._approved(client, admin, has_couriers=True)

        assert "delivery" in client.get(f"/api/v1/restaurants/{v['id']}").json()["channels"]


def test_the_existing_venues_are_unaffected(client):
    seeded = client.get("/api/v1/restaurants").json()

    assert {"Bao Bar", "Pizza Roma", "Burger Lab"} <= {r["name"] for r in seeded}
    assert all(r["approval"] == "approved" and r["offers_delivery"] for r in seeded[:3])


def test_the_application_endpoint_is_rate_limited(client, monkeypatch):
    from app.core.config import settings
    from app.core.ratelimit import limiter

    limiter.reset()
    monkeypatch.setattr(settings, "login_rate_limit", "2/minute")
    codes = [client.post(APPLY, json=_application()).status_code for _ in range(3)]
    limiter.reset()

    assert codes == [201, 201, 429]


class TestTheSiteForm:
    """The same application from the website: plain form fields, no scripts."""

    @pytest.fixture
    def web(self, client):
        from fastapi.testclient import TestClient

        from app.main import app

        return TestClient(app)

    def _form(self, **extra) -> dict:
        return {
            "venue_name": f"Site Applicant {next(_n)}",
            "cuisine": "Pizza",
            "city_slug": "almaty",
            "has_couriers": "no",
            "description": "Wood-fired",
            "contact_name": "Marat",
            "phone": "+77019998877",
            "email": f"form.{secrets.token_hex(3)}@cafe.kz",
            "password": "formpass123",
            "consent": "yes",
            **extra,
        }

    def test_the_form_asks_the_courier_question(self, web):
        html = web.get("/partners/").text

        assert "Есть ли у вас свои курьеры?" in html and 'name="has_couriers"' in html

    def test_it_exists_in_kazakh_and_says_so_to_search_engines(self, web):
        html = web.get("/kk/partners/").text

        assert "Өз курьерлеріңіз бар ма?" in html and 'hreflang="ru"' in html

    def test_a_good_application_lands_on_the_thanks_page_and_creates_a_pending_venue(self, client, admin, web):
        form = self._form()

        r = web.post("/partners/", data=form, follow_redirects=False)

        assert r.status_code == 303 and r.headers["location"] == "/partners/thanks/"
        assert "Заявка принята" in web.get("/partners/thanks/").text
        queue = client.get("/api/v1/admin/applications", headers=admin).json()
        mine = next(row for row in queue if row["name"] == form["venue_name"])
        assert mine["has_couriers"] is False and mine["owner_email"] == form["email"]

    def test_the_kazakh_form_thanks_in_kazakh(self, web):
        r = web.post("/kk/partners/", data=self._form(), follow_redirects=False)

        assert r.headers["location"] == "/kk/partners/thanks/"
        assert "Өтінім қабылданды" in web.get("/kk/partners/thanks/").text

    def test_a_bad_form_explains_and_keeps_what_was_typed(self, web):
        form = self._form(password="short")

        r = web.post("/partners/", data=form)

        assert r.status_code == 400 and "Проверьте поля" in r.text
        assert form["venue_name"] in r.text and "short" not in r.text

    def test_an_email_already_used_is_said_plainly(self, web):
        form = self._form()
        web.post("/partners/", data=form)

        assert "Эта почта уже зарегистрирована" in web.post("/partners/", data=form).text

    def test_the_thanks_page_is_not_indexed(self, web):
        assert 'name="robots" content="noindex"' in web.get("/partners/thanks/").text

    def test_the_link_is_in_the_footer(self, web):
        assert 'href="/partners/"' in web.get("/").text
        assert 'href="/kk/partners/"' in web.get("/kk/").text


class TestThePricesOnTheSite:
    """The page that sells the service must show what it costs, from the same
    numbers the billing uses — not a copy that drifts."""

    def test_every_plan_and_its_price_is_shown(self, client):
        from app.core.features import PLANS

        html = client.get("/partners/").text

        for spec in PLANS.values():
            assert spec["name"] in html
            assert f"{spec['monthly_price']:,}".replace(",", " ") in html
        assert "30 дней" in html

    def test_a_failed_form_still_shows_them(self, client):
        html = client.post("/partners/", data={"venue_name": ""}).text

        assert "49 990" in html

    def test_they_are_in_kazakh_too(self, client):
        html = client.get("/kk/partners/").text

        assert "Тарифтер" in html and "айына" in html


class TestWhoHearsAboutIt:
    @pytest.fixture
    def pushed(self, monkeypatch):
        from app.services import partners as svc

        calls = []
        monkeypatch.setattr(svc, "push_fanout", lambda db, ids, **kw: calls.append((set(ids), kw)))
        return calls

    def test_the_platform_is_told_about_a_new_application(self, client, admin, pushed):
        body = _application()
        client.post(APPLY, json=body)

        admin_id = client.get("/api/v1/auth/me", headers=admin).json()["id"]
        ids, kw = pushed[-1]
        assert admin_id in ids
        assert body["venue_name"] in kw["body"] and kw["data"]["cause"] == "application"

    def test_the_owner_is_told_the_decision(self, client, admin, applied, pushed):
        rid = applied["restaurant_id"]
        client.post(f"/api/v1/admin/restaurants/{rid}/approval", json={"approve": True}, headers=admin)

        ids, kw = pushed[-1]
        assert ids == {applied["user"]["id"]}
        assert "approved" in kw["title"] and kw["data"]["cause"] == "approval"

    def test_a_rejection_carries_the_reason(self, client, admin, applied, pushed):
        rid = applied["restaurant_id"]
        client.post(
            f"/api/v1/admin/restaurants/{rid}/approval",
            json={"approve": False, "reason": "Нет санитарной книжки"},
            headers=admin,
        )

        assert pushed[-1][1]["body"] == "Нет санитарной книжки"
