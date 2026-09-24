"""Seed catalog (and optional demo users). Run after `alembic upgrade head`."""

from __future__ import annotations

import secrets

from sqlalchemy import select

import app.models  # noqa: F401
from app.core.security import hash_password
from app.db.session import SessionLocal
from app.models import MenuItem, ModifierGroup, ModifierOption, Restaurant, User, UserRole

RESTAURANTS = [
    {
        "name": "Bao Bar",
        "cuisine": "Asian",
        "description": "Steamed buns, ramen, wok.",
        "rating": 4.7,
        "delivery_fee": 500,
        "delivery_time_min": 25,
        "lat": 43.25654,
        "lng": 76.92812,
        "image_url": "https://images.unsplash.com/photo-1555126634-323283e090fa?w=800",
        "menu": [
            (
                "Pork Bao",
                "Steamed bun, pork belly, hoisin",
                1500,
                "Buns",
                "https://images.unsplash.com/photo-1563245372-f21724e3856d?w=600",
            ),
            (
                "Tonkotsu Ramen",
                "Rich pork broth, egg, chashu",
                2900,
                "Ramen",
                "https://images.unsplash.com/photo-1557872943-16a5ac26437e?w=600",
            ),
            (
                "Pad Thai",
                "Rice noodles, shrimp, peanuts",
                2600,
                "Wok",
                "https://images.unsplash.com/photo-1559314809-0d155014e29e?w=600",
            ),
        ],
    },
    {
        "name": "Pizza Roma",
        "cuisine": "Italian",
        "description": "Neapolitan pizza, wood-fired.",
        "rating": 4.5,
        "delivery_fee": 700,
        "delivery_time_min": 35,
        "lat": 43.23800,
        "lng": 76.94547,
        "image_url": "https://images.unsplash.com/photo-1513104890138-7c749659a591?w=800",
        "menu": [
            (
                "Margherita",
                "Tomato, mozzarella, basil",
                3200,
                "Pizza",
                "https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=600",
            ),
            (
                "Pepperoni",
                "Tomato, mozzarella, pepperoni",
                3800,
                "Pizza",
                "https://images.unsplash.com/photo-1628840042765-356cda07504e?w=600",
            ),
            (
                "Tiramisu",
                "Classic",
                1800,
                "Dessert",
                "https://images.unsplash.com/photo-1571877227200-a0d98ea607e9?w=600",
            ),
        ],
    },
    {
        "name": "Burger Lab",
        "cuisine": "American",
        "description": "Smash burgers, fries, shakes.",
        "rating": 4.3,
        "delivery_fee": 600,
        "delivery_time_min": 20,
        "lat": 43.21670,
        "lng": 76.88280,
        "image_url": "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=800",
        "menu": [
            (
                "Classic Smash",
                "Double patty, cheese, pickles",
                2700,
                "Burgers",
                "https://images.unsplash.com/photo-1550547660-d9450f859349?w=600",
            ),
            (
                "Fries",
                "Sea salt",
                900,
                "Sides",
                "https://images.unsplash.com/photo-1576107232684-1279f390859f?w=600",
            ),
            (
                "Vanilla Shake",
                "Real vanilla",
                1400,
                "Drinks",
                "https://images.unsplash.com/photo-1572490122747-3968b75cc699?w=600",
            ),
        ],
    },
]


def seed_catalog() -> int:
    """Insert the three demo restaurants if the catalog is empty. Returns count added."""
    with SessionLocal() as db:
        if db.scalar(select(Restaurant).limit(1)):
            return 0
        for raw in RESTAURANTS:
            data = dict(raw)
            menu = data.pop("menu")
            restaurant = Restaurant(**data, rating_count=10)
            restaurant.menu_items = [
                MenuItem(name=n, description=d, price=p, category=c, image_url=img)
                for n, d, p, c, img in menu
            ]
            db.add(restaurant)
        db.commit()
        return 3


def ensure_floor_plan_tables() -> None:
    from app.db.session import engine
    from app.models.floor_plan import Floor, FloorObject, FloorVersion, FloorZone

    for model in (Floor, FloorZone, FloorObject, FloorVersion):
        model.__table__.create(bind=engine, checkfirst=True)


