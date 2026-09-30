# Billing

Plans and entitlements are data in `app/core/features.py`. Business code checks `entitlements(db, restaurant).enabled("delivery.enabled")`, never `if plan == "premium"`.

| Plan | Price / month | Delivery | Tables (default) | Staff |
|---|---|---|---|---|
| Basic | 9 990 ₸ | no | 20 | 5 |
| Pro | 29 990 ₸ | yes | 100 | 30 |
| Premium | 49 990 ₸ | yes | unlimited | unlimited |

There is no free tier. Every venue pays; guests pay the restaurant directly and the platform charges only this subscription.

Limits are in that registry, not in widgets. Per-restaurant `feature_overrides` can flip a single key without changing the plan.

Existing venues default to **Pro** so the marketplace delivery flow keeps working.

## Payments

Customer checkout uses `app/core/billing.py`. `CashProvider` creates an unpaid order. If `STRIPE_SECRET_KEY` is empty, `UnconfiguredProvider` returns HTTP 409 ("Card payments are not connected. Pay with cash.") — never a fake paid charge. With a Stripe test/live secret the API opens a Checkout Session; the order stays `pending` until Stripe reports `paid` (webhook or `POST /orders/{id}/pay/sync`). Kaspi is not wired. There is no fake MRR on the platform overview.

Do not put `sk_` keys in git. Local `backend/.env`, Vercel env for prod. After a secret leaks in chat, roll it in the Stripe dashboard.

## Restaurant subscription lifecycle

* Approving an application (`partners.decide`) starts a **30-day Pro trial**: `billing_status="trial"`, `plan_renews_at = now + 30d`.
* Vercel runs no scheduler, so nothing flips the state when the date passes. `subscriptions.effective_status()` computes it on every read: inside the end date the stored status stands; up to **7 days after** it the venue is `grace_period` and still takes orders; later it is `expired` and `create_order` answers 403. Menu, history and settings stay.
* `days_left()` feeds the app banners (trial ending, overdue, orders closed).
* A venue with no end date (seeded, platform-created) never times out; a venue with a Stripe subscription is left to Stripe's webhooks.
* The platform confirms money received outside Stripe (bank transfer, a Kazakh processor) with `POST /admin/restaurants/{id}/subscription/manual {plan_code, months}` — admin only, audited as `subscription.manual`. Paying early extends the current period. This and the Stripe webhook are the only two doors that mark a venue paid; nothing fakes it.
* Stripe cannot serve Kazakh merchants, so it stays wired but idle until a local processor (Kaspi Pay / Halyk / Freedom Pay) is added behind the same `record_payment`.

Setup fee vs subscription is a billing concern for when a provider is wired. Do not collect card data in this app until then.
