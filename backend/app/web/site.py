"""The public website: real HTML, rendered on the server.

The Flutter build is a canvas — search engines and link-preview bots see an
empty body. Everything a stranger might arrive on (landing, a restaurant and
its menu, the terms pages) is rendered here instead, from the same database the
app uses, so it can be crawled, shared and read before any JavaScript runs.

Ordering, the courier surface and the admin panel stay in the app.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.responses import HTMLResponse, PlainTextResponse, Response
from fastapi.templating import Jinja2Templates
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_db
from app.core.config import settings
from app.models import MenuItem, Restaurant
from app.models.promo import Promo

HERE = Path(__file__).parent
templates = Jinja2Templates(directory=str(HERE / "templates"))

router = APIRouter(include_in_schema=False)

DB = Depends(get_db)


@dataclass(frozen=True)
class MenuSection:
    name: str
    items: list[MenuItem]


def _base_url() -> str:
    return (settings.public_site_url or "").rstrip("/")


def _render(
    request: Request,
    name: str,
    context: dict,
    *,
    status_code: int = 200,
) -> HTMLResponse:
    context.setdefault("base_url", _base_url())
    context.setdefault("app_url", settings.public_app_url.rstrip("/"))
    return templates.TemplateResponse(request, name, context, status_code=status_code)


def _open_restaurants(db: Session) -> list[Restaurant]:
    return list(
        db.scalars(
            select(Restaurant).order_by(Restaurant.is_open.desc(), Restaurant.rating.desc())
        )
    )


@router.get("/", response_class=HTMLResponse)
def home(request: Request, db: Session = DB) -> HTMLResponse:
    restaurants = _open_restaurants(db)
    # Only codes a visitor could actually use. An exhausted or disabled promo on
    # the landing page is a promise the checkout will refuse to keep.
    promos = list(
        db.scalars(
            select(Promo)
            .where(Promo.is_active.is_(True))
            .order_by(Promo.value.desc())
            .limit(8)
        )
    )
    usable = [
        promo
        for promo in promos
        if promo.max_uses is None or promo.used_count < promo.max_uses
    ]
    return _render(
        request,
        "home.html",
        {
            "title": "Доставка еды в Алматы",
            "description": (
                "Заказывайте доставку из ресторанов Алматы: паназиатская кухня, "
                "пицца, бургеры. Оплата картой или наличными, бронь столика."
            ),
            "restaurants": restaurants,
            "promos": usable,
            "canonical": f"{_base_url()}/",
        },
    )


@router.get("/r/{slug}/", response_class=HTMLResponse)
def restaurant_page(slug: str, request: Request, db: Session = DB) -> HTMLResponse:
    restaurant = db.scalar(select(Restaurant).where(Restaurant.slug == slug))
    if restaurant is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "No such restaurant")
    items = list(
        db.scalars(
            select(MenuItem)
            .where(MenuItem.restaurant_id == restaurant.id, MenuItem.is_available.is_(True))
            .order_by(MenuItem.category, MenuItem.name)
        )
    )
    sections: list[MenuSection] = []
    for item in items:
        if not sections or sections[-1].name != item.category:
            sections.append(MenuSection(name=item.category, items=[]))
        sections[-1].items.append(item)
    cheapest = min((i.price for i in items), default=0)
    return _render(
        request,
        "restaurant.html",
        {
            "title": f"{restaurant.name} — доставка в Алматы",
            "description": (
                restaurant.description
                or f"{restaurant.name}: доставка {restaurant.delivery_time_min} мин."
            )[:300],
            "restaurant": restaurant,
            "sections": sections,
            "item_count": len(items),
            "cheapest": cheapest,
            "canonical": f"{_base_url()}/r/{restaurant.slug}/",
            "og_image": restaurant.image_url,
        },
    )


_PAGES = {
    "delivery": {
        "title": "Доставка и оплата",
        "description": "Условия доставки, зоны, способы оплаты и возврат.",
        "template": "delivery.html",
    },
    "about": {
        "title": "О сервисе",
        "description": "Как устроен сервис доставки еды и что в нём есть.",
        "template": "about.html",
    },
}


@router.get("/delivery/", response_class=HTMLResponse)
def delivery_page(request: Request) -> HTMLResponse:
    page = _PAGES["delivery"]
    return _render(
        request,
        page["template"],
        {
            "title": page["title"],
            "description": page["description"],
            "canonical": f"{_base_url()}/delivery/",
        },
    )


@router.get("/about/", response_class=HTMLResponse)
def about_page(request: Request) -> HTMLResponse:
    page = _PAGES["about"]
    return _render(
        request,
        page["template"],
        {
            "title": page["title"],
            "description": page["description"],
            "canonical": f"{_base_url()}/about/",
        },
    )


@router.get("/robots.txt", response_class=PlainTextResponse)
def robots() -> Response:
    base = _base_url()
    # The app's own surfaces are behind a login and worthless in an index; the
    # API would only burn crawl budget.
    body = "\n".join(
        [
            "User-agent: *",
            "Disallow: /api/",
            "Disallow: /docs",
            "Allow: /",
            f"Sitemap: {base}/sitemap.xml",
            "",
        ]
    )
    return PlainTextResponse(body)


@router.get("/sitemap.xml")
def sitemap(db: Session = DB) -> Response:
    base = _base_url()
    urls = [f"{base}/", f"{base}/delivery/", f"{base}/about/"]
    urls += [
        f"{base}/r/{slug}/"
        for slug in db.scalars(select(Restaurant.slug).where(Restaurant.slug.is_not(None)))
    ]
    body = "".join(f"<url><loc>{url}</loc></url>" for url in urls)
    xml = (
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'
        f"{body}</urlset>"
    )
    return Response(content=xml, media_type="application/xml")
