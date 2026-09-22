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

Customer checkout uses `app/core/billing.py`. `CashProvider` creates an unpaid order. If `STRIPE_SECRET_KEY` is empty, `UnconfiguredProvider` returns HTTP 409 ("Card payments are not connected. Pay with cash.") — never a fake paid charge. With a Stripe test/live secret the API opens a Checkout Session; the order stays `pending` until Stripe reports `paid` (webhook or `POST /orders/{id}/pay/sync`). Kaspi is not wired. There is no fake MRR on the platform overview.

Do not put `sk_` keys in git. Local `backend/.env`, Vercel env for prod. After a secret leaks in chat, roll it in the Stripe dashboard.

Restaurant SaaS billing is still unconfigured. Billing status on the restaurant (`trial`, `active`, `past_due`, `grace_period`, `suspended`, `cancelled`, `expired`) is stored. `suspended` / `cancelled` / `expired` refuse new orders. Nothing auto-transitions yet.

Setup fee vs subscription is a billing concern for when a provider is wired. Do not collect card data in this app until then.
