"""cities: Kazakh names for the /kk/ site

Revision ID: f8a0b2c4d6e9
Revises: e7f9a1b3c5d8
Create Date: 2026-09-30 21:00:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "f8a0b2c4d6e9"
down_revision: Union[str, Sequence[str], None] = "e7f9a1b3c5d8"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

_COLUMNS = [
    sa.Column("name_kk", sa.String(length=80), nullable=True),
    sa.Column("name_in_kk", sa.String(length=80), nullable=True),
]


def _has_column(table: str, column: str) -> bool:
    insp = sa.inspect(op.get_bind())
    return insp.has_table(table) and column in {c["name"] for c in insp.get_columns(table)}


def upgrade() -> None:
    # ensure_hours_loyalty_schema() adds them at boot on hosts without alembic.
    for column in _COLUMNS:
        if not _has_column("cities", column.name):
            with op.batch_alter_table("cities") as batch:
                batch.add_column(column)


def downgrade() -> None:
    for column in reversed(_COLUMNS):
        if _has_column("cities", column.name):
            with op.batch_alter_table("cities") as batch:
                batch.drop_column(column.name)
