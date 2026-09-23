import asyncio
from contextlib import asynccontextmanager
from uuid import uuid4

from fastapi import FastAPI, HTTPException, Request
from fastapi.exception_handlers import http_exception_handler
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from sqlalchemy import text
from starlette.exceptions import HTTPException as StarletteHTTPException
from starlette.responses import Response

from app.api.v1.router import api_router
from app.core.config import settings
from app.core.events import hub
from app.core.ratelimit import limiter
from app.db.session import SessionLocal
from app.web.site import ASSET_VERSION as site_asset_version
from app.web.site import HERE as SITE_ROOT
from app.web.site import router as site_router
from app.web.site import templates as site_templates

SITE_STATIC = SITE_ROOT / "static"


@asynccontextmanager
async def lifespan(_: FastAPI):
    if settings.allow_ephemeral_db:
        from app.db.seed import seed
        from app.db.session import Base, engine

        Base.metadata.create_all(bind=engine)
        seed()
    elif not settings.sqlalchemy_url.startswith("sqlite"):
        from app.db.seed import (
            ensure_address_columns,
            ensure_capacity_schema,
            ensure_chat_schema,
            ensure_checkout_schema,
            ensure_courier_payout_schema,
            ensure_delivery_pricing_schema,
            ensure_demo_modifiers,
            ensure_demo_promos,
            ensure_favorites_table,
            ensure_floor_plan_tables,
            ensure_geo_schema,
            ensure_handover_schema,
            ensure_menu_images,
            ensure_offers_schema,
            ensure_reservations_schema,
            ensure_restaurant_coords,
            ensure_restaurant_slugs,
            ensure_saas_schema,
            ensure_slug_schema,
            ensure_subscription_schema,
            seed_catalog,
        )

        # Shape the schema before touching a single row. These run on hosts
        # without alembic, and anything below here selects through the ORM —
        # which asks for every column the models declare, including the ones
        # this block is here to add.
        ensure_address_columns()
        ensure_favorites_table()
        ensure_floor_plan_tables()
        ensure_saas_schema()
        ensure_geo_schema()
        ensure_checkout_schema()
        ensure_offers_schema()
        ensure_chat_schema()
        ensure_reservations_schema()
        ensure_delivery_pricing_schema()
        ensure_handover_schema()
        ensure_capacity_schema()
        ensure_courier_payout_schema()
        ensure_slug_schema()
        ensure_subscription_schema()

        # Now the data.
        seed_catalog()
        ensure_menu_images()
        ensure_restaurant_coords()
        ensure_demo_modifiers()
        ensure_demo_promos()
        ensure_restaurant_slugs()
    # Sync endpoints run in a threadpool; hub needs the main loop to push WS frames.
    hub.bind_loop(asyncio.get_running_loop())
    yield


docs = None if settings.is_prod else "/docs"
app = FastAPI(
    title="Food Delivery API",
    version="0.12.0",
    lifespan=lifespan,
    docs_url=docs,
    redoc_url=None if settings.is_prod else "/redoc",
    openapi_url=None if settings.is_prod else "/openapi.json",
)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_origin_regex=settings.cors_origin_regex or None,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router)

# The public site. Mounted after the API so /api/v1 keeps its paths, and the
# static bundle sits under /site so it cannot collide with a restaurant slug.
app.mount("/site", StaticFiles(directory=str(SITE_STATIC)), name="site")
app.include_router(site_router)


@app.exception_handler(StarletteHTTPException)
async def _not_found(request: Request, exc: StarletteHTTPException):
    """A stranger who mistypes a restaurant URL should land on a page, not on
    a JSON blob. API paths keep the machine-readable answer."""
    wants_json = request.url.path.startswith(("/api/", "/health", "/docs", "/openapi"))
    if wants_json or exc.status_code != 404:
        return await http_exception_handler(request, exc)
    return site_templates.TemplateResponse(
        request,
        "404.html",
        {
            "title": "Страница не найдена",
            "description": "Такой страницы нет.",
            "app_url": settings.public_app_url.rstrip("/"),
            "asset_version": site_asset_version,
        },
        status_code=404,
    )


@app.middleware("http")
async def request_context(request: Request, call_next) -> Response:
    rid = request.headers.get("x-request-id") or uuid4().hex[:16]
    request.state.request_id = rid
    response = await call_next(request)
    response.headers["X-Request-ID"] = rid
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["Referrer-Policy"] = "no-referrer"
    if settings.is_prod:
        response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    return response


@app.get("/health", tags=["meta"])
def health() -> dict[str, str]:
    try:
        with SessionLocal() as db:
            db.execute(text("SELECT 1"))
    except Exception as exc:
        raise HTTPException(status_code=503, detail="database unavailable") from exc
    return {"status": "ok"}
