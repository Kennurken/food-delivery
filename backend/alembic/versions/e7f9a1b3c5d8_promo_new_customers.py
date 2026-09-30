"""welcome promos: new customers only

Revision ID: e7f9a1b3c5d8
Revises: d6e8f0a2b4c7
Create Date: 2026-09-30 19:00:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "e7f9a1b3c5d8"
down_revision: Union[str, Sequence[str], None] = "d6e8f0a2b4c7"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _has_column(table: str, column: str) -> bool:
    insp = sa.inspect(op.get_bind())
    return insp.has_table(table) and column in {c["name"] for c in insp.get_columns(table)}


def upgrade() -> None:
    # ensure_hours_loyalty_schema() adds it at boot on hosts without alembic.
    if not _has_column("promos", "new_customers_only"):
        with op.batch_alter_table("promos") as batch:
            batch.add_column(
                sa.Column(
                    "new_customers_only", sa.Boolean(), nullable=False, server_default=sa.false()
                )
            )


def downgrade() -> None:
    if _has_column("promos", "new_customers_only"):
        with op.batch_alter_table("promos") as batch:
            batch.drop_column("new_customers_only")
