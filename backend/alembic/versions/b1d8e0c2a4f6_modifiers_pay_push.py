"""modifiers, cash pay fields, device tokens

Revision ID: b1d8e0c2a4f6
Revises: a9c2d4e6f8b0
Create Date: 2026-09-22 18:40:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "b1d8e0c2a4f6"
down_revision: Union[str, Sequence[str], None] = "a9c2d4e6f8b0"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "modifier_groups",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("menu_item_id", sa.Integer(), sa.ForeignKey("menu_items.id"), nullable=False),
        sa.Column("name", sa.String(length=80), nullable=False),
        sa.Column("required", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("min_select", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("max_select", sa.Integer(), nullable=False, server_default="1"),
    )
    op.create_index("ix_modifier_groups_menu_item_id", "modifier_groups", ["menu_item_id"])
    op.create_table(
        "modifier_options",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("group_id", sa.Integer(), sa.ForeignKey("modifier_groups.id"), nullable=False),
        sa.Column("name", sa.String(length=80), nullable=False),
        sa.Column("price_delta", sa.Float(), nullable=False, server_default="0"),
        sa.Column("is_default", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("is_available", sa.Boolean(), nullable=False, server_default=sa.true()),
    )
    op.create_index("ix_modifier_options_group_id", "modifier_options", ["group_id"])
    op.create_table(
        "device_tokens",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("token", sa.String(length=512), nullable=False),
        sa.Column("platform", sa.String(length=20), nullable=False, server_default="android"),
        sa.Column("updated_at", sa.DateTime(), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint("token", name="uq_device_tokens_token"),
    )
    op.create_index("ix_device_tokens_user_id", "device_tokens", ["user_id"])
    op.add_column(
        "order_items",
        sa.Column("modifiers", sa.JSON(), nullable=False, server_default="[]"),
    )
    op.add_column(
        "orders",
        sa.Column("pay_method", sa.String(length=20), nullable=False, server_default="cash"),
    )
    op.add_column(
        "orders",
        sa.Column("pay_status", sa.String(length=20), nullable=False, server_default="unpaid"),
    )


def downgrade() -> None:
    op.drop_column("orders", "pay_status")
    op.drop_column("orders", "pay_method")
    op.drop_column("order_items", "modifiers")
    op.drop_index("ix_device_tokens_user_id", table_name="device_tokens")
    op.drop_table("device_tokens")
    op.drop_index("ix_modifier_options_group_id", table_name="modifier_options")
    op.drop_table("modifier_options")
    op.drop_index("ix_modifier_groups_menu_item_id", table_name="modifier_groups")
    op.drop_table("modifier_groups")
