"""Seed dev database. Run after `alembic upgrade head`: uv run python -m app.db.seed"""

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
            ("Pork Bao", "Steamed bun, pork belly, hoisin", 1500, "Buns"),
            ("Tonkotsu Ramen", "Rich pork broth, egg, chashu", 2900, "Ramen"),
            ("Pad Thai", "Rice noodles, shrimp, peanuts", 2600, "Wok"),
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
            ("Margherita", "Tomato, mozzarella, basil", 3200, "Pizza"),
            ("Pepperoni", "Tomato, mozzarella, pepperoni", 3800, "Pizza"),
            ("Tiramisu", "Classic", 1800, "Dessert"),
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
            ("Classic Smash", "Double patty, cheese, pickles", 2700, "Burgers"),
            ("Fries", "Sea salt", 900, "Sides"),
            ("Vanilla Shake", "Real vanilla", 1400, "Drinks"),
        ],
    },
]


def seed() -> None:
    with SessionLocal() as db:
        if db.scalar(select(Restaurant).limit(1)):
            print("Already seeded")
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

        for r in RESTAURANTS:
            menu = r.pop("menu")
            restaurant = Restaurant(**r)
            restaurant.menu_items = [
                MenuItem(name=n, description=d, price=p, category=c) for n, d, p, c in menu
            ]
            db.add(restaurant)

        db.commit()
        print("Seeded: 3 users, 3 restaurants, 9 menu items")


if __name__ == "__main__":
    seed()
