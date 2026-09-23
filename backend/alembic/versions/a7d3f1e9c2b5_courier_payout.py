"""courier payout frozen on the order

Revision ID: a7d3f1e9c2b5
Revises: c9e2a5b7d1f4
Create Date: 2026-09-23 16:10:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "a7d3f1e9c2b5"
down_revision: Union[str, Sequence[str], None] = "c9e2a5b7d1f4"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _has_column(table: str, column: str) -> bool:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    if not inspector.has_table(table):
        return False
    return column in {c["name"] for c in inspector.get_columns(table)}


def upgrade() -> None:
    # ensure_courier_payout_schema() adds this at boot on hosts without alembic,
    # so this has to be safe to replay on a database that already has it.
    if not _has_column("orders", "courier_payout"):
        op.add_column(
            "orders",
            sa.Column(
                "courier_payout",
                sa.Float(),
                nullable=False,
                server_default="0",
            ),
        )


def downgrade() -> None:
    if _has_column("orders", "courier_payout"):
        op.drop_column("orders", "courier_payout")
