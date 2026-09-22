# Architecture

This is a **modular monolith**: FastAPI + SQLAlchemy + Flutter. One deployable API, one database, one app with three roles (customer, courier, platform admin).

Restaurant **is** the tenant. There is no separate `Tenant` table. Staff belong to a restaurant through `restaurant_members`. Platform operators keep `UserRole.admin` and are not members of any restaurant.

```
Platform admin
    │
    ├── Restaurant A  (tenant, plan=pro)
    │     ├── members
    │     ├── menu
    │     ├── floors / tables
    │     └── orders (delivery | qr_table)
    └── Restaurant B
```

Do not split this into microservices until a domain actually needs its own deploy cycle. Boundaries that *could* extract later: notifications, billing, analytics, search.

## Request context

Every response includes `X-Request-ID`. The backend never trusts client-supplied `role`, `plan`, or `restaurant_id` for authorization — membership and `UserRole` are loaded from the database.

## Events

`OrderHub` is still in-process WebSocket. Payloads include `restaurant_id` and `channel`. Swap for Redis when there is more than one API instance.

## Cache keys

`app.core.features.cache_key(restaurant_id, ...)` → `tenant:{id}:...`. No Redis yet; use this helper when one is added.
