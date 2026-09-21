"""Seed catalog (and optional demo users). Run after `alembic upgrade head`."""

from __future__ import annotations

import secrets

from sqlalchemy import select

import app.models  # noqa: F401
from app.core.security import hash_password
from app.db.session import SessionLocal
from app.models import MenuItem, Restaurant, User, UserRole

RESTAURANTS = [
    {
        "name": "Bao Bar",
        "cuisine": "Asian",
        "description": "Steamed buns, ramen, wok.",
        "rating": 4.7,
        "delivery_fee": 500,
        "delivery_time_min": 25,
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


def ensure_user(email: str, password: str, role: UserRole, name: str, phone: str | None = None) -> bool:
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
    print("Already seeded" if added == 0 else "Seeded: 3 users, 3 restaurants, 9 menu items")


if __name__ == "__main__":
    import argparse
    import os

    from app.core.config import settings

    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog-only", action="store_true", help="restaurants, no demo users")
    parser.add_argument("--admin-email", default=os.environ.get("ADMIN_EMAIL", "admin@food.delivery"))
    args = parser.parse_args()

    if args.catalog_only or settings.is_prod:
        n = seed_catalog()
        photos = ensure_menu_images()
        print(f"Catalog: {'seeded' if n else 'already present'}")
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
