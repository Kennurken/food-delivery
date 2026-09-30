"""The public website: real HTML, rendered on the server.

The Flutter build is a canvas — search engines and link-preview bots see an
empty body. Everything a stranger might arrive on (landing, a restaurant and
its menu, the terms pages) is rendered here instead, from the same database the
app uses, so it can be crawled, shared and read before any JavaScript runs.

Ordering lives here too, and it also works with scripts switched off: the cart
is a signed cookie and every change is a form POST. The courier surface and the
admin panel stay in the app.
"""

from __future__ import annotations

import hashlib
from dataclasses import dataclass
from datetime import timedelta
from pathlib import Path

from fastapi import APIRouter, Depends, Form, HTTPException, Request, status
from fastapi.responses import HTMLResponse, PlainTextResponse, RedirectResponse, Response
from fastapi.templating import Jinja2Templates
from pydantic import ValidationError
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_db
from app.core.config import settings
from app.core.security import create_access_token, hash_password, verify_password
from app.models import City, MenuItem, Order, Restaurant, User, UserRole
from app.schemas.order import OrderCreate
from app.services import cities, hours, offers, order_service
from app.web import cart as cart_store
from app.web import session as web_session

HERE = Path(__file__).parent
templates = Jinja2Templates(directory=str(HERE / "templates"))


def _asset_version() -> str:
    """A stamp that changes when the stylesheet does, and only then.

    Static files go out with an ETag and no max-age, so browsers fall back to
    heuristic caching: a deployed CSS change can sit unseen behind a stale copy
    for a returning visitor. A changed file has to be a different URL.

    The stamp is a hash of the contents, not the mtime. Vercel stamps every
    built file with the same fixed date (1540000000), so an mtime-based version
    is frozen across deploys — which is the one thing it must not be.
    """
    try:
        data = (HERE / "static" / "site.css").read_bytes()
    except OSError:
        return "0"
    return hashlib.sha256(data).hexdigest()[:12]


ASSET_VERSION = _asset_version()

router = APIRouter(include_in_schema=False)

DB = Depends(get_db)


@dataclass(frozen=True)
class MenuSection:
    name: str
    items: list[MenuItem]


def _base_url() -> str:
    return (settings.public_site_url or "").rstrip("/")


def _viewer(request: Request, db: Session) -> User | None:
    return web_session.current_user(db, request.cookies.get(web_session.COOKIE))


def _cart(request: Request) -> cart_store.Cart:
    return cart_store.read(request.cookies.get(cart_store.COOKIE))


def _render(
    request: Request,
    name: str,
    context: dict,
    *,
    db: Session | None = None,
    status_code: int = 200,
) -> HTMLResponse:
    context.setdefault("base_url", _base_url())
    context.setdefault("app_url", settings.public_app_url.rstrip("/"))
    context.setdefault("cart_count", _cart(request).count)
    context.setdefault("asset_version", ASSET_VERSION)
    if db is not None:
        context.setdefault("viewer", _viewer(request, db))
        live = cities.active(db)
        default = cities.default(db)
        context.setdefault("city", default)
        context.setdefault("city_in", _in_city(context["city"]))
        context.setdefault("cities_in", _in_cities(live))
        context.setdefault(
            "city_links",
            [(c, "/" if default and c.id == default.id else f"/{c.slug}/") for c in live],
        )
    return templates.TemplateResponse(request, name, context, status_code=status_code)


def _back(request: Request, fallback: str = "/") -> str:
    """Return the visitor to the page they acted from, but only within this
    site: an open redirect is a phishing gadget, not a convenience."""
    target = request.headers.get("referer") or ""
    if target.startswith(_base_url()) and _base_url():
        return target
    if target.startswith("/"):
        return target
    return fallback


def _safe_next(value: str | None, fallback: str = "/") -> str:
    if value and value.startswith("/") and not value.startswith("//"):
        return value
    return fallback


def _locative(city: City) -> str:
    """The city as it reads after "в" — stored, since Russian declines it and
    the name alone can't say how ("Алматы" stays, "Астана" becomes "Астане")."""
    return city.name_in or city.name


def _in_city(city: City | None) -> str:
    """"в Астане" — or "" when there is no city to name."""
    return "" if city is None else "в " + _locative(city)


def _in_cities(items: list[City]) -> str:
    """"в Алматы и Астане" — every live city, for pages about the whole service."""
    names = [_locative(c) for c in items]
    if not names:
        return ""
    if len(names) == 1:
        return "в " + names[0]
    return "в " + ", ".join(names[:-1]) + " и " + names[-1]


