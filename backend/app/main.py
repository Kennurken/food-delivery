import asyncio
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1.router import api_router
from app.core.events import hub


@asynccontextmanager
async def lifespan(_: FastAPI):
    # Sync endpoints run in a threadpool; hub needs the main loop to push WS frames.
    hub.bind_loop(asyncio.get_running_loop())
    yield


# Schema is managed by Alembic: `uv run alembic upgrade head`
app = FastAPI(title="Food Delivery API", version="0.3.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router)


@app.get("/health", tags=["meta"])
def health() -> dict[str, str]:
    return {"status": "ok"}
