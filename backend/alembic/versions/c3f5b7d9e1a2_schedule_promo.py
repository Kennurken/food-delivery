"""scheduled_for, promo snapshot, promo table

Revision ID: c3f5b7d9e1a2
Revises: b1d8e0c2a4f6
Create Date: 2026-09-22 18:50:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "c3f5b7d9e1a2"
down_revision: Union[str, Sequence[str], None] = "b1d8e0c2a4f6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "promos",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("restaurant_id", sa.Integer(), sa.ForeignKey("restaurants.id"), nullable=False),
        sa.Column("code", sa.String(length=24), nullable=False),
        sa.Column("kind", sa.String(length=16), nullable=False, server_default="percent"),
        sa.Column("value", sa.Float(), nullable=False),
        sa.Column("min_subtotal", sa.Float(), nullable=False, server_default="0"),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("max_uses", sa.Integer(), nullable=True),
        sa.Column("used_count", sa.Integer(), nullable=False, server_default="0"),
        sa.UniqueConstraint("restaurant_id", "code", name="uq_promos_restaurant_code"),
    )
    op.create_index("ix_promos_restaurant_id", "promos", ["restaurant_id"])
    op.add_column("orders", sa.Column("scheduled_for", sa.DateTime(), nullable=True))
    op.add_column("orders", sa.Column("promo_code", sa.String(length=24), nullable=True))
    op.add_column(
        "orders",
        sa.Column("discount", sa.Float(), nullable=False, server_default="0"),
    )


def downgrade() -> None:
    op.drop_column("orders", "discount")
    op.drop_column("orders", "promo_code")
    op.drop_column("orders", "scheduled_for")
    op.drop_index("ix_promos_restaurant_id", table_name="promos")
    op.drop_table("promos")