# Demo dining rooms. Tables are FloorObjects — there is no separate Table entity.
_DEMO_FLOORS: dict[str, list[tuple[str, str, float, float, int]]] = {
    # restaurant name -> (table name, kind, x, y, seats)
    "Bao Bar": [
        ("T1", "table_round", 200, 200, 2),
        ("T2", "table_round", 520, 200, 2),
        ("T3", "table_square", 840, 200, 4),
        ("T4", "table_square", 200, 560, 4),
        ("T5", "table_rect", 560, 560, 6),
        ("T6", "table_large", 960, 560, 8),
    ],
    "Pizza Roma": [
        ("1", "table_square", 220, 220, 4),
        ("2", "table_square", 560, 220, 4),
        ("3", "table_rect", 900, 220, 6),
        ("4", "table_round", 220, 600, 2),
        ("5", "table_large", 620, 600, 10),
    ],
    "Burger Lab": [
        ("A", "table_round", 240, 240, 2),
        ("B", "table_round", 540, 240, 2),
        ("C", "table_square", 840, 240, 4),
        ("D", "table_rect", 380, 600, 6),
    ],
}


def ensure_demo_floor_plan() -> int:
    """Give each demo restaurant one dining room, so tables/QR/reservations have something real."""
    from app.models.floor_plan import Floor, FloorObject, FloorZone
    from app.models.restaurant import Restaurant

    ensure_floor_plan_tables()
    made = 0
    with SessionLocal() as db:
        for name, tables in _DEMO_FLOORS.items():
            restaurant = db.scalar(select(Restaurant).where(Restaurant.name == name))
            if restaurant is None:
                continue
            if db.scalar(select(Floor).where(Floor.restaurant_id == restaurant.id)):
                continue
            floor = Floor(
                restaurant_id=restaurant.id,
                name="Main hall",
                sort_order=0,
                width_cm=1400,
                height_cm=900,
                grid_cm=40,
            )
            db.add(floor)
            db.flush()
            zone = FloorZone(
                floor_id=floor.id,
                name="Hall",
                kind="hall",
                x=80,
                y=80,
                width=1240,
                height=740,
            )
            db.add(zone)
            db.flush()
            for table_name, kind, x, y, seats in tables:
                size = 120 if seats <= 2 else 160 if seats <= 4 else 220
                db.add(
                    FloorObject(
                        floor_id=floor.id,
                        zone_id=zone.id,
                        kind=kind,
                        name=table_name,
                        x=x,
                        y=y,
                        width=size,
                        height=size if kind != "table_rect" else size * 0.62,
                        capacity=seats,
                        min_guests=1,
                        max_guests=seats,
                        status="available",
                        mergeable=seats <= 4,
                    )
                )
            made += 1
        db.commit()
    return made


# Each demo venue gets a person to call. Local seed only — production restaurants
# get real owners through the staff API, not a well-known password.
_DEMO_OWNERS: dict[str, tuple[str, str, str, str]] = {
    # restaurant name -> (email, password, person, phone)
    "Bao Bar": ("owner.bao@food.dev", "owner123", "Aigerim Suleimen", "+77012345001"),
    "Pizza Roma": ("owner.roma@food.dev", "owner123", "Marco Bellini", "+77012345002"),
    "Burger Lab": ("owner.lab@food.dev", "owner123", "Daniyar Aben", "+77012345003"),
}


def ensure_demo_owners() -> int:
    """Attach an owner to each demo restaurant so the platform directory has contacts."""
    from app.models.member import RestaurantMember
    from app.models.restaurant import Restaurant

    made = 0
    for venue, (email, password, person, phone) in _DEMO_OWNERS.items():
        ensure_user(email, password, UserRole.customer, person, phone)
        with SessionLocal() as db:
            restaurant = db.scalar(select(Restaurant).where(Restaurant.name == venue))
            user = db.scalar(select(User).where(User.email == email))
            if restaurant is None or user is None:
                continue
            existing = db.scalar(
                select(RestaurantMember).where(
                    RestaurantMember.restaurant_id == restaurant.id,
                    RestaurantMember.user_id == user.id,
                )
            )
            if existing is not None:
                continue
            db.add(
                RestaurantMember(
                    restaurant_id=restaurant.id,
                    user_id=user.id,
                    role="owner",
                    is_active=True,
                )
            )
            db.commit()
            made += 1
    return made


