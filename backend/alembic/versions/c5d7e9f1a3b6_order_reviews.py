"""written reviews and venue replies on orders

Revision ID: c5d7e9f1a3b6
Revises: b4c6d8e0f2a5
Create Date: 2026-09-30 16:00:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "c5d7e9f1a3b6"
down_revision: Union[str, Sequence[str], None] = "b4c6d8e0f2a5"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

_COLUMNS = [
    sa.Column("review", sa.String(length=1000), nullable=True),
    sa.Column("review_reply", sa.String(length=1000), nullable=True),
    sa.Column("reviewed_at", sa.DateTime(), nullable=True),
]


def _has_column(table: str, column: str) -> bool:
    insp = sa.inspect(op.get_bind())
    return insp.has_table(table) and column in {c["name"] for c in insp.get_columns(table)}


def upgrade() -> None:
    # ensure_hours_loyalty_schema() adds them at boot on hosts without alembic.
    for column in _COLUMNS:
        if not _has_column("orders", column.name):
            with op.batch_alter_table("orders") as batch:
                batch.add_column(column)


def downgrade() -> None:
    for column in reversed(_COLUMNS):
        if _has_column("orders", column.name):
            with op.batch_alter_table("orders") as batch:
                batch.drop_column(column.name)
