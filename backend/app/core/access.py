"""Restaurant-scoped permissions. Platform admin (`UserRole.admin`) bypasses membership.

Never trust a client-supplied role or restaurant_id — look the membership up.
"""

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import Restaurant, User, UserRole
from app.models.member import STAFF_ROLES, RestaurantMember

PERMISSIONS = frozenset(
    {
        "menu.read",
        "menu.write",
        "orders.read",
        "orders.manage",
        "tables.read",
        "tables.write",
        "analytics.read",
        "staff.read",
        "staff.write",
        "billing.read",
        "billing.manage",
        "restaurant.settings.write",
    }
)

_ALL = PERMISSIONS

# Restaurant staff roles. Platform SUPER_ADMIN is UserRole.admin, not a membership.
ROLE_PERMS: dict[str, frozenset[str]] = {
    "owner": _ALL,
    "admin": _ALL - {"billing.manage"},
    "manager": frozenset(
        {
            "menu.read",
            "menu.write",
            "orders.read",
            "orders.manage",
            "tables.read",
            "tables.write",
            "analytics.read",
            "staff.read",
            "restaurant.settings.write",
        }
    ),
    "cashier": frozenset({"orders.read", "orders.manage", "tables.read", "menu.read"}),
    "waiter": frozenset({"orders.read", "orders.manage", "tables.read", "tables.write", "menu.read"}),
    "kitchen": frozenset({"orders.read", "orders.manage", "menu.read"}),
    "delivery_manager": frozenset({"orders.read", "orders.manage", "analytics.read"}),
    "delivery_courier": frozenset({"orders.read"}),
    "accountant": frozenset({"analytics.read", "billing.read", "orders.read"}),
}


def permissions_for(role: str) -> frozenset[str]:
    return ROLE_PERMS.get(role, frozenset())


def has_permission(role: str, permission: str) -> bool:
    return permission in permissions_for(role)


def require_restaurant(db: Session, user: User, restaurant_id: int, permission: str) -> Restaurant:
    restaurant = db.get(Restaurant, restaurant_id)
    if not restaurant:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Restaurant not found")
    if user.role == UserRole.admin:
        return restaurant
    member = db.scalar(
        select(RestaurantMember).where(
            RestaurantMember.user_id == user.id,
            RestaurantMember.restaurant_id == restaurant_id,
            RestaurantMember.is_active.is_(True),
        )
    )
    if not member:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Not a member of this restaurant")
    if permission not in permissions_for(member.role):
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Missing permission")
    return restaurant


def membership(db: Session, user_id: int, restaurant_id: int) -> RestaurantMember | None:
    return db.scalar(
        select(RestaurantMember).where(
            RestaurantMember.user_id == user_id,
            RestaurantMember.restaurant_id == restaurant_id,
        )
    )


def valid_staff_role(role: str) -> bool:
    return role in STAFF_ROLES