def ensure_delivery_pricing_schema() -> None:
    """Per-km delivery columns for hosts that boot without alembic."""
    from sqlalchemy import text

    from app.db.session import engine

    wanted = (
        ("delivery_fee_per_km", "FLOAT DEFAULT 0"),
        ("delivery_free_km", "FLOAT DEFAULT 0"),
        ("delivery_max_km", "FLOAT"),
    )
    with engine.begin() as conn:
        have = {r[1] for r in conn.execute(text("PRAGMA table_info(restaurants)"))} if engine.dialect.name == "sqlite" else set()
        if engine.dialect.name != "sqlite":
            rows = conn.execute(
                text(
                    "SELECT column_name FROM information_schema.columns "
                    "WHERE table_name = 'restaurants'"
                )
            )
            have = {r[0] for r in rows}
        for name, kind in wanted:
            if name not in have:
                conn.execute(text(f"ALTER TABLE restaurants ADD COLUMN {name} {kind}"))


# Demo pricing: a base fee plus per-km past the first couple of kilometres.
_DEMO_DELIVERY_PRICING: dict[str, tuple[float, float, float]] = {
    # restaurant name -> (per_km, free_km, max_km)
    "Bao Bar": (120, 2, 15),
    "Pizza Roma": (100, 3, 20),
    "Burger Lab": (140, 1.5, 12),
}


def ensure_demo_delivery_pricing() -> int:
    """Give the demo venues a distance-based tariff so the quote is visible."""
    from app.models.restaurant import Restaurant

    ensure_delivery_pricing_schema()
    changed = 0
    with SessionLocal() as db:
        for name, (per_km, free_km, max_km) in _DEMO_DELIVERY_PRICING.items():
            restaurant = db.scalar(select(Restaurant).where(Restaurant.name == name))
            if restaurant is None or (restaurant.delivery_fee_per_km or 0) > 0:
                continue
            restaurant.delivery_fee_per_km = per_km
            restaurant.delivery_free_km = free_km
            restaurant.delivery_max_km = max_km
            changed += 1
        db.commit()
    return changed


def ensure_handover_schema() -> None:
    """Proof-of-delivery column for hosts that boot without alembic."""
    from sqlalchemy import text

    from app.db.session import engine

    with engine.begin() as conn:
        if engine.dialect.name == "sqlite":
            have = {r[1] for r in conn.execute(text("PRAGMA table_info(orders)"))}
        else:
            have = {
                r[0]
                for r in conn.execute(
                    text(
                        "SELECT column_name FROM information_schema.columns "
                        "WHERE table_name = 'orders'"
                    )
                )
            }
        if "handover_code" not in have:
            conn.execute(text("ALTER TABLE orders ADD COLUMN handover_code VARCHAR(8)"))


def ensure_courier_payout_schema() -> None:
    """Courier payout column for hosts that boot without alembic."""
    from sqlalchemy import text

    from app.db.session import engine

    with engine.begin() as conn:
        if engine.dialect.name == "sqlite":
            have = {r[1] for r in conn.execute(text("PRAGMA table_info(orders)"))}
        else:
            have = {
                r[0]
                for r in conn.execute(
                    text(
                        "SELECT column_name FROM information_schema.columns "
                        "WHERE table_name = 'orders'"
                    )
                )
            }
        if "courier_payout" not in have:
            conn.execute(
                text(
                    "ALTER TABLE orders ADD COLUMN courier_payout "
                    "DOUBLE PRECISION NOT NULL DEFAULT 0"
                    if engine.dialect.name != "sqlite"
                    else "ALTER TABLE orders ADD COLUMN courier_payout FLOAT NOT NULL DEFAULT 0"
                )
            )


def ensure_slug_schema() -> None:
    """Public-URL slug column for hosts that boot without alembic."""
    from sqlalchemy import text

    from app.db.session import engine

    with engine.begin() as conn:
        if engine.dialect.name == "sqlite":
            have = {r[1] for r in conn.execute(text("PRAGMA table_info(restaurants)"))}
        else:
            have = {
                r[0]
                for r in conn.execute(
                    text(
                        "SELECT column_name FROM information_schema.columns "
                        "WHERE table_name = 'restaurants'"
                    )
                )
            }
        if "slug" not in have:
            conn.execute(text("ALTER TABLE restaurants ADD COLUMN slug VARCHAR(80)"))
            conn.execute(
                text("CREATE UNIQUE INDEX IF NOT EXISTS ix_restaurants_slug ON restaurants (slug)")
            )


