# What to do next

Researched 21 Sep 2026 against GitHub READMEs, issue lists, file trees, Glovo/Wolt/Chocofood first-party pages, and this repo. Companion view: Cursor canvas `next-research.canvas.tsx`.

Second GitHub pass (same day) went deeper on clones vs real Glovo/Wolt: Enatega is a feature checklist with a **closed API**; FastAPI delivery platforms with stars barely exist; Glovo-class OSS does not.

## Verdict

Do **not** rebuild as a Firebase clone. The stack (Flutter + FastAPI + Neon, three live roles, WebSocket status, en/ru/kk) is already ahead of the 1k-star UI-only GitHub demos.

**Shipped 21 Sep 2026:** web column ~560px, customer sliding-pill bottom nav, dish photos + dish search, persist cart, reduced motion, empty-cart CTA, login password visibility, reorder, home sort + Popular, KZ address extras, admin add-restaurant, favorite restaurants, admin floor-plan editor.

**Shipped 22 Sep 2026:** tenant = restaurant, plan entitlements, table QR (`/t/:token`), dine-in orders, membership isolation, platform counts (no fake MRR).

**Shipped 22 Sep 2026 (later):** pickup channel + kitchen board. Same status machine for delivery / pickup / table QR.

**Shipped 22 Sep 2026 (maps):** OSM tiles, center-pin address picker, restaurant pins, driving polyline, live courier GPS. No Google/Yandex/2GIS SDK.

**Shipped 22 Sep 2026 (checkout):** item modifiers with ticket snapshot, cash-on-delivery (unpaid), device tokens, local notifications when paused. No Kaspi/Stripe/FCM keys — card checkout is 409, FCM send is 0.

**Shipped 22 Sep 2026 (offers):** checkout slot (`scheduled_for`, 30 min–48 h, 15-min picker), kitchen Later lane, courier pool waits until 40 min before the slot. Restaurant promo codes (`BAO10` / `PIZZA500` / `SMASH500` on the demo catalog), quoted at checkout, snapshotted on the ticket. Table QR cannot be scheduled. Card/FCM still blocked on keys.

**Shipped 22 Sep 2026 (chat):** one thread per order. Customer, kitchen, assigned courier, platform admin. Closed when the ticket is final. Same WebSocket; `order.chat` does not refetch the kitchen board. Card/FCM still blocked on keys.

**Next:** reservations if we want the next no-key slice. Card/FCM stay blocked on keys.

## What we already have

- Customer: browse, cuisine chip, restaurant + **dish** search, hero + dish photos, cart (secure-storage persist), addresses, live order status over WebSocket, rating, bottom nav, constrained web shell.
- Courier / admin in the same app (`mobile/lib/core/router/app_router.dart`).
- Motion tokens (`mobile/lib/core/theme/motion.dart`) from animate-ui / jitter; Manrope; seed `#E8562A`.
- Prod: Vercel + Neon, no public `admin123`.

## GitHub (stars from `gh search`, 21 Sep 2026)

