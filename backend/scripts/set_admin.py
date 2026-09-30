"""Create the platform admin, or reset its password, on any database.

    cd backend && uv run python scripts/set_admin.py

Asks for the database URL, the email and the password with hidden input, so
none of them lands in shell history or on screen. Prints only the email.
"""

import getpass
import os
import sys


def main() -> int:
    url = os.environ.get("DATABASE_URL") or getpass.getpass("DATABASE_URL (Neon, hidden): ").strip()
    if not url:
        print("No database URL given.")
        return 1
    os.environ["DATABASE_URL"] = url  # before app.* reads settings

    sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
    from app.db.seed import set_platform_admin

    email = input("Admin email [admin@food.delivery]: ").strip() or "admin@food.delivery"
    password = getpass.getpass("New password (10+ chars, hidden): ")
    if password != getpass.getpass("Repeat it: "):
        print("Passwords differ; nothing changed.")
        return 1
    try:
        outcome = set_platform_admin(email, password)
    except ValueError as exc:
        print(exc)
        return 1
    print(f"Platform admin {outcome}: {email}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
