# Feature matrix

Status is against this repo, not the long-term product spec.

| Feature | Status | Plan key |
|---|---|---|
| QR menu / table token | **Shipped** | `qr.menu`, `table.ordering` |
| Digital catalog | **Existing** | `catalog` |
| Delivery orders | **Existing** | `delivery.enabled` |
| Floor plan + real tables | **Existing** | `floor_plan` |
| Favorites, sort, KZ address | **Existing** | — |
| Entitlements / plans | **Shipped** | registry |
| Restaurant memberships | **Shipped** | `staff.*` |
| Audit log | **Shipped** (plan/staff/create) | — |
| Platform overview | **Shipped** (real counts, no MRR) | — |
| Order idempotency | **Shipped** | header |
| Pickup | **Shipped** | `pickup.enabled` |
| KDS | **Shipped** (same order machine) | `kds` |
| Maps (address + live courier) | **Shipped** (OSM / Photon / OSRM, no Google key) | — |
| Item modifiers | **Shipped** (catalog + `OrderItem` snapshot) | — |
| Cash / COD | **Shipped** (`pay_method=cash`, status `unpaid`) | — |
| Device tokens | **Shipped** (`PUT /me/devices`; FCM send no-op without key) | `notifications` |
| Scheduled delivery / pickup | **Shipped** (`scheduled_for`, 30 min–48 h; couriers see it 40 min out) | — |
| Promotions | **Shipped** (one restaurant-scoped code per order) | `promotions` |
| Order chat | **Shipped** (one thread per ticket; kitchen/courier/customer) | — |
| Reservations | Missing | `reservations` |
| Online payments | Adapter only (`409` without a card key) | `payments.online` |
| Notifications (SMS/email) | Missing | `notifications` |
| Multi-branch | Missing | `multi_branch` |
| Inventory / costing | Missing | `inventory` |
| Loyalty / CRM | Missing | `loyalty` |
| Public API keys / webhooks | Missing | `api.public`, `webhooks` |
| Custom domain / white-label | Missing | `custom_domain` |
| AI | Missing | `ai` |

Registry: `backend/app/core/features.py`. One list, used by API, admin workspace, and tests.
