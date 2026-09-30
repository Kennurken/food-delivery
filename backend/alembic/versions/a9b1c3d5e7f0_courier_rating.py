"""a diner's rating of the courier

Revision ID: a9b1c3d5e7f0
Revises: f8a0b2c4d6e9
Create Date: 2026-10-01 09:00:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "a9b1c3d5e7f0"
down_revision: Union[str, Sequence[str], None] = "f8a0b2c4d6e9"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _has_column(table: str, column: str) -> bool:
    insp = sa.inspect(op.get_bind())
    return insp.has_table(table) and column in {c["name"] for c in insp.get_columns(table)}


def upgrade() -> None:
    # ensure_hours_loyalty_schema() adds it at boot on hosts without alembic.
    if not _has_column("orders", "courier_rating"):
        with op.batch_alter_table("orders") as batch:
            batch.add_column(sa.Column("courier_rating", sa.Integer(), nullable=True))


def downgrade() -> None:
    if _has_column("orders", "courier_rating"):
        with op.batch_alter_table("orders") as batch:
            batch.drop_column("courier_rating")
