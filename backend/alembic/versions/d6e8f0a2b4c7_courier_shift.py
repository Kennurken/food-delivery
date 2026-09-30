"""courier on/off the line

Revision ID: d6e8f0a2b4c7
Revises: c5d7e9f1a3b6
Create Date: 2026-09-30 18:00:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "d6e8f0a2b4c7"
down_revision: Union[str, Sequence[str], None] = "c5d7e9f1a3b6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _has_column(table: str, column: str) -> bool:
    insp = sa.inspect(op.get_bind())
    return insp.has_table(table) and column in {c["name"] for c in insp.get_columns(table)}


def upgrade() -> None:
    # Existing couriers start on the line, so nothing changes until they choose.
    # ensure_hours_loyalty_schema() adds it at boot on hosts without alembic.
    if not _has_column("users", "on_shift"):
        with op.batch_alter_table("users") as batch:
            batch.add_column(
                sa.Column("on_shift", sa.Boolean(), nullable=False, server_default=sa.true())
            )


def downgrade() -> None:
    if _has_column("users", "on_shift"):
        with op.batch_alter_table("users") as batch:
            batch.drop_column("on_shift")
