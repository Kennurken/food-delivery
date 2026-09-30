"""Which language a page is in, and how a string becomes that language.

The public pages have one URL per language — /r/bao-bar/ is Russian and
/kk/r/bao-bar/ is Kazakh — so a search engine indexes each on its own and the
page a link points at is the page you get. The pages that are only for the
person using them (cart, checkout, orders, sign-in) have no second URL; they
follow the language cookie the switcher sets.

Strings are looked up by their Russian source text (see kk.py). A string with
no entry stays Russian rather than breaking the page.
"""

from __future__ import annotations

from fastapi import Request
from jinja2 import pass_context
from markupsafe import Markup

from app.web.kk import KK

COOKIE = "fd_lang"
LANGS = ("ru", "kk")
PREFIX = {"ru": "", "kk": "/kk"}

# Pages that follow the visitor's cookie because they have no URL of their own
# in the other language.
_PERSONAL = ("/cart", "/checkout", "/orders", "/login", "/register", "/logout", "/lang")


def lang_of(request: Request) -> str:
    path = request.url.path
    if path == "/kk" or path.startswith("/kk/"):
        return "kk"
    if path.startswith(_PERSONAL):
        chosen = request.cookies.get(COOKIE)
        return chosen if chosen in LANGS else "ru"
    return "ru"


def translate(text: str, lang: str, **params: object) -> str:
    out = KK.get(text, text) if lang == "kk" else text
    return out % params if params else out


def tidy(text: str) -> str:
    """Collapse the doubled space an empty parameter leaves behind."""
    return " ".join(text.split()).replace(" :", ":")


@pass_context
def gettext(ctx, text: str, **params: object) -> Markup:
    """`_()` in templates. Returns markup so a translation may carry a tag of
    its own (<em>, <code>); the parameters are escaped, the sentence is ours."""
    out = KK.get(text, text) if ctx.get("lang") == "kk" else text
    return Markup(out) % params if params else Markup(out)


@pass_context
def city_name(ctx, city) -> str:
    """A city's display name in the page's language."""
    if ctx.get("lang") == "kk" and getattr(city, "name_kk", None):
        return city.name_kk
    return city.name