def _hours_note(restaurant: Restaurant) -> str | None:
    """Human-readable note about when the venue opens next.

    Returns None when the venue is open now (or has no schedule). When closed
    by schedule: "Откроется в 10:00" (today), "Откроется завтра в 10:00"
    (tomorrow), or "Откроется в пн, 10:00" (later in the week).
    """
    state = hours.status_of(restaurant)
    if not state.has_schedule or state.open_now or state.opens_at is None:
        return None

    # Dates are compared on the venue's own wall clock, not the server's.
    today = hours.local_time(restaurant).date()
    opens = state.opens_at
    at = _clock(opens)
    if opens.date() == today:
        return f"Откроется в {at}"
    if opens.date() == today + timedelta(days=1):
        return f"Откроется завтра в {at}"
    return f"Откроется в {['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'][opens.weekday()]}, {at}"


_DAYS_RU = ["Понедельник", "Вторник", "Среда", "Четверг", "Пятница", "Суббота", "Воскресенье"]
_DAYS_SCHEMA = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]


def _clock(value) -> str:
    return value.strftime("%H:%M")


def _week(schedule: list[hours.Stretch]) -> list[tuple[str, str]]:
    """The seven days as (name, "10:00–22:00, 17:00–23:00"), for the page.

    Built here rather than in the template: a template that has to group
    stretches by weekday ends up writing the same filter seven times.
    """
    rows = []
    for day, name in enumerate(_DAYS_RU):
        today = [s for s in schedule if s.weekday == day]
        if not today:
            rows.append((name, "Выходной"))
            continue
        parts = ["Круглосуточно" if s.opens == s.closes else f"{_clock(s.opens)}–{_clock(s.closes)}" for s in today]
        rows.append((name, ", ".join(parts)))
    return rows


def _opening_spec(schedule: list[hours.Stretch]) -> list[dict]:
    """schema.org OpeningHoursSpecification, one entry per stretch."""
    return [
        {
            "@type": "OpeningHoursSpecification",
            "dayOfWeek": f"https://schema.org/{_DAYS_SCHEMA[s.weekday]}",
            "opens": _clock(s.opens),
            "closes": _clock(s.closes),
        }
        for s in schedule
    ]


# ---------------------------------------------------------------- public pages


def _landing(request: Request, db: Session, city: City | None) -> HTMLResponse:
    """The landing page for one city — or for every venue when there is no city
    at all (a database the city seed hasn't reached yet)."""
    query = select(Restaurant).order_by(Restaurant.is_open.desc(), Restaurant.rating.desc())
    if city is not None:
        query = query.where(Restaurant.city_id == city.id)
    restaurants = list(db.scalars(query))
    # Campaigns that are actually running. A finished offer on the landing page
    # is a promise the checkout will refuse to keep.
    promos = offers.live(db, limit=6)
    default = cities.default(db)
    on_root = city is None or (default is not None and city.id == default.id)
    where = f" {_in_city(city)}" if city else ""
    # Hours notes for cards — schedule-closed venues show when they open
    notes = {r.id: _hours_note(r) for r in restaurants}
    return _render(
        request,
        "home.html",
        {
            "title": f"Доставка еды{where}",
            "description": (
                f"Доставка еды{where}: паназиатская кухня, пицца, бургеры. "
                "Оплата картой или наличными, бронь столика."
            ),
            "restaurants": restaurants,
            "promos": promos,
            "canonical": f"{_base_url()}/" if on_root else f"{_base_url()}/{city.slug}/",
            "city": city,
            "notes": notes,
            # A city with no venues yet is a thin page; keep it out of the index
            # until it has something to show.
            "noindex": not restaurants,
        },
        db=db,
    )


@router.get("/", response_class=HTMLResponse)
def home(request: Request, db: Session = DB) -> HTMLResponse:
    return _landing(request, db, cities.default(db))


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
    city = restaurant.city or cities.default(db)
    where = f" {_in_city(city)}" if city else ""
    # Hours note for the restaurant page
    note = _hours_note(restaurant)
    schedule = hours.stretches(restaurant.hours)
    return _render(
        request,
        "restaurant.html",
        {
            "title": f"{restaurant.name} — доставка{where}",
            "description": (
                restaurant.description
                or f"{restaurant.name}: доставка {restaurant.delivery_time_min} мин."
            )[:300],
            "restaurant": restaurant,
            "sections": sections,
            "item_count": len(items),
            "canonical": f"{_base_url()}/r/{restaurant.slug}/",
            "og_image": restaurant.image_url,
            "city": city,
            "hours_note": note,
            "hours_week": _week(schedule) if schedule else [],
            "hours_spec": _opening_spec(schedule),
        },
        db=db,
    )


