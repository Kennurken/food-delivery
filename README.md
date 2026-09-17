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
cd backend && uv sync && uv run python -m app.db.seed && uv run uvicorn app.main:app --reload
```
Swagger: http://127.0.0.1:8000/docs — dev users `user@food.dev / user123`, `admin@food.dev / admin123`.

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
| POST | /api/v1/orders/{id}/cancel | user |
| PATCH | /api/v1/orders/{id}/status | admin |

Order status machine: `pending → confirmed → preparing → on_the_way → delivered`; cancel allowed from `pending`/`confirmed`.

## Tests

```bash
cd backend && uv run pytest
cd mobile && flutter test
```

## Roadmap

- [ ] Courier role + order assignment
- [ ] Push notifications on status change (FCM)
- [ ] Map/geocoding for address
- [ ] Payments (Kaspi / Stripe)
- [ ] Alembic migrations, Postgres in prod
- [ ] Docker compose
