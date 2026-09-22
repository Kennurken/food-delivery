import os

os.environ.setdefault("DATABASE_URL", "sqlite:///./test.db")  # CI/PG can override
os.environ["LOGIN_RATE_LIMIT"] = "1000/minute"  # every fixture logs in from 127.0.0.1
os.environ["GEO_PROVIDER"] = "fixture"
os.environ["STRIPE_SECRET_KEY"] = ""
os.environ["STRIPE_PUBLISHABLE_KEY"] = ""
os.environ["STRIPE_WEBHOOK_SECRET"] = ""

import pytest
from fastapi.testclient import TestClient

from app.db.seed import seed
from app.db.session import Base, engine
from app.main import app


def _login(client, email, password) -> dict[str, str]:
    r = client.post("/api/v1/auth/login/json", json={"email": email, "password": password})
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


@pytest.fixture(scope="session")
def client():
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    seed()
    with TestClient(app) as c:
        yield c
    Base.metadata.drop_all(bind=engine)


@pytest.fixture
def auth(client):
    return _login(client, "user@food.dev", "user123")


@pytest.fixture
def courier(client):
    return _login(client, "courier@food.dev", "courier123")


@pytest.fixture
def admin(client):
    return _login(client, "admin@food.dev", "admin123")
