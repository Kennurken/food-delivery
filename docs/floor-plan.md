# Floor plan

Tables **are** `floor_objects` with `kind` starting `table_`. There is no separate Table table.

A table QR is HMAC(`restaurant_id.object_id`) using `SECRET_KEY`. Public `GET /api/v1/qr/{token}` returns restaurant + table names. Customer route: `/#/t/{token}`.

Saving a layout refuses *new* tables over `tables.max` for the restaurant's plan. Existing tables stay if the restaurant downgrades.
