# Multi-tenancy

Every restaurant-scoped query takes `restaurant_id` from the URL or from a row the caller already loaded (floor → restaurant). Platform admins may act on any restaurant. Everyone else needs a `restaurant_members` row.

Permissions live in `app/core/access.py`. Roles map to permissions (`menu.write`, `tables.read`, …). Endpoints call `require_restaurant(db, user, restaurant_id, permission)` instead of `if user.role == "admin"` sprinkled through the app.

Isolation test: a manager of restaurant 1 can read its floors and cannot read restaurant 2.

Uploaded files, cache keys, and audit rows should carry `restaurant_id`. File storage is not wired yet; when it is, prefix object keys with the restaurant id.

Downgrade does **not** delete data. A restaurant that drops from Premium to Basic keeps extra tables/branches; new ones are rejected when over the plan limit.
