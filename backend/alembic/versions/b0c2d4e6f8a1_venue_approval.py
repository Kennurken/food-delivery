"""venue applications: approval state and delivery choice

Revision ID: b0c2d4e6f8a1
Revises: a9b1c3d5e7f0
Create Date: 2026-10-01 12:00:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "b0c2d4e6f8a1"
down_revision: Union[str, Sequence[str], None] = "a9b1c3d5e7f0"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

# Existing venues are approved and deliver: nothing changes for them.
_COLUMNS = [
    sa.Column("approval", sa.String(length=12), nullable=False, server_default="approved"),
    sa.Column("offers_delivery", sa.Boolean(), nullable=False, server_default=sa.true()),
    sa.Column("applied_at", sa.DateTime(), nullable=True),
    sa.Column("rejection_reason", sa.String(length=300), nullable=True),
]


def _has_column(table: str, column: str) -> bool:
    insp = sa.inspect(op.get_bind())
    return insp.has_table(table) and column in {c["name"] for c in insp.get_columns(table)}


def upgrade() -> None:
    # ensure_hours_loyalty_schema() adds them at boot on hosts without alembic.
    for column in _COLUMNS:
        if not _has_column("restaurants", column.name):
            with op.batch_alter_table("restaurants") as batch:
                batch.add_column(column)


def downgrade() -> None:
    for column in reversed(_COLUMNS):
        if _has_column("restaurants", column.name):
            with op.batch_alter_table("restaurants") as batch:
                batch.drop_column(column.name)
