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
    │     └── orders (delivery | pickup | qr_table)
    └── Restaurant B
```

Do not split this into microservices until a domain actually needs its own deploy cycle. Boundaries that *could* extract later: notifications, billing, analytics, search.

## Request context

Every response includes `X-Request-ID`. The backend never trusts client-supplied `role`, `plan`, or `restaurant_id` for authorization — membership and `UserRole` are loaded from the database.

## Events

`OrderHub` is still in-process WebSocket. Payloads include `restaurant_id`, `channel`, and `cause` (`status`, `location`, or a separate `order.chat` frame). Location and chat must not toast as status changes or refetch kitchen lists. Swap for Redis when there is more than one API instance.

## Maps

Tiles render in Flutter (`flutter_map` + Carto Voyager / Dark Matter). Geocoding and routing never leave the API (`app.core.geo`): Photon, then Nominatim; OSRM, then a straight line. `GEO_PROVIDER=fixture` keeps tests offline. Default camera is Republic Square, Almaty. Courier GPS lives on `User.last_*` and is snapshotted onto assigned orders over the socket.

## Checkout

`price_line` applies modifier groups on `MenuItem`. Empty `option_ids` pick each group's defaults so older clients still price Regular. The ticket stores `{group, option_id, name, price}` on `OrderItem.modifiers`; unit `price` already includes deltas.

`pay_method=cash` → unpaid. `pay_method=online` without a card key → 409. Device tokens live on `device_tokens`. `app.core.push.fanout` speaks FCM HTTP v1 and is a no-op unless `FCM_CREDENTIALS_JSON` holds a service account; it never fails an order, and it drops tokens Google reports as `UNREGISTERED`.

## Offers

`scheduled_for` is a UTC-naive slot between 30 minutes and 48 hours. Table QR cannot be scheduled. Couriers only see a delivery once the slot is within 40 minutes (`due_for_courier` + the available-pool filter). Kitchen puts those tickets in a Later lane.

Promo codes are restaurant-scoped (`promos`, unique on restaurant + code). Checkout quotes one code via `GET /restaurants/{id}/promo`. The ticket stores `promo_code` + `discount`; `used_count` increments on a successful create. Applying a code requires the `promotions` entitlement, not `if plan == "pro"`. Demo catalog: `BAO10`, `PIZZA500`, `SMASH500`.

## Chat

One thread per order (`order_messages`). Same people as `GET /orders/{id}`: customer, assigned courier, staff with `orders.read`, platform admin. Unassigned couriers cannot read it. Write is closed after delivered/cancelled. Frames are `{"type":"order.chat","message":{...}}` so kitchen lists do not refetch. FCM still no-ops without a key.

## Reservations

Entitlement `reservations` (Pro+). There is no separate Table table — bookings point at `FloorObject` rows whose `kind` is in `TABLE_KINDS`. Customer `POST /reservations` 30 min–14 days out. Picking a free table auto-confirms and sets the object `available → reserved`. No table stays `requested` until kitchen confirms. `seated` → `occupied`. Cancel/no-show only releases `reserved`, never `occupied` (QR dine-in may already be sitting there). Kitchen walk-in skips the 30-minute lead.

## Cache keys

`app.core.features.cache_key(restaurant_id, ...)` → `tenant:{id}:...`. No Redis yet; use this helper when one is added.
