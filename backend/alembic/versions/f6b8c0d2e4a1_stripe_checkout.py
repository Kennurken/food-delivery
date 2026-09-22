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


def upgrade() -> None:
    op.add_column("orders", sa.Column("pay_ref", sa.String(length=120), nullable=True))
    op.add_column("orders", sa.Column("checkout_url", sa.String(length=500), nullable=True))


def downgrade() -> None:
    op.drop_column("orders", "checkout_url")
    op.drop_column("orders", "pay_ref")