@router.get("/actions/", response_class=HTMLResponse)
def offers_page(request: Request, db: Session = DB) -> HTMLResponse:
    running = offers.live(db)
    return _render(
        request,
        "offers.html",
        {
            "title": "Акции и предложения",
            "description": "Действующие акции ресторанов: скидки, промокоды, комбо.",
            "offers": running,
            "canonical": f"{_base_url()}/actions/",
        },
        db=db,
    )


@router.get("/actions/{slug}", response_class=HTMLResponse)
def offer_page(slug: str, request: Request, db: Session = DB) -> HTMLResponse:
    offer = offers.by_slug(db, slug)
    if offer is None:
        # A campaign that has ended is gone, not merely stale: leaving its URL
        # answering 200 keeps advertising something nobody will honour.
        raise HTTPException(status.HTTP_404_NOT_FOUND, "No such offer")
    return _render(
        request,
        "offer.html",
        {
            "title": offer.title,
            "description": (offer.subtitle or offer.body or offer.title)[:300],
            "offer": offer,
            "code": offers.usable_code(db, offer),
            "canonical": f"{_base_url()}/actions/{offer.slug}",
            "og_image": offer.image_url,
        },
        db=db,
    )


@router.get("/delivery/", response_class=HTMLResponse)
def delivery_page(request: Request, db: Session = DB) -> HTMLResponse:
    return _render(
        request,
        "delivery.html",
        {
            "title": "Доставка и оплата",
            "description": "Условия доставки, зоны, способы оплаты и возврат.",
            "canonical": f"{_base_url()}/delivery/",
        },
        db=db,
    )


@router.get("/about/", response_class=HTMLResponse)
def about_page(request: Request, db: Session = DB) -> HTMLResponse:
    return _render(
        request,
        "about.html",
        {
            "title": "О сервисе",
            "description": "Как устроен сервис доставки еды и что в нём есть.",
            "canonical": f"{_base_url()}/about/",
        },
        db=db,
    )


# ---------------------------------------------------------------------- cart


@router.post("/cart/add")
def cart_add(
    request: Request,
    restaurant_id: int = Form(...),
    item_id: int = Form(...),
    db: Session = DB,
) -> Response:
    item = db.get(MenuItem, item_id)
    if item is None or item.restaurant_id != restaurant_id or not item.is_available:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "No such dish")
    cart = cart_store.add(_cart(request), restaurant_id=restaurant_id, item_id=item_id)
    response = RedirectResponse(_back(request), status_code=status.HTTP_303_SEE_OTHER)
    cart_store.save(response, cart)
    return response


@router.post("/cart/update")
def cart_update(
    request: Request,
    item_id: int = Form(...),
    quantity: int = Form(...),
) -> Response:
    cart = cart_store.set_quantity(_cart(request), item_id=item_id, quantity=quantity)
    response = RedirectResponse("/cart/", status_code=status.HTTP_303_SEE_OTHER)
    cart_store.save(response, cart)
    return response


@router.post("/cart/clear")
def cart_clear() -> Response:
    response = RedirectResponse("/cart/", status_code=status.HTTP_303_SEE_OTHER)
    cart_store.save(response, cart_store.Cart())
    return response


@router.get("/cart/", response_class=HTMLResponse)
def cart_page(request: Request, db: Session = DB) -> HTMLResponse:
    cart = _cart(request)
    restaurant, lines, subtotal = cart_store.hydrate(db, cart)
    return _render(
        request,
        "cart.html",
        {
            "title": "Корзина",
            "description": "Ваш заказ.",
            "restaurant": restaurant,
            "lines": lines,
            "subtotal": subtotal,
        },
        db=db,
    )


# ---------------------------------------------------------------------- auth


@router.get("/login/", response_class=HTMLResponse)
def login_form(request: Request, next: str | None = None, db: Session = DB) -> HTMLResponse:
    return _render(
        request,
        "login.html",
        {
            "title": "Вход",
            "description": "Вход в личный кабинет.",
            "next": _safe_next(next),
        },
        db=db,
    )


@router.post("/login/")
def login(
    request: Request,
    email: str = Form(...),
    password: str = Form(...),
    next: str = Form("/"),
    db: Session = DB,
) -> Response:
    user = db.scalar(select(User).where(User.email == email.strip().lower()))
    if user is None or not verify_password(password, user.hashed_password):
        # One message for both cases: saying "no such email" tells a stranger
        # which addresses are registered here.
        return _render(
            request,
            "login.html",
            {
                "title": "Вход",
                "description": "Вход в личный кабинет.",
                "error": "Неверная почта или пароль",
                "email": email,
                "next": _safe_next(next),
            },
            db=db,
            status_code=status.HTTP_401_UNAUTHORIZED,
        )
    response = RedirectResponse(_safe_next(next), status_code=status.HTTP_303_SEE_OTHER)
    web_session.remember(response, create_access_token(str(user.id)))
    return response


