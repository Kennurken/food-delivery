"""table reservations

Revision ID: e5b7d9f1c3a4
Revises: d4a6c8e0b2f1
Create Date: 2026-09-22 19:20:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "e5b7d9f1c3a4"
down_revision: Union[str, Sequence[str], None] = "d4a6c8e0b2f1"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "reservations",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("restaurant_id", sa.Integer(), sa.ForeignKey("restaurants.id"), nullable=False),
        sa.Column(
            "user_id",
            sa.Integer(),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column(
            "table_object_id",
            sa.Integer(),
            sa.ForeignKey("floor_objects.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column("name", sa.String(length=80), nullable=False),
        sa.Column("phone", sa.String(length=30), nullable=True),
        sa.Column("guests", sa.Integer(), nullable=False, server_default="2"),
        sa.Column("starts_at", sa.DateTime(), nullable=False),
        sa.Column("duration_min", sa.Integer(), nullable=False, server_default="90"),
        sa.Column("status", sa.String(length=20), nullable=False, server_default="requested"),
        sa.Column("comment", sa.String(length=500), nullable=True),
        sa.Column("created_at", sa.DateTime(), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_reservations_restaurant_id", "reservations", ["restaurant_id"])
    op.create_index("ix_reservations_user_id", "reservations", ["user_id"])
    op.create_index("ix_reservations_table_object_id", "reservations", ["table_object_id"])
    op.create_index("ix_reservations_starts_at", "reservations", ["starts_at"])


def downgrade() -> None:
    op.drop_index("ix_reservations_starts_at", table_name="reservations")
    op.drop_index("ix_reservations_table_object_id", table_name="reservations")
    op.drop_index("ix_reservations_user_id", table_name="reservations")
    op.drop_index("ix_reservations_restaurant_id", table_name="reservations")
    op.drop_table("reservations")
