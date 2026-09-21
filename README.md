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
| PATCH | /api/v1/me | user |
| GET/POST/DELETE | /api/v1/me/addresses[/{id}] | user |
| POST | /api/v1/orders/{id}/rate | customer (delivered) |
| GET | /api/v1/restaurants/cuisines | – |
| GET/PATCH | /api/v1/admin/restaurants[/{id}] | admin |
| POST | /api/v1/admin/restaurants/{id}/menu | admin |
| PATCH/DELETE | /api/v1/admin/menu/{id} | admin |

Order status machine: `pending → confirmed → preparing → on_the_way → delivered`; cancel allowed from `pending`/`confirmed`.
Admin confirms; courier picks up from `confirmed`/`preparing` and advances step by step.

Live updates: `WS /api/v1/ws?token=<jwt>` streams `{"type":"order.updated","order":{...}}` to the customer, assigned courier, and all staff on every change. In-process hub — single instance; swap for Redis pub/sub to scale out.

Prod: set `ENV=prod` and a real `SECRET_KEY` — the app refuses to start with the default key.

Schema migrations: `cd backend && uv run alembic revision --autogenerate -m "..." && uv run alembic upgrade head`.

## Motion system

`mobile/lib/core/theme/motion.dart` holds the tokens; `core/widgets/` the primitives. Values lifted from
[animate-ui](https://animate-ui.com) and [jitter](https://jitter.video/templates/ui-elements/) presets:

| Primitive | Source | Notes |
|---|---|---|
| `Pressable` | animate-ui Button `tapScale 0.95` | wraps cards, buttons, stars |
| `SlidingNumber` | jitter Counter | digits roll on change — cart totals, qty |
| `.stagger(i)` | jitter Animated App List | fade + slide-up, 55 ms interval |
| `Shimmer` / `Bone` | — | skeleton while lists load |
| `SuccessCheck` | jitter Loading → Success | drawn with `CustomPainter` after checkout |
| `StretchSwitch` | animate-ui Switch `pressedWidth` | thumb stretches while pressed |
| `PillTabBar` | animate-ui Tabs (spring 300/32) | sliding pill indicator |
| `LiveToast` | jitter Simple Notification | WS events → top banner, per role |
| `AnimatedGradient` | animate-ui Gradient background | login backdrop |
| `QuantityStepper` | jitter View Cart: Split | `+` morphs into `− n +` |
| Item bottom sheet | animate-ui Sheet (spring 150/22) | emphasized curve |
| `Hero` restaurant image | — | list → detail |

Theme: Manrope via `google_fonts`, light + dark from one seed, 20px radii, flat cards.

## Tests

```bash
cd backend && uv run pytest
cd mobile && flutter test
```

## Roadmap

- [x] Courier role + order assignment
- [x] Alembic migrations, Postgres via docker compose
- [x] Live order updates over WebSocket
- [x] GitHub Actions CI (ruff, pytest, alembic check, dart format, analyze, flutter test)
- [x] Customer profile, saved addresses, address picker at checkout
- [x] Order rating → restaurant running average
- [x] Cuisine filter
- [ ] Push notifications when app is in background (FCM)
- [x] Admin panel in-app (confirm/advance orders, toggle restaurant, edit menu)
- [ ] Map/geocoding for address
- [ ] Payments (Kaspi / Stripe)