@router.get("/register/", response_class=HTMLResponse)
def register_form(request: Request, next: str | None = None, db: Session = DB) -> HTMLResponse:
    return _render(
        request,
        "register.html",
        {
            "title": "Регистрация",
            "description": "Создать аккаунт.",
            "next": _safe_next(next),
        },
        db=db,
    )


@router.post("/register/")
def register(
    request: Request,
    name: str = Form(...),
    email: str = Form(...),
    phone: str = Form(""),
    password: str = Form(...),
    next: str = Form("/"),
    db: Session = DB,
) -> Response:
    email = email.strip().lower()
    problem: str | None = None
    if len(password) < 8:
        problem = "Пароль должен быть не короче 8 символов"
    elif db.scalar(select(User.id).where(User.email == email)):
        problem = "Такая почта уже зарегистрирована"
    if problem:
        return _render(
            request,
            "register.html",
            {
                "title": "Регистрация",
                "description": "Создать аккаунт.",
                "error": problem,
                "name": name,
                "email": email,
                "phone": phone,
                "next": _safe_next(next),
            },
            db=db,
            status_code=status.HTTP_400_BAD_REQUEST,
        )
    user = User(
        name=name.strip() or "Гость",
        email=email,
        phone=phone.strip() or None,
        hashed_password=hash_password(password),
        role=UserRole.customer,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    response = RedirectResponse(_safe_next(next), status_code=status.HTTP_303_SEE_OTHER)
    web_session.remember(response, create_access_token(str(user.id)))
    return response


@router.post("/logout/")
def logout() -> Response:
    response = RedirectResponse("/", status_code=status.HTTP_303_SEE_OTHER)
    web_session.forget(response)
    return response


# ------------------------------------------------------------------ checkout


def _checkout_context(request: Request, db: Session, user: User, **extra) -> dict:
    cart = _cart(request)
    restaurant, lines, subtotal = cart_store.hydrate(db, cart)
    context = {
        "title": "Оформление заказа",
        "description": "Адрес, способ получения и оплата.",
        "restaurant": restaurant,
        "lines": lines,
        "subtotal": subtotal,
        "viewer": user,
        "card_enabled": order_service.card_connected(),
    }
    context.update(extra)
    return context


@router.get("/checkout/", response_class=HTMLResponse)
def checkout_form(request: Request, db: Session = DB) -> Response:
    user = _viewer(request, db)
    if user is None:
        return RedirectResponse("/login/?next=/checkout/", status_code=status.HTTP_303_SEE_OTHER)
    cart = _cart(request)
    if cart.is_empty():
        return RedirectResponse("/cart/", status_code=status.HTTP_303_SEE_OTHER)
    return _render(request, "checkout.html", _checkout_context(request, db, user), db=db)


@router.post("/checkout/")
def checkout(
    request: Request,
    address: str = Form(""),
    channel: str = Form("delivery"),
    pay_method: str = Form("cash"),
    comment: str = Form(""),
    promo_code: str = Form(""),
    db: Session = DB,
) -> Response:
    user = _viewer(request, db)
    if user is None:
        return RedirectResponse("/login/?next=/checkout/", status_code=status.HTTP_303_SEE_OTHER)
    cart = _cart(request)
    restaurant, lines, _ = cart_store.hydrate(db, cart)
    if restaurant is None or not lines:
        return RedirectResponse("/cart/", status_code=status.HTTP_303_SEE_OTHER)

    def refuse(message: str, code: int = status.HTTP_400_BAD_REQUEST) -> HTMLResponse:
        return _render(
            request,
            "checkout.html",
            _checkout_context(
                request,
                db,
                user,
                error=message,
                address=address,
                channel=channel,
                pay_method=pay_method,
                comment=comment,
                promo_code=promo_code,
            ),
            db=db,
            status_code=code,
        )

    try:
        payload = OrderCreate(
            restaurant_id=restaurant.id,
            address=address.strip() or None,
            channel=channel if channel in ("delivery", "pickup") else "delivery",
            comment=comment.strip() or None,
            pay_method=pay_method if pay_method in ("cash", "online") else "cash",
            promo_code=promo_code.strip() or None,
            items=[{"menu_item_id": line.item.id, "quantity": line.quantity} for line in lines],
        )
    except ValidationError:
        return refuse("Укажите адрес доставки или выберите самовывоз")

    try:
        order = order_service.create_order(db, user, payload, origin=_base_url() or None)
    except HTTPException as exc:
        # The kitchen being full, an address out of range, a dead promo — all of
        # these are answers the visitor needs to read, not a 500 page.
        return refuse(str(exc.detail), code=status.HTTP_400_BAD_REQUEST)

    # Paid online: Stripe owns the next screen. Cash: straight to the ticket.
    target = order.checkout_url or f"/orders/{order.id}/"
    response = RedirectResponse(target, status_code=status.HTTP_303_SEE_OTHER)
    cart_store.save(response, cart_store.Cart())
    return response


# -------------------------------------------------------------------- orders


@router.get("/orders/", response_class=HTMLResponse)
def orders_page(request: Request, db: Session = DB) -> Response:
    user = _viewer(request, db)
    if user is None:
        return RedirectResponse("/login/?next=/orders/", status_code=status.HTTP_303_SEE_OTHER)
    orders = list(
        db.scalars(
            select(Order).where(Order.user_id == user.id).order_by(Order.created_at.desc()).limit(25)
        )
    )
    return _render(
        request,
        "orders.html",
        {"title": "Мои заказы", "description": "История заказов.", "orders": orders},
        db=db,
    )


@router.get("/orders/{order_id}/", response_class=HTMLResponse)
def order_page(order_id: int, request: Request, db: Session = DB) -> Response:
    user = _viewer(request, db)
    if user is None:
        return RedirectResponse(
            f"/login/?next=/orders/{order_id}/", status_code=status.HTTP_303_SEE_OTHER
        )
    order = db.get(Order, order_id)
    if order is None or order.user_id != user.id:
        # Someone else's ticket looks exactly like one that never existed.
        raise HTTPException(status.HTTP_404_NOT_FOUND, "No such order")
    return _render(
        request,
        "order.html",
        {
            "title": f"Заказ #{order.id}",
            "description": "Статус заказа.",
            "order": order,
        },
        db=db,
    )


# ------------------------------------------------------------------ crawlers


@router.get("/robots.txt", response_class=PlainTextResponse)
def robots() -> Response:
    base = _base_url()
    # Everything behind a login is worthless in an index, and the API would only
    # burn crawl budget.
    body = "\n".join(
        [
            "User-agent: *",
            "Disallow: /api/",
            "Disallow: /docs",
            "Disallow: /cart/",
            "Disallow: /checkout/",
            "Disallow: /orders/",
            "Disallow: /login/",
            "Disallow: /register/",
            "Allow: /",
            f"Sitemap: {base}/sitemap.xml",
            "",
        ]
    )
    return PlainTextResponse(body)


@router.get("/sitemap.xml")
def sitemap(db: Session = DB) -> Response:
    base = _base_url()
    urls = [f"{base}/", f"{base}/actions/", f"{base}/delivery/", f"{base}/about/"]
    urls += [
        f"{base}/r/{slug}/"
        for slug in db.scalars(select(Restaurant.slug).where(Restaurant.slug.is_not(None)))
    ]
    # Only running campaigns: a sitemap that lists a finished one sends a
    # crawler to a 404 and spends its budget doing it.
    urls += [f"{base}/actions/{offer.slug}" for offer in offers.live(db)]
    # The default city is already "/". A city with no venues is noindex, so
    # listing it would only send a crawler to a page it is told to drop.
    default = cities.default(db)
    for c in cities.active(db):
        if default and c.id == default.id:
            continue
        has_venue = db.scalar(
            select(Restaurant.id).where(Restaurant.city_id == c.id).limit(1)
        )
        if has_venue:
            urls.append(f"{base}/{c.slug}/")
    body = "".join(f"<url><loc>{url}</loc></url>" for url in urls)
    xml = (
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'
        f"{body}</urlset>"
    )
    return Response(content=xml, media_type="application/xml")


# ------------------------------------------------------------------- city pages
# Must stay last: routes match in order, so a one-segment catch-all shadows any
# page registered after it. The slug itself can't collide with a page either —
# see cities.RESERVED_SLUGS.
@router.get("/{city_slug}/", response_class=HTMLResponse)
def city_page(city_slug: str, request: Request, db: Session = DB) -> Response:
    city = cities.by_slug(db, city_slug)
    if city is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "No such city")
    default = cities.default(db)
    if default and city.id == default.id:
        return RedirectResponse("/", status_code=status.HTTP_301_MOVED_PERMANENTLY)
    return _landing(request, db, city)