def ensure_restaurant_slugs() -> int:
    """Give every restaurant a slug. Existing ones keep theirs — a slug that has
    been crawled or shared is a promise, not a cache."""
    from app.models.restaurant import Restaurant
    from app.services.slugs import unique_slug

    filled = 0
    with SessionLocal() as db:
        for restaurant in db.scalars(select(Restaurant).where(Restaurant.slug.is_(None))):
            restaurant.slug = unique_slug(db, Restaurant, restaurant.name, skip_id=restaurant.id)
            db.flush()
            filled += 1
        if filled:
            db.commit()
    return filled


def ensure_subscription_schema() -> None:
    """Stripe Billing columns for hosts that boot without alembic."""
    from sqlalchemy import text

    from app.db.session import engine

    with engine.begin() as conn:
        if engine.dialect.name == "sqlite":
            have = {r[1] for r in conn.execute(text("PRAGMA table_info(restaurants)"))}
        else:
            have = {
                r[0]
                for r in conn.execute(
                    text(
                        "SELECT column_name FROM information_schema.columns "
                        "WHERE table_name = 'restaurants'"
                    )
                )
            }
        if "stripe_customer_id" not in have:
            conn.execute(
                text("ALTER TABLE restaurants ADD COLUMN stripe_customer_id VARCHAR(80)")
            )
        if "stripe_subscription_id" not in have:
            conn.execute(
                text("ALTER TABLE restaurants ADD COLUMN stripe_subscription_id VARCHAR(80)")
            )
        if "plan_renews_at" not in have:
            conn.execute(text("ALTER TABLE restaurants ADD COLUMN plan_renews_at TIMESTAMP"))


def ensure_offer_schema() -> None:
    """Campaign table for hosts that boot without alembic."""
    from app.db.session import engine
    from app.models.offer import Offer

    Offer.__table__.create(bind=engine, checkfirst=True)


_DEMO_OFFERS = [
    (
        "Bao Bar",
        "dvoinaya-porciya",
        "Двойная порция",
        "По цене одной, по будням до 16:00",
        (
            "Берите любое блюдо из раздела «Ramen» и получайте вторую порцию "
            "бесплатно. Работает на доставку и самовывоз в будние дни до 16:00."
        ),
        "https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=800",
        None,
    ),
    (
        "Pizza Roma",
        "pizza-500",
        "−500 ₸ на пиццу",
        "По промокоду при заказе от 3000 ₸",
        "Скидка применяется в корзине. Не суммируется с другими акциями.",
        "https://images.unsplash.com/photo-1513104890138-7c749659a591?w=800",
        "PIZZA500",
    ),
    (
        None,
        "besplatnaya-dostavka",
        "Бесплатная доставка",
        "Первый заказ в любом ресторане",
        "Доставка бесплатна для первого заказа, если адрес попадает в радиус ресторана.",
        "https://images.unsplash.com/photo-1526367790999-0150786686a2?w=800",
        None,
    ),
]


def ensure_demo_offers() -> int:
    """Give the site something real to show on /actions/."""
    from app.models.offer import Offer
    from app.models.restaurant import Restaurant

    ensure_offer_schema()
    made = 0
    with SessionLocal() as db:
        for name, slug, title, subtitle, body, image, code in _DEMO_OFFERS:
            if db.scalar(select(Offer).where(Offer.slug == slug)):
                continue
            restaurant_id = None
            if name is not None:
                restaurant = db.scalar(select(Restaurant).where(Restaurant.name == name))
                if restaurant is None:
                    continue
                restaurant_id = restaurant.id
            db.add(
                Offer(
                    restaurant_id=restaurant_id,
                    slug=slug,
                    title=title,
                    subtitle=subtitle,
                    body=body,
                    image_url=image,
                    promo_code=code,
                    is_active=True,
                    sort_order=made,
                )
            )
            made += 1
        if made:
            db.commit()
    return made


