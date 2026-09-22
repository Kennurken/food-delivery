"""order chat thread

Revision ID: d4a6c8e0b2f1
Revises: c3f5b7d9e1a2
Create Date: 2026-09-22 19:05:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "d4a6c8e0b2f1"
down_revision: Union[str, Sequence[str], None] = "c3f5b7d9e1a2"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "order_messages",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "order_id",
            sa.Integer(),
            sa.ForeignKey("orders.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "user_id",
            sa.Integer(),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column("sender_name", sa.String(length=80), nullable=False),
        sa.Column("body", sa.String(length=800), nullable=False),
        sa.Column("created_at", sa.DateTime(), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_order_messages_order_id", "order_messages", ["order_id"])
    op.create_index("ix_order_messages_user_id", "order_messages", ["user_id"])


def downgrade() -> None:
    op.drop_index("ix_order_messages_user_id", table_name="order_messages")
    op.drop_index("ix_order_messages_order_id", table_name="order_messages")
    op.drop_table("order_messages")
