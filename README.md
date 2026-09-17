# Food Delivery

Mobile food delivery app. Flutter client + FastAPI backend.

```
food-delivery/
├── backend/                 # Python 3.12+, FastAPI, SQLAlchemy 2, JWT
│   ├── app/
│   │   ├── api/v1/          # auth, restaurants, orders routers
│   │   ├── core/            # config, security (bcrypt + JWT)
│   │   ├── db/              # session, seed
│   │   ├── models/          # User, Restaurant, MenuItem, Order, OrderItem
│   │   ├── schemas/         # Pydantic I/O
│   │   ├── services/        # order_service (pricing, status machine)
│   │   └── main.py
│   └── tests/
└── mobile/                  # Flutter 3.47, Riverpod 3, go_router, dio
    └── lib/
        ├── core/            # api client, secure token storage, router, theme
        └── features/        # auth, restaurants, cart, orders (data/domain/presentation)
```

## Run

Backend:
```bash
cd backend && uv sync && uv run alembic upgrade head && uv run python -m app.db.seed && uv run uvicorn app.main:app --reload
```
Or with Postgres: `docker compose up --build` (then seed inside: `docker compose exec api uv run python -m app.db.seed`).

Swagger: http://127.0.0.1:8000/docs — dev users `user@food.dev / user123`, `courier@food.dev / courier123`, `admin@food.dev / admin123`.

Mobile:
```bash
cd mobile && flutter run
```
Android emulator hits `10.0.2.2:8000`, iOS sim hits `127.0.0.1:8000`. Override: `--dart-define=API_URL=http://host:8000`.

## API

| Method | Path | Auth |
|---|---|---|
| POST | /api/v1/auth/register | – |
| POST | /api/v1/auth/login/json | – |
| GET | /api/v1/auth/me | user |
| GET | /api/v1/restaurants?q=&cuisine= | – |
| GET | /api/v1/restaurants/{id} | – |
| POST | /api/v1/orders | user |
| GET | /api/v1/orders | user |
| GET | /api/v1/orders/{id} | user |
| POST | /api/v1/orders/{id}/cancel | customer |
| GET | /api/v1/orders/available | courier |
| POST | /api/v1/orders/{id}/accept | courier |
| POST | /api/v1/orders/{id}/advance | courier (assigned) |
| PATCH | /api/v1/orders/{id}/status | admin |

Order status machine: `pending → confirmed → preparing → on_the_way → delivered`; cancel allowed from `pending`/`confirmed`.
Admin confirms; courier picks up from `confirmed`/`preparing` and advances step by step. Client polls order every 4s until final.

Schema migrations: `cd backend && uv run alembic revision --autogenerate -m "..." && uv run alembic upgrade head`.

## Tests

```bash
cd backend && uv run pytest
cd mobile && flutter test
```

## Roadmap

- [x] Courier role + order assignment
- [x] Alembic migrations, Postgres via docker compose
- [ ] Push notifications on status change (FCM) — replaces polling
- [ ] Restaurant/admin panel (confirm orders, edit menu)
- [ ] Map/geocoding for address
- [ ] Payments (Kaspi / Stripe)