def ensure_guest_schema() -> None:
    """Guest flag on users for hosts that boot without alembic."""
    from sqlalchemy import text

    from app.db.session import engine

    with engine.begin() as conn:
        if engine.dialect.name == "sqlite":
            have = {r[1] for r in conn.execute(text("PRAGMA table_info(users)"))}
        else:
            have = {
                r[0]
                for r in conn.execute(
                    text(
                        "SELECT column_name FROM information_schema.columns "
                        "WHERE table_name = 'users'"
                    )
                )
            }
        if "is_guest" not in have:
            conn.execute(
                text(
                    "ALTER TABLE users ADD COLUMN is_guest BOOLEAN NOT NULL DEFAULT FALSE"
                    if engine.dialect.name != "sqlite"
                    else "ALTER TABLE users ADD COLUMN is_guest BOOLEAN NOT NULL DEFAULT 0"
                )
            )


def ensure_capacity_schema() -> None:
    """Kitchen cap column for hosts that boot without alembic."""
    from sqlalchemy import text

    from app.db.session import engine

    with engine.begin() as conn:
        if engine.dialect.name == "sqlite":
            have = {r[1] for r in conn.execute(text("PRAGMA table_info(restaurants)"))}
        else:
            have = {
                r[0]
                for r in conn.execute(
                    text(
                        "SELECT column_name FROM information_schema.columns "
                        "WHERE table_name = 'restaurants'"
                    )
                )
            }
        if "max_active_orders" not in have:
            conn.execute(text("ALTER TABLE restaurants ADD COLUMN max_active_orders INTEGER"))


def ensure_favorites_table() -> None:
    """Prod deploys skip alembic; create the favorites table if missing."""
    from app.db.session import engine
    from app.models.favorite import Favorite

    Favorite.__table__.create(bind=engine, checkfirst=True)


def ensure_saas_schema() -> None:
    """Prod deploys skip alembic; add tenant columns/tables if the DB predates them."""
    from sqlalchemy import inspect, text

    from app.db.session import engine
    from app.models.audit import AuditLog
    from app.models.feature_flag import FeatureOverride
    from app.models.idempotency import IdempotencyRecord
    from app.models.member import RestaurantMember

    for model in (RestaurantMember, FeatureOverride, AuditLog, IdempotencyRecord):
        model.__table__.create(bind=engine, checkfirst=True)

    insp = inspect(engine)
    dialect = engine.dialect.name

    def _add(table: str, name: str, typ: str) -> None:
        if table not in insp.get_table_names():
            return
        existing = {c["name"] for c in insp.get_columns(table)}
        if name in existing:
            return
        with engine.begin() as conn:
            if dialect == "postgresql":
                conn.execute(text(f"ALTER TABLE {table} ADD COLUMN IF NOT EXISTS {name} {typ}"))
            else:
                conn.execute(text(f"ALTER TABLE {table} ADD COLUMN {name} {typ}"))

    _add("restaurants", "plan_code", "VARCHAR(20) DEFAULT 'pro'")
    _add("restaurants", "billing_status", "VARCHAR(20) DEFAULT 'active'")
    _add("orders", "channel", "VARCHAR(20) DEFAULT 'delivery'")
    _add("orders", "table_object_id", "INTEGER")
    if dialect == "postgresql":
        with engine.begin() as conn:
            conn.execute(
                text(
                    "UPDATE restaurants SET plan_code = 'pro' WHERE plan_code IS NULL OR plan_code = ''"
                )
            )
            conn.execute(
                text(
                    "UPDATE restaurants SET billing_status = 'active' "
                    "WHERE billing_status IS NULL OR billing_status = ''"
                )
            )
            conn.execute(
                text("UPDATE orders SET channel = 'delivery' WHERE channel IS NULL OR channel = ''")
            )


def ensure_address_columns() -> None:
    """Prod deploys skip alembic; add KZ address fields if the table predates them."""
    from sqlalchemy import inspect, text

    from app.db.session import engine

    insp = inspect(engine)
    if "addresses" not in insp.get_table_names():
        return
    existing = {c["name"] for c in insp.get_columns("addresses")}
    extras = (
        ("apt", "VARCHAR(40)"),
        ("entrance", "VARCHAR(40)"),
        ("floor", "VARCHAR(20)"),
        ("intercom", "VARCHAR(40)"),
    )
    missing = [(name, typ) for name, typ in extras if name not in existing]
    if not missing:
        return
    dialect = engine.dialect.name
    with engine.begin() as conn:
        for name, typ in missing:
            if dialect == "postgresql":
                conn.execute(text(f"ALTER TABLE addresses ADD COLUMN IF NOT EXISTS {name} {typ}"))
            else:
                conn.execute(text(f"ALTER TABLE addresses ADD COLUMN {name} {typ}"))


