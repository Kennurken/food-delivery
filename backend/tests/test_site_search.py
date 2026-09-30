"""Finding a restaurant on the landing page without scripts: a search box and
cuisine chips, both plain GET parameters."""

import re

import pytest


def _names(html: str) -> list[str]:
    """Restaurant cards only — campaign cards share the class."""
    return re.findall(r'href="[^"]*/r/[^"]*">.*?class="card-title">([^<]+)<', html, re.DOTALL)


def test_the_landing_lists_everything_by_default(client):
    assert {"Bao Bar", "Pizza Roma", "Burger Lab"} <= set(_names(client.get("/").text))


def test_search_by_name(client):
    names = _names(client.get("/", params={"q": "pizza"}).text)

    assert "Pizza Roma" in names and "Bao Bar" not in names


def test_search_finds_a_venue_by_a_dish(client):
    dish = client.get("/api/v1/restaurants/1/menu").json()[0]["name"]

    names = _names(client.get("/", params={"q": dish}).text)

    assert "Bao Bar" in names


def test_search_by_cuisine_word(client):
    assert "Burger Lab" in _names(client.get("/", params={"q": "american"}).text)


def test_a_cuisine_chip_filters(client):
    names = _names(client.get("/", params={"cuisine": "Italian"}).text)

    assert names[:1] == ["Pizza Roma"] and "Bao Bar" not in names


def test_chips_and_search_combine(client):
    html = client.get("/", params={"cuisine": "Asian", "q": "zzz-nothing"}).text

    assert "Ничего не найдено" in html and "Bao Bar" not in _names(html)


def test_the_chips_come_from_the_whole_list(client):
    html = client.get("/", params={"cuisine": "Italian"}).text

    assert "cuisine=Asian" in html and "cuisine=American" in html


def test_a_search_page_is_kept_out_of_the_index_and_has_no_twin(client):
    html = client.get("/", params={"q": "bao"}).text

    assert '<meta name="robots" content="noindex">' in html
    assert "hreflang" not in html
    assert re.search(r'rel="canonical" href="[^"]*/"', html) and "?q=" not in html.split("canonical")[1][:80]


def test_the_plain_landing_is_still_indexable_with_twins(client):
    html = client.get("/").text

    assert 'name="robots"' not in html
    assert 'hreflang="kk"' in html


@pytest.mark.parametrize("q", ["%", "_", "\\", "'; drop table restaurants; --", "<script>alert(1)</script>"])
def test_odd_queries_are_just_text(client, q):
    r = client.get("/", params={"q": q})

    assert r.status_code == 200
    assert "<script>alert(1)</script>" not in r.text


def test_percent_is_not_a_wildcard(client):
    assert _names(client.get("/", params={"q": "%"}).text) == []


def test_it_works_in_kazakh_too(client):
    html = client.get("/kk/", params={"q": "zzz-nothing"}).text

    assert "Ештеңе табылмады" in html
    assert 'placeholder="Мейрамхана немесе тағам"' in html
