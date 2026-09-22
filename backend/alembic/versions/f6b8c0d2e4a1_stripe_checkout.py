"""stripe checkout session on orders

Revision ID: f6b8c0d2e4a1
Revises: e5b7d9f1c3a4
Create Date: 2026-09-22 19:40:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "f6b8c0d2e4a1"
down_revision: Union[str, Sequence[str], None] = "e5b7d9f1c3a4"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _has_column(table: str, column: str) -> bool:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    if not inspector.has_table(table):
        return False
    return column in {c["name"] for c in inspector.get_columns(table)}


def upgrade() -> None:
    # ensure_checkout_schema() adds these at boot on hosts without alembic.
    if not _has_column("orders", "pay_ref"):
        op.add_column("orders", sa.Column("pay_ref", sa.String(length=120), nullable=True))
    if not _has_column("orders", "checkout_url"):
        op.add_column("orders", sa.Column("checkout_url", sa.String(length=500), nullable=True))


def downgrade() -> None:
    if _has_column("orders", "checkout_url"):
        op.drop_column("orders", "checkout_url")
    if _has_column("orders", "pay_ref"):
        op.drop_column("orders", "pay_ref")