COORDS = {
    "Bao Bar": (43.25654, 76.92812),
    "Pizza Roma": (43.23800, 76.94547),
    "Burger Lab": (43.21670, 76.88280),
}


def ensure_geo_schema() -> None:
    """Prod deploys skip alembic; pin restaurants and orders to the map."""
    from sqlalchemy import inspect, text

    from app.db.session import engine

    insp = inspect(engine)
    dialect = engine.dialect.name

    def _add(table: str, name: str, typ: str) -> None:
        if table not in insp.get_table_names():
            return
        existing = {c["name"] for c in insp.get_columns(table)}
        if name in existing:
            return
        with engine.begin() as conn:
            if dialect == "postgresql":
                conn.execute(text(f"ALTER TABLE {table} ADD COLUMN IF NOT EXISTS {name} {typ}"))
            else:
                conn.execute(text(f"ALTER TABLE {table} ADD COLUMN {name} {typ}"))

    _add("restaurants", "lat", "FLOAT")
    _add("restaurants", "lng", "FLOAT")
    _add("addresses", "lat", "FLOAT")
    _add("addresses", "lng", "FLOAT")
    _add("orders", "dest_lat", "FLOAT")
    _add("orders", "dest_lng", "FLOAT")
    _add("orders", "pickup_lat", "FLOAT")
    _add("orders", "pickup_lng", "FLOAT")
    _add("users", "last_lat", "FLOAT")
    _add("users", "last_lng", "FLOAT")
    _add("users", "last_heading", "FLOAT")
    _add("users", "last_seen_at", "TIMESTAMP")


def ensure_restaurant_coords() -> int:
    """Backfill demo venue pins if a catalog row was seeded without them."""
    updated = 0
    with SessionLocal() as db:
        for r in db.scalars(select(Restaurant)).all():
            pin = COORDS.get(r.name)
            if not pin or r.lat is not None:
                continue
            r.lat, r.lng = pin
            updated += 1
        if updated:
            db.commit()
    return updated


def ensure_menu_images() -> int:
    """Backfill dish photos on existing demo rows that were seeded without them."""
    wanted = {(r["name"], n): img for r in RESTAURANTS for n, _d, _p, _c, img in r["menu"]}
    updated = 0
    with SessionLocal() as db:
        for item in db.scalars(select(MenuItem)).all():
            if item.image_url:
                continue
            url = wanted.get((item.restaurant.name, item.name))
            if not url:
                continue
            item.image_url = url
            updated += 1
        if updated:
            db.commit()
    return updated


DEMO_MODIFIERS = {
    "Pork Bao": [
        (
            "Size",
            True,
            1,
            1,
            [("Regular", 0, True), ("Large", 400, False)],
        ),
        (
            "Extras",
            False,
            0,
            3,
            [("Egg", 200, False), ("Chili oil", 100, False)],
        ),
    ],
    "Margherita": [
        (
            "Size",
            True,
            1,
            1,
            [("30 cm", 0, True), ("40 cm", 800, False)],
        ),
        (
            "Add-ons",
            False,
            0,
            2,
            [("Extra cheese", 300, False)],
        ),
    ],
    "Classic Smash": [
        (
            "Add-ons",
            False,
            0,
            3,
            [("Bacon", 400, False), ("Extra patty", 700, False)],
        ),
    ],
}


