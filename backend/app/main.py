import asyncio
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from sqlalchemy import text
from starlette.responses import Response

from app.api.v1.router import api_router
from app.core.config import settings
from app.core.events import hub
from app.core.ratelimit import limiter
from app.db.session import SessionLocal


@asynccontextmanager
async def lifespan(_: FastAPI):
    if settings.allow_ephemeral_db:
        from app.db.seed import seed
        from app.db.session import Base, engine

        Base.metadata.create_all(bind=engine)
        seed()
    # Sync endpoints run in a threadpool; hub needs the main loop to push WS frames.
    hub.bind_loop(asyncio.get_running_loop())
    yield


docs = None if settings.is_prod else "/docs"
app = FastAPI(
    title="Food Delivery API",
    version="0.5.0",
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


@app.middleware("http")
async def security_headers(request: Request, call_next) -> Response:
    response = await call_next(request)
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
