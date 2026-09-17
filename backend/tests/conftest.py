import os

os.environ["DATABASE_URL"] = "sqlite:///./test.db"

import pytest
from fastapi.testclient import TestClient

from app.db.seed import seed
from app.db.session import Base, engine
from app.main import app


@pytest.fixture(scope="session")
def client():
    Base.metadata.drop_all(bind=engine)
    seed()
    with TestClient(app) as c:
        yield c
    Base.metadata.drop_all(bind=engine)


@pytest.fixture
def auth(client) -> dict[str, str]:
    r = client.post("/api/v1/auth/login/json", json={"email": "user@food.dev", "password": "user123"})
    return {"Authorization": f"Bearer {r.json()['access_token']}"}
