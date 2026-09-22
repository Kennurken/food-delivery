"""address apt/entrance/floor/intercom

Revision ID: c4f1a9d2e8b0
Revises: 8beff049897e
Create Date: 2026-09-21 17:20:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "c4f1a9d2e8b0"
down_revision: Union[str, Sequence[str], None] = "8beff049897e"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    with op.batch_alter_table("addresses", schema=None) as batch_op:
        batch_op.add_column(sa.Column("apt", sa.String(length=40), nullable=True))
        batch_op.add_column(sa.Column("entrance", sa.String(length=40), nullable=True))
        batch_op.add_column(sa.Column("floor", sa.String(length=20), nullable=True))
        batch_op.add_column(sa.Column("intercom", sa.String(length=40), nullable=True))


def downgrade() -> None:
    with op.batch_alter_table("addresses", schema=None) as batch_op:
        batch_op.drop_column("intercom")
        batch_op.drop_column("floor")
        batch_op.drop_column("entrance")
        batch_op.drop_column("apt")
