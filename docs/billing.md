# Billing

Plans and entitlements are data in `app/core/features.py`. Business code checks `entitlements(db, restaurant).enabled("delivery.enabled")`, never `if plan == "premium"`.

| Plan | Delivery | Tables (default) | Staff |
|---|---|---|---|
| Basic | no | 20 | 5 |
| Pro | yes | 100 | 30 |
| Premium | yes | unlimited | unlimited |

Limits are in that registry, not in widgets. Per-restaurant `feature_overrides` can flip a single key without changing the plan.

Existing venues default to **Pro** so the marketplace delivery flow keeps working.

## Payments

`app/core/billing.py` defines `PaymentProvider`. The only implementation is `UnconfiguredProvider`, which returns HTTP 501. There is no Stripe/Kaspi integration and no fake MRR on the platform overview.

Billing status on the restaurant (`trial`, `active`, `past_due`, `grace_period`, `suspended`, `cancelled`, `expired`) is stored. `suspended` / `cancelled` / `expired` refuse new orders. Nothing auto-transitions yet.

Setup fee vs subscription is a billing concern for when a provider is wired. Do not collect card data in this app until then.
