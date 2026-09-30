"""The privacy policy, the terms, and the consent the forms ask for."""

import secrets

import pytest
from fastapi.testclient import TestClient

from app.core.config import settings
from app.main import app


@pytest.fixture
def web(client):
    # Not a `with` block: that re-runs the lifespan and closes the event hub's
    # loop under every later test (see tests/test_site_ordering.py).
    return TestClient(app)


@pytest.mark.parametrize(
    "path,needle",
    [
        ("/privacy/", "О персональных данных и их защите"),
        ("/terms/", "Продавец блюд — ресторан"),
        ("/kk/privacy/", "Дербес деректер және оларды қорғау туралы"),
        ("/kk/terms/", "Тағамдарды сатушы — мейрамхана"),
    ],
)
def test_both_documents_exist_in_both_languages(web, path, needle):
    r = web.get(path)

    assert r.status_code == 200
    assert needle in r.text


def test_every_page_links_to_them(web):
    html = web.get("/").text

    assert 'href="/privacy/"' in html and 'href="/terms/"' in html
    assert 'href="/kk/privacy/"' in web.get("/kk/").text


def test_they_are_in_the_sitemap(web):
    xml = web.get("/sitemap.xml").text

    for path in ("/privacy/", "/terms/", "/kk/privacy/", "/kk/terms/"):
        assert path in xml


def test_the_operator_and_contacts_come_from_settings(web, monkeypatch):
    monkeypatch.setattr(settings, "legal_entity", "ТОО «Тест», БИН 000000000000")
    monkeypatch.setattr(settings, "support_email", "help@example.kz")
    monkeypatch.setattr(settings, "support_phone", "+7 700 000 00 00")

    html = web.get("/privacy/").text

    assert "ТОО «Тест», БИН 000000000000" in html
    assert "help@example.kz" in html
    assert 'href="mailto:help@example.kz"' in html  # footer
    assert 'href="tel:+77000000000"' in html


def test_without_contacts_the_footer_shows_none(web):
    assert "mailto:" not in web.get("/").text


def test_registration_needs_consent(web):
    r = web.post(
        "/register/",
        data={"name": "No Consent", "email": f"nc.{secrets.token_hex(3)}@food.dev",
              "phone": "", "password": "sitepass123", "next": "/"},
        follow_redirects=False,
    )

    assert r.status_code == 400
    assert "согласие на обработку персональных данных" in r.text


def test_an_application_needs_consent(web):
    r = web.post(
        "/partners/",
        data={"venue_name": "No Consent Cafe", "cuisine": "Pizza", "has_couriers": "yes",
              "contact_name": "Marat", "phone": "+77019998877",
              "email": f"nc.{secrets.token_hex(3)}@cafe.kz", "password": "formpass123"},
        follow_redirects=False,
    )

    assert r.status_code == 400
    assert "согласие на обработку персональных данных" in r.text


def test_the_forms_show_the_checkbox(web):
    for path in ("/register/", "/partners/", "/kk/partners/"):
        html = web.get(path).text
        assert 'name="consent"' in html and "required" in html


def test_a_city_cannot_take_their_address():
    from app.services.cities import RESERVED_SLUGS

    assert {"privacy", "terms"} <= RESERVED_SLUGS
