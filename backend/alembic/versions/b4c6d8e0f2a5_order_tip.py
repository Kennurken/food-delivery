"""courier tip on orders

Revision ID: b4c6d8e0f2a5
Revises: a3b5c7d9e1f4
Create Date: 2026-09-30 15:00:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "b4c6d8e0f2a5"
down_revision: Union[str, Sequence[str], None] = "a3b5c7d9e1f4"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _has_column(table: str, column: str) -> bool:
    insp = sa.inspect(op.get_bind())
    return insp.has_table(table) and column in {c["name"] for c in insp.get_columns(table)}


def upgrade() -> None:
    # ensure_hours_loyalty_schema() adds it at boot on hosts without alembic.
    if not _has_column("orders", "tip"):
        with op.batch_alter_table("orders") as batch:
            batch.add_column(sa.Column("tip", sa.Float(), nullable=False, server_default="0"))


def downgrade() -> None:
    if _has_column("orders", "tip"):
        with op.batch_alter_table("orders") as batch:
            batch.drop_column("tip")