| Repo | Stars | Steal | Skip |
|---|---:|---|---|
| [enatega/food-delivery-multivendor](https://github.com/enatega/food-delivery-multivendor) | 1376 | Screen list: favorites, reorder, rider chat, pickup vs delivery, variations, rider earnings/wallet. [README](https://github.com/enatega/food-delivery-multivendor). | Proprietary API. 100+ open issues (chat never reaches admin, OTP hardcoded). |
| [Tarikul711/flutter-food-delivery-app-ui](https://github.com/Tarikul711/flutter-food-delivery-app-ui) | 1210 | Category rail, route transitions. | UI only; README says incomplete. |
| [WanyueKJ/Food-delivery-uniapp](https://github.com/WanyueKJ/Food-delivery-uniapp) | 801 | Courier **grab-order** (抢单); `package-shansong` is a Glovo “Anything” analogue. | Frontends only; PHP backend commercial; SMS `123456`. |
| [AhmedLSayed9/deliverzler](https://github.com/AhmedLSayed9/deliverzler) | 733 | Courier map, FCM, nested GoRouter, Riverpod. | Firebase + Maps billing. |
| [vinothvino42/SwiggyUI](https://github.com/vinothvino42/SwiggyUI) | 625 | Home as **modules** (spotlight, categories, offers, ETA+rating chrome), not a flat list. Live: [swiggyuiclone.web.app](https://swiggyuiclone.web.app). | Pixel clone, hardcoded lists, no orders. |
| [siam1026/siam-server](https://github.com/siam1026/siam-server) | 505 | Shop admin vs city dispatch; cashier/POS; coupons; refunds; printers. Apache-2.0. | Rider/shop mini-program source gated; JDK 8. |
| [sergeyCodenameOne/UberEatsClone](https://github.com/sergeyCodenameOne/UberEatsClone) (Grub) | 547 | Filter sheet (cuisine/rating/price); promo as a cart line; cancelled-order UI; onboarding before location. | Visual only, no backend. Codename One. |
| [f-lab-edu/food-delivery](https://github.com/f-lab-edu/food-delivery) | 445 | Coupons in the ERD; owner vs customer screens. | Dead study project (CI off since 2020). |
| [FilledStacks/boxtout](https://github.com/FilledStacks/boxtout) | 412 | Split customer / driver / restaurant as products. | Tutorial series, dated. |
| [adrianhajdin/food_ordering](https://github.com/adrianhajdin/food_ordering) | 323 | Search-first tabs; offers that deep-link into filtered search. | RN + Appwrite; `.env` committed. |
| [amritmaurya1504/Restaurant_POS_System](https://github.com/amritmaurya1504/Restaurant_POS_System) | 301 | Table as an entity; POS chrome. | Categories/items static ([#1](https://github.com/amritmaurya1504/Restaurant_POS_System/issues/1)). |
| [medusajs/medusa-eats](https://github.com/medusajs/medusa-eats) | 264 | Delivery **workflow with human waits** (`await-start-preparation` → pickup → deliver); SSE subscribe. Best OSS model of our status machine. | Hackathon, unmaintained; restaurant login broken. |
| [mehdihadeli/go-food-delivery-microservices](https://github.com/mehdihadeli/go-food-delivery-microservices) | 1133 | Catalog write vs read; outbox for “pay then order.” | No GUI, no riders. Architecture sample only. |
| [satisfecho/pos](https://github.com/satisfecho/pos) | 45 | FastAPI QR menu, KDS, WebSockets, multi-tenant. Closest FastAPI cousin. | Dine-in POS, not marketplace. |

`gh search` for FastAPI food-delivery above 20★ returns almost nothing runnable. Glovo clones top out at 7★ UI practice. Do not paste Enatega, Tomato (no Restaurant model), or Flutter UI-only repos as architecture.

## Real apps (first party)

- **Glovo** ([FAQ](https://customer-microsite.glovoapp.com/en/faq/)): address before browse; scheduled orders; chat; promo; Prime; cash/card. Kazakhstan is a live market.
- **Wolt** ([item search](https://life.wolt.com/en/fin/howto/hacks/item-search), [scheduled](https://life.wolt.com/en/fin/howto/hacks/scheduled-orders), [Wolt+](https://explore.wolt.com/en/deu/wolt-plus)): dish-first search; discovery carousels; schedule at checkout; membership.
- **Chocofood** ([App Store](https://apps.apple.com/us/app/chocofood-kz-%D0%B4%D0%BE%D1%81%D1%82%D0%B0%D0%B2%D0%BA%D0%B0-%D0%B5%D0%B4%D1%8B/id1033887038)): courier on map, saved addresses, promos, card or cash, support, ~32 min average.

We match the **order machine** (pending → delivered), **basic discovery** (photos, dish search, phone-width web), checkout extras (modifiers, cash, schedule, one promo), and a live courier map. We still do not match subscriptions, courier matching, or payouts.

Clones almost never implement: Uber One / Glovo Prime / Wolt+; scheduled slots; grocery/Anything verticals; geo matching; proof of delivery; live map of a named courier; in-app chat ops can see; dynamic fees; restaurant auto-pause; promo stacking; courier wallet/KYC; merchant KDS; refunds/SLA; group order.

## Gaps in this repo

| Area | Evidence | Cheap? | Status |
|---|---|---|---|
| Web max-width | `AppShell` ~560px | Yes | Done |
| Bottom nav | `SlidingBottomNav` on customer shell | Yes | Done |
| Dish photos | Seed + `DishThumb` on menu/cart/sheet | Yes | Done |
| Dish search | `q` matches `MenuItem.name` | Yes | Done |
| Persist cart | `CartStorage` via secure storage | Yes | Done |
| Empty CTAs / greeting / reduced motion | Cart EmptyState; no 👋; `Motion.reduced` | Yes | Done |
| Sort | Cuisine chip only; no rating / ETA / fee sort | Yes | Done |
| Home modules | Flat restaurant list | Yes | Done |
| Reorder | History exists; no “order again” | Yes | Done |
| Favorites | Heart on cards + `/me/favorites` + Saved row | Yes | Done |
| Item modifiers | `OrderItem` is name+price+qty snapshot | Medium | Done |
| KZ address | `Address.line` plus apt / entrance / floor / intercom | Yes | Done |
| Admin create restaurant | `POST /admin/restaurants` + FAB | Yes | Done |
| Floor plan editor | Admin canvas: floors, zones, tables, save/undo | Medium | Done |
| Tenant / plans / QR table order | Restaurant membership + entitlements + `/t/:token` | Medium | Done |
| COD | Place order = done | Yes | Done |
| Scheduled slot | Cart picker; `scheduled_for` on the ticket | Yes | Done |
| Promo code | One per order, restaurant-scoped, `promotions` entitlement | Yes | Done |
| In-app chat | One thread per order; ops can see it | Medium | Done |
| Maps / FCM / Kaspi | Blocked until keys | No | Maps done; FCM/Kaspi wait |

UI guidelines: [Vercel Web Interface Guidelines](https://raw.githubusercontent.com/vercel-labs/web-interface-guidelines/main/command.md). Flutter web canvaskit still ignores programmatic input (a11y tree ≠ `TextEditingController`).

## Suggested order

1. ~~Web shell, empty CTAs, drop 👋.~~
2. ~~Dish photos + dish search.~~
3. ~~Persist cart.~~ (COD radio still optional, no PSP.)
4. ~~Reorder from history.~~
5. ~~Home modules + sort.~~
6. ~~Structured address; admin “add restaurant” dialog (API exists).~~
7. ~~Favorites.~~
8. ~~Admin floor-plan editor.~~
9. ~~QR table ordering + plan entitlements.~~
10. ~~Item options.~~ Medusa workflow steps stay our status machine — keep WebSocket.
11. ~~Scheduled checkout + restaurant promo codes.~~
12. ~~Order chat (kitchen / courier / customer).~~
13. FCM / Kaspi / Stripe — after keys. Enatega/Deliverzler as checklists, not code to paste.
14. Later, if we want Glovo not just food: Wanyue grab-order + Anything; Siam/Satisfecho if we care about restaurant POS.