def ensure_checkout_schema() -> None:
    """Prod deploys skip alembic; modifiers, cash fields, device tokens."""
    from sqlalchemy import inspect, text

    from app.db.session import engine
    from app.models.device import DeviceToken
    from app.models.restaurant import ModifierGroup, ModifierOption

    for model in (ModifierGroup, ModifierOption, DeviceToken):
        model.__table__.create(bind=engine, checkfirst=True)

    insp = inspect(engine)
    dialect = engine.dialect.name

    def _add(table: str, name: str, typ: str) -> None:
        if table not in insp.get_table_names():
            return
        existing = {c["name"] for c in insp.get_columns(table)}
        if name in existing:
            return
        with engine.begin() as conn:
            if dialect == "postgresql":
                conn.execute(text(f"ALTER TABLE {table} ADD COLUMN IF NOT EXISTS {name} {typ}"))
            else:
                conn.execute(text(f"ALTER TABLE {table} ADD COLUMN {name} {typ}"))

    json_typ = "JSONB DEFAULT '[]'::jsonb" if dialect == "postgresql" else "JSON DEFAULT '[]'"
    _add("order_items", "modifiers", json_typ)
    _add("orders", "pay_method", "VARCHAR(20) DEFAULT 'cash'")
    _add("orders", "pay_status", "VARCHAR(20) DEFAULT 'unpaid'")
    _add("orders", "pay_ref", "VARCHAR(120)")
    _add("orders", "checkout_url", "VARCHAR(500)")


def ensure_offers_schema() -> None:
    """Prod deploys skip alembic; schedule + promo columns."""
    from sqlalchemy import inspect, text

    from app.db.session import engine
    from app.models.promo import Promo

    Promo.__table__.create(bind=engine, checkfirst=True)
    insp = inspect(engine)
    dialect = engine.dialect.name

    def _add(table: str, name: str, typ: str) -> None:
        if table not in insp.get_table_names():
            return
        existing = {c["name"] for c in insp.get_columns(table)}
        if name in existing:
            return
        with engine.begin() as conn:
            if dialect == "postgresql":
                conn.execute(text(f"ALTER TABLE {table} ADD COLUMN IF NOT EXISTS {name} {typ}"))
            else:
                conn.execute(text(f"ALTER TABLE {table} ADD COLUMN {name} {typ}"))

    _add("orders", "scheduled_for", "TIMESTAMP")
    _add("orders", "promo_code", "VARCHAR(24)")
    _add("orders", "discount", "FLOAT DEFAULT 0")


def ensure_chat_schema() -> None:
    """Prod deploys skip alembic; order thread."""
    from app.db.session import engine
    from app.models.message import OrderMessage

    OrderMessage.__table__.create(bind=engine, checkfirst=True)


def ensure_reservations_schema() -> None:
    """Prod deploys skip alembic; table bookings."""
    from app.db.session import engine
    from app.models.reservation import Reservation

    Reservation.__table__.create(bind=engine, checkfirst=True)


DEMO_PROMOS = (
    ("Bao Bar", "BAO10", "percent", 10, 2000),
    ("Pizza Roma", "PIZZA500", "amount", 500, 3000),
    ("Burger Lab", "SMASH500", "amount", 500, 2500),
)


def ensure_demo_promos() -> int:
    from app.models.promo import Promo

    added = 0
    with SessionLocal() as db:
        for name, code, kind, value, minimum in DEMO_PROMOS:
            restaurant = db.scalar(select(Restaurant).where(Restaurant.name == name))
            if restaurant is None:
                continue
            if db.scalar(
                select(Promo).where(Promo.restaurant_id == restaurant.id, Promo.code == code)
            ):
                continue
            db.add(
                Promo(
                    restaurant_id=restaurant.id,
                    code=code,
                    kind=kind,
                    value=value,
                    min_subtotal=minimum,
                )
            )
            added += 1
        if added:
            db.commit()
    return added


def ensure_demo_modifiers() -> int:
    """Attach size/extras to the demo dishes once."""
    added = 0
    with SessionLocal() as db:
        for item in db.scalars(select(MenuItem)).all():
            spec = DEMO_MODIFIERS.get(item.name)
            if not spec or item.modifier_groups:
                continue
            for name, required, mn, mx, options in spec:
                group = ModifierGroup(
                    menu_item_id=item.id,
                    name=name,
                    required=required,
                    min_select=mn,
                    max_select=mx,
                )
                group.options = [
                    ModifierOption(name=n, price_delta=p, is_default=d) for n, p, d in options
                ]
                db.add(group)
                added += 1
        if added:
            db.commit()
    return added


def ensure_user(
    email: str, password: str, role: UserRole, name: str, phone: str | None = None
) -> bool:
    """Create a user if that email does not exist. Returns True if created."""
    with SessionLocal() as db:
        if db.scalar(select(User).where(User.email == email)):
            return False
        db.add(
            User(
                email=email,
                name=name,
                phone=phone,
                hashed_password=hash_password(password),
                role=role,
            )
        )
        db.commit()
        return True


