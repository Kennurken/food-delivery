"""delivery pricing per km

Revision ID: a7c9e1d3b5f2
Revises: f6b8c0d2e4a1
Create Date: 2026-09-23 04:10:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "a7c9e1d3b5f2"
down_revision: str | Sequence[str] | None = "f6b8c0d2e4a1"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

# (name, type, server_default, nullable) — the two tariff numbers always have a
# value; the radius is genuinely optional, so it stays nullable.
_COLUMNS = (
    ("delivery_fee_per_km", sa.Float(), "0", False),
    ("delivery_free_km", sa.Float(), "0", False),
    ("delivery_max_km", sa.Float(), None, True),
)


def _has_column(table: str, column: str) -> bool:
    inspector = sa.inspect(op.get_bind())
    if not inspector.has_table(table):
        return False
    return column in {c["name"] for c in inspector.get_columns(table)}


def upgrade() -> None:
    # ensure_delivery_pricing_schema() adds these at boot on hosts without alembic.
    for name, kind, default, nullable in _COLUMNS:
        if _has_column("restaurants", name):
            continue
        op.add_column(
            "restaurants",
            sa.Column(name, kind, nullable=nullable, server_default=default),
        )


def downgrade() -> None:
    for name, _kind, _default, _nullable in reversed(_COLUMNS):
        if _has_column("restaurants", name):
            op.drop_column("restaurants", name)
