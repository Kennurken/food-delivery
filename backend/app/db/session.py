from collections.abc import Generator

from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker
from sqlalchemy.pool import NullPool

from app.core.config import settings

sqlite = settings.sqlalchemy_url.startswith("sqlite")
kwargs: dict = {
    "connect_args": {"check_same_thread": False} if sqlite else {},
    "pool_pre_ping": True,
}
if not sqlite:
    # Vercel Functions + Neon: no persistent connections across invocations.
    kwargs["poolclass"] = NullPool
engine = create_engine(settings.sqlalchemy_url, **kwargs)
SessionLocal = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)


class Base(DeclarativeBase):
    pass


def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
