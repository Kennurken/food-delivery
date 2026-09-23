"""kitchen capacity cap

Revision ID: c9e2a5b7d1f4
Revises: b8d1f4a6c9e3
Create Date: 2026-09-23 06:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "c9e2a5b7d1f4"
down_revision: str | Sequence[str] | None = "b8d1f4a6c9e3"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def _has_column(table: str, column: str) -> bool:
    inspector = sa.inspect(op.get_bind())
    if not inspector.has_table(table):
        return False
    return column in {c["name"] for c in inspector.get_columns(table)}


def upgrade() -> None:
    # ensure_capacity_schema() adds this at boot on hosts without alembic.
    if not _has_column("restaurants", "max_active_orders"):
        op.add_column(
            "restaurants", sa.Column("max_active_orders", sa.Integer(), nullable=True)
        )


def downgrade() -> None:
    if _has_column("restaurants", "max_active_orders"):
        op.drop_column("restaurants", "max_active_orders")
