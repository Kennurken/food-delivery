from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1.router import api_router
from app.db.session import Base, engine


@asynccontextmanager
async def lifespan(_: FastAPI):
    import app.models  # noqa: F401 — register tables

    Base.metadata.create_all(bind=engine)
    yield


app = FastAPI(title="Food Delivery API", version="0.1.0", lifespan=lifespan)

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
