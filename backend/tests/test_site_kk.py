"""The Kazakh site.

One URL per language for the public pages, so a search engine indexes each on
its own; the personal pages follow a cookie. What must never happen: a page
that links a Kazakh reader back into Russian, a string that has no translation
and nobody notices, or a Kazakh page that claims the Russian URL as its own.
"""

import glob
import re
from pathlib import Path

import pytest

from app.web import site
from app.web.kk import KK

TEMPLATES = Path(site.HERE / "templates")


def _visible(html: str) -> str:
    body = re.sub(r"<script.*?</script>", "", html, flags=re.DOTALL | re.IGNORECASE)
    body = re.sub(r"<style.*?</style>", "", body, flags=re.DOTALL | re.IGNORECASE)
    return re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", body)).strip()


class TestNothingIsLeftUntranslated:
    def test_every_template_string_has_a_kazakh_entry(self):
        missing = []
        for path in sorted(glob.glob(str(TEMPLATES / "*.html"))):
            text = Path(path).read_text()
            for m in re.finditer(r"""_\(\s*(?:"((?:[^"\\]|\\.)*)"|'((?:[^'\\]|\\.)*)')""", text):
                key = (m.group(1) if m.group(1) is not None else m.group(2)).replace('\\"', '"')
                if key not in KK:
                    missing.append((Path(path).name, key[:60]))
        assert not missing, f"add to app/web/kk.py: {missing}"

    def test_no_template_has_russian_left_outside_the_translator(self):
        """A string added to a template without _() would show Russian to a
        Kazakh reader forever. Jinja comments and the translator's own
        arguments are the only places Cyrillic may sit."""
        offenders = []
        for path in sorted(glob.glob(str(TEMPLATES / "*.html"))):
            text = Path(path).read_text()
            text = re.sub(r"{#.*?#}", "", text, flags=re.DOTALL)
            text = re.sub(r"""_\(\s*(?:"(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*')""", "_()", text)
            for line in text.splitlines():
                # The language switch names each language in its own language.
                if "ҚАЗ" in line or "Тіл / Язык" in line:
                    continue
                if re.search(r"[А-Яа-яЁё]", line):
                    offenders.append((Path(path).name, line.strip()[:70]))
        assert not offenders, offenders

    def test_a_translation_keeps_the_placeholders_of_its_source(self):
        broken = [
            ru
            for ru, kk in KK.items()
            if sorted(re.findall(r"%\((\w+)\)s", ru)) != sorted(re.findall(r"%\((\w+)\)s", kk))
        ]
        assert not broken, broken


class TestPublicPages:
    @pytest.mark.parametrize("path", ["/kk/", "/kk/about/", "/kk/delivery/", "/kk/actions/", "/kk/r/bao-bar/"])
    def test_each_public_page_exists_in_kazakh(self, client, path):
        r = client.get(path)

        assert r.status_code == 200, path
        assert '<html lang="kk">' in r.text

    def test_the_russian_page_is_unchanged(self, client):
        r = client.get("/about/")

        assert '<html lang="ru">' in r.text
        assert "Сервис доставки еды в Алматы и Астане" in _visible(r.text)

    def test_the_kazakh_about_page_is_kazakh(self, client):
        text = _visible(client.get("/kk/about/").text)

        assert "Сервис туралы" in text
        assert "Қонақтар үшін" in text
        assert "Алматыда және Астанада тамақ жеткізу сервисі" in text
        # None of the Russian sentences it was translated from remain.
        assert "Для гостей" not in text and "Контакты" not in text

    def test_the_landing_says_the_city_the_kazakh_way(self, client):
        text = _visible(client.get("/kk/").text)

        assert "Алматыда тамақ жеткізу" in text

    def test_links_stay_in_kazakh(self, client):
        html = client.get("/kk/").text

        assert 'href="/kk/about/"' in html
        assert 'href="/kk/delivery/"' in html
        assert 'href="/kk/r/bao-bar/"' in html
        # ...except the personal pages, which have no Kazakh URL of their own.
        assert 'href="/cart/"' in html

    def test_the_city_switcher_stays_in_kazakh(self, client):
        html = client.get("/kk/").text

        assert 'href="/kk/astana/"' in html
        assert ">Астана<" in html

    def test_a_kazakh_city_page(self, client, admin):
        client.post(
            "/api/v1/admin/restaurants",
            json={"name": "Kk Astana Cafe", "cuisine": "Test", "city_slug": "astana"},
            headers=admin,
        )

        r = client.get("/kk/astana/")

        assert r.status_code == 200
        assert "Астанада тамақ жеткізу" in _visible(r.text)

    def test_the_default_city_in_kazakh_redirects_to_the_kazakh_root(self, client):
        r = client.get("/kk/almaty/", follow_redirects=False)

        assert r.status_code == 301 and r.headers["location"] == "/kk/"

    def test_an_unknown_kazakh_page_is_still_a_404(self, client):
        assert client.get("/kk/atlantis/").status_code == 404
        assert client.get("/kk/r/no-such-place/").status_code == 404


