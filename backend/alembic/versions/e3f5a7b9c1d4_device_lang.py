"""device tokens: the app's language, for push texts

Revision ID: e3f5a7b9c1d4
Revises: d2e4f6a8b0c3
Create Date: 2026-10-01 12:00:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "e3f5a7b9c1d4"
down_revision: Union[str, Sequence[str], None] = "d2e4f6a8b0c3"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _has_column(table: str, column: str) -> bool:
    insp = sa.inspect(op.get_bind())
    return insp.has_table(table) and column in {c["name"] for c in insp.get_columns(table)}


def upgrade() -> None:
    # ensure_hours_loyalty_schema() adds it at boot on hosts without alembic.
    if not _has_column("device_tokens", "lang"):
        with op.batch_alter_table("device_tokens") as batch:
            batch.add_column(sa.Column("lang", sa.String(length=5), nullable=True))


def downgrade() -> None:
    if _has_column("device_tokens", "lang"):
        with op.batch_alter_table("device_tokens") as batch:
            batch.drop_column("lang")
