"""order chat: escalation messages

Revision ID: c1d3e5f7a9b2
Revises: b0c2d4e6f8a1
Create Date: 2026-10-02 12:00:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "c1d3e5f7a9b2"
down_revision: Union[str, Sequence[str], None] = "b0c2d4e6f8a1"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _has_column(table: str, column: str) -> bool:
    insp = sa.inspect(op.get_bind())
    return insp.has_table(table) and column in {c["name"] for c in insp.get_columns(table)}


def upgrade() -> None:
    # ensure_hours_loyalty_schema() adds it at boot on hosts without alembic.
    if not _has_column("order_messages", "kind"):
        with op.batch_alter_table("order_messages") as batch:
            batch.add_column(
                sa.Column("kind", sa.String(length=12), nullable=False, server_default="text")
            )


def downgrade() -> None:
    if _has_column("order_messages", "kind"):
        with op.batch_alter_table("order_messages") as batch:
            batch.drop_column("kind")