class TestSearchEngines:
    def test_each_language_declares_its_twin(self, client):
        for path, ru, kk in (("/about/", "/about/", "/kk/about/"), ("/kk/about/", "/about/", "/kk/about/")):
            html = client.get(path).text

            assert 'hreflang="ru" href="' in html and html.count('rel="alternate"') == 3
            assert re.search(rf'hreflang="ru" href="[^"]*{re.escape(ru)}"', html)
            assert re.search(rf'hreflang="kk" href="[^"]*{re.escape(kk)}"', html)

    def test_the_kazakh_page_is_its_own_canonical(self, client):
        html = client.get("/kk/about/").text

        assert re.search(r'rel="canonical" href="[^"]*/kk/about/"', html)

    def test_the_russian_canonical_did_not_move(self, client):
        assert re.search(r'rel="canonical" href="[^"]*/about/"', client.get("/about/").text)
        assert not re.search(r'rel="canonical" href="[^"]*/kk/', client.get("/about/").text)

    def test_the_sitemap_lists_both_languages(self, client):
        body = client.get("/sitemap.xml").text

        assert "/kk/</loc>" in body and "/kk/about/</loc>" in body
        assert "/kk/r/bao-bar/</loc>" in body

    def test_personal_pages_are_not_given_twins(self, client):
        html = client.get("/cart/").text

        assert "hreflang" not in html


class TestVenuePage:
    def test_the_venue_page_speaks_kazakh_and_keeps_its_data(self, client):
        html = client.get("/kk/r/bao-bar/").text
        text = _visible(html)

        assert "Мәзір" in text and "Себетке" in text
        assert "Bao Bar" in text and "Pork Bao" in text  # names are the venue's own
        assert "доставка" not in text.lower().replace("жеткізу", "")  # no Russian heading left

    def test_the_title_reads_kazakh(self, client):
        title = re.search(r"<title>(.*?)</title>", client.get("/kk/r/bao-bar/").text).group(1)

        assert "Алматыда жеткізу" in title


class TestChoosingALanguage:
    def test_the_switch_sets_a_cookie_and_goes_back(self, client):
        r = client.get("/lang/kk?next=/cart/", follow_redirects=False)

        assert r.status_code == 303 and r.headers["location"] == "/cart/"
        assert "fd_lang=kk" in r.headers["set-cookie"]

    def test_the_personal_pages_follow_the_cookie(self, client):
        from fastapi.testclient import TestClient

        from app.main import app

        web = TestClient(app)
        web.get("/lang/kk?next=/cart/")

        page = web.get("/cart/").text

        assert '<html lang="kk">' in page
        assert "Себет" in _visible(page)

    def test_the_cookie_does_not_change_a_public_url(self, client):
        from fastapi.testclient import TestClient

        from app.main import app

        web = TestClient(app)
        web.get("/lang/kk?next=/")

        assert '<html lang="ru">' in web.get("/about/").text

    def test_it_will_not_redirect_off_site(self, client):
        r = client.get("/lang/kk?next=//evil.example", follow_redirects=False)

        assert r.headers["location"] == "/"

    def test_an_unknown_language_is_404(self, client):
        assert client.get("/lang/xx").status_code == 404
