# Backend

```bash
uv sync
uv run python -m app.db.seed
uv run uvicorn app.main:app --reload
```

Swagger: http://127.0.0.1:8000/docs

Dev accounts: `admin@food.dev / admin123`, `user@food.dev / user123` (local seed only).

Production: `uv run python -m app.db.seed --catalog-only` — restaurants plus random staff passwords, never `admin123`.

Tests: `uv run pytest`