def ensure_admin(email: str, password: str, name: str = "Admin") -> bool:
    return ensure_user(email, password, UserRole.admin, name)


def seed_demo_users() -> None:
    with SessionLocal() as db:
        if db.scalar(select(User).limit(1)):
            return
        db.add(
            User(
                email="admin@food.dev",
                name="Admin",
                hashed_password=hash_password("admin123"),
                role=UserRole.admin,
            )
        )
        db.add(
            User(
                email="courier@food.dev",
                name="Courier Bek",
                phone="+77007654321",
                hashed_password=hash_password("courier123"),
                role=UserRole.courier,
            )
        )
        db.add(
            User(
                email="user@food.dev",
                name="Test User",
                phone="+77001234567",
                hashed_password=hash_password("user123"),
            )
        )
        db.commit()


def disable_known_demo_accounts() -> list[str]:
    """Scramble passwords for the well-known local demo emails if they exist in this DB."""
    changed: list[str] = []
    with SessionLocal() as db:
        for email in ("admin@food.dev", "courier@food.dev", "user@food.dev"):
            user = db.scalar(select(User).where(User.email == email))
            if user is None:
                continue
            user.hashed_password = hash_password(secrets.token_urlsafe(24))
            changed.append(email)
        if changed:
            db.commit()
    return changed


def seed() -> None:
    """Local/dev: catalog + demo accounts with well-known passwords."""
    seed_demo_users()
    added = seed_catalog()
    ensure_menu_images()
    ensure_restaurant_coords()
    ensure_checkout_schema()
    ensure_demo_modifiers()
    ensure_offers_schema()
    ensure_demo_promos()
    ensure_chat_schema()
    ensure_capacity_schema()
    ensure_handover_schema()
    ensure_reservations_schema()
    floors = ensure_demo_floor_plan()
    if floors:
        print(f"Floor plans: seeded {floors}")
    owners = ensure_demo_owners()
    if owners:
        print(f"Restaurant owners: linked {owners}")
    tariffs = ensure_demo_delivery_pricing()
    if tariffs:
        print(f"Delivery tariffs: set {tariffs}")
    ensure_slug_schema()
    ensure_subscription_schema()
    ensure_offer_schema()
    ensure_guest_schema()
    campaigns = ensure_demo_offers()
    if campaigns:
        print(f"Campaigns: seeded {campaigns}")
    slugs = ensure_restaurant_slugs()
    if slugs:
        print(f"Public slugs: filled {slugs}")
    print("Already seeded" if added == 0 else "Seeded: 3 users, 3 restaurants, 9 menu items")


if __name__ == "__main__":
    import argparse
    import os

    from app.core.config import settings

    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog-only", action="store_true", help="restaurants, no demo users")
    parser.add_argument(
        "--admin-email", default=os.environ.get("ADMIN_EMAIL", "admin@food.delivery")
    )
    args = parser.parse_args()

    if args.catalog_only or settings.is_prod:
        n = seed_catalog()
        photos = ensure_menu_images()
        ensure_checkout_schema()
        ensure_demo_modifiers()
        ensure_offers_schema()
        ensure_demo_promos()
        ensure_chat_schema()
        ensure_capacity_schema()
        ensure_handover_schema()
        ensure_reservations_schema()
        floors = ensure_demo_floor_plan()
        ensure_delivery_pricing_schema()
        print(f"Catalog: {'seeded' if n else 'already present'}")
        if floors:
            print(f"Floor plans: seeded {floors}")
        if photos:
            print(f"Menu photos: backfilled {photos}")
        killed = disable_known_demo_accounts()
        if killed:
            print("Disabled local demo logins:", ", ".join(killed))
        accounts = [
            (args.admin_email, UserRole.admin, "Admin", None),
            ("courier@food.delivery", UserRole.courier, "Courier Bek", "+77007654321"),
            ("user@food.delivery", UserRole.customer, "Demo User", "+77001234567"),
        ]
        print("Accounts:")
        for email, role, name, phone in accounts:
            password = secrets.token_urlsafe(18)
            if ensure_user(email, password, role, name, phone):
                print(f"  {role.value:9}  {email}  {password}")
            else:
                print(f"  {role.value:9}  {email}  (already exists, password unchanged)")
    else:
        seed()
