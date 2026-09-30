# Launch checklist

What must be true before real guests and a real restaurant use this.

## Done in code
- [x] Restaurants apply on the site or in the app; the platform approves before anyone sees them.
- [x] 30-day trial, 7-day grace, then orders close (see `billing.md`).
- [x] Restaurants hire their own couriers (`delivery_courier` staff); an unhired courier stays on the shared pool.
- [x] Optional error reporting (`SENTRY_DSN`) — nothing is sent without it.
- [x] `backend/scripts/backup_db.sh` — dump the production DB to a compressed file.

## Needs the owner (accounts or secrets — not something to commit)
- [ ] **Sentry**: create a project, put the DSN in Vercel as `SENTRY_DSN` (Production). Until then, failures are visible only in Vercel runtime logs.
- [ ] **Backups**: run `DATABASE_URL=… backend/scripts/backup_db.sh` on a schedule (cron/launchd on a machine that is on). Neon's built-in history is a rewind window, not a backup. Never store dumps in this public repo or its CI artifacts.
- [ ] **Real-phone test**: install the Android build, log in as a courier and a guest, place an order, watch the push arrive (FCM is wired but has not been seen on a device).
- [ ] **Domain**: buy one, then set `PUBLIC_SITE_URL`, `PUBLIC_APP_URL`, the app's API URL and the Vercel domains; canonical/hreflang/sitemap follow `PUBLIC_SITE_URL`.
- [ ] **Local payment processor** (Kaspi Pay / Halyk / Freedom Pay) under the legal entity; until then the platform records subscription payments by hand.
- [ ] **iOS**: Xcode target and APNs key.
