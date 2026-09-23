"""proof of delivery handover code

Revision ID: b8d1f4a6c9e3
Revises: a7c9e1d3b5f2
Create Date: 2026-09-23 05:10:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "b8d1f4a6c9e3"
down_revision: str | Sequence[str] | None = "a7c9e1d3b5f2"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def _has_column(table: str, column: str) -> bool:
    inspector = sa.inspect(op.get_bind())
    if not inspector.has_table(table):
        return False
    return column in {c["name"] for c in inspector.get_columns(table)}


def upgrade() -> None:
    # ensure_handover_schema() adds this at boot on hosts without alembic.
    if not _has_column("orders", "handover_code"):
        op.add_column("orders", sa.Column("handover_code", sa.String(length=8), nullable=True))


def downgrade() -> None:
    if _has_column("orders", "handover_code"):
        op.drop_column("orders", "handover_code")
