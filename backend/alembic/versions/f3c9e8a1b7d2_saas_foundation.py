"""saas foundation: plans, members, audit, order channel

Revision ID: f3c9e8a1b7d2
Revises: e1a7c3f9b2d4
Create Date: 2026-09-22 18:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "f3c9e8a1b7d2"
down_revision: Union[str, Sequence[str], None] = "e1a7c3f9b2d4"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "restaurants",
        sa.Column("plan_code", sa.String(length=20), server_default="pro", nullable=False),
    )
    op.add_column(
        "restaurants",
        sa.Column("billing_status", sa.String(length=20), server_default="active", nullable=False),
    )
    op.add_column(
        "orders",
        sa.Column("channel", sa.String(length=20), server_default="delivery", nullable=False),
    )
    op.add_column("orders", sa.Column("table_object_id", sa.Integer(), nullable=True))
    with op.batch_alter_table("orders") as batch:
        batch.create_foreign_key(
            "fk_orders_table_object_id",
            "floor_objects",
            ["table_object_id"],
            ["id"],
            ondelete="SET NULL",
        )

    op.create_table(
        "restaurant_members",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("restaurant_id", sa.Integer(), nullable=False),
        sa.Column("role", sa.String(length=40), nullable=False),
        sa.Column("created_at", sa.DateTime(), server_default=sa.func.now(), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["restaurant_id"], ["restaurants.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "restaurant_id", name="uq_member_user_restaurant"),
    )
    op.create_index("ix_restaurant_members_user_id", "restaurant_members", ["user_id"])
    op.create_index("ix_restaurant_members_restaurant_id", "restaurant_members", ["restaurant_id"])

    op.create_table(
        "feature_overrides",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("restaurant_id", sa.Integer(), nullable=False),
        sa.Column("key", sa.String(length=80), nullable=False),
        sa.Column("enabled", sa.Boolean(), nullable=False),
        sa.ForeignKeyConstraint(["restaurant_id"], ["restaurants.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("restaurant_id", "key", name="uq_feature_restaurant_key"),
    )
    op.create_index("ix_feature_overrides_restaurant_id", "feature_overrides", ["restaurant_id"])

    op.create_table(
        "audit_logs",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("actor_id", sa.Integer(), nullable=True),
        sa.Column("restaurant_id", sa.Integer(), nullable=True),
        sa.Column("action", sa.String(length=80), nullable=False),
        sa.Column("resource", sa.String(length=120), nullable=False),
        sa.Column("payload", sa.JSON(), nullable=False),
        sa.Column("request_id", sa.String(length=40), nullable=True),
        sa.Column("created_at", sa.DateTime(), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["actor_id"], ["users.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["restaurant_id"], ["restaurants.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_audit_logs_actor_id", "audit_logs", ["actor_id"])
    op.create_index("ix_audit_logs_restaurant_id", "audit_logs", ["restaurant_id"])
    op.create_index("ix_audit_logs_action", "audit_logs", ["action"])
    op.create_index("ix_audit_logs_created_at", "audit_logs", ["created_at"])

    op.create_table(
        "idempotency_keys",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("key", sa.String(length=128), nullable=False),
        sa.Column("body_hash", sa.String(length=64), nullable=False),
        sa.Column("order_id", sa.Integer(), nullable=True),
        sa.Column("created_at", sa.DateTime(), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["order_id"], ["orders.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "key", name="uq_idempotency_user_key"),
    )
    op.create_index("ix_idempotency_keys_user_id", "idempotency_keys", ["user_id"])


def downgrade() -> None:
    op.drop_table("idempotency_keys")
    op.drop_table("audit_logs")
    op.drop_table("feature_overrides")
    op.drop_table("restaurant_members")
    with op.batch_alter_table("orders") as batch:
        batch.drop_constraint("fk_orders_table_object_id", type_="foreignkey")
        batch.drop_column("table_object_id")
        batch.drop_column("channel")
    op.drop_column("restaurants", "billing_status")
    op.drop_column("restaurants", "plan_code")
