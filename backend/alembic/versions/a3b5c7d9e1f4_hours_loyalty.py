"""opening hours, bonus ledger, city forms

Revision ID: a3b5c7d9e1f4
Revises: f9c4e6a8b0d3
Create Date: 2026-09-30 10:00:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "a3b5c7d9e1f4"
down_revision: Union[str, Sequence[str], None] = "f9c4e6a8b0d3"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

_COLUMNS = [
    ("cities", sa.Column("name_in", sa.String(length=80), nullable=True)),
    ("cities", sa.Column("utc_offset_min", sa.Integer(), nullable=False, server_default="300")),
    ("restaurants", sa.Column("loyalty_percent", sa.Float(), nullable=False, server_default="0")),
    ("restaurants", sa.Column("loyalty_max_share", sa.Float(), nullable=False, server_default="0.5")),
    ("orders", sa.Column("loyalty_spent", sa.Float(), nullable=False, server_default="0")),
]


def _inspector():
    return sa.inspect(op.get_bind())


def _has_column(table: str, column: str) -> bool:
    insp = _inspector()
    return insp.has_table(table) and column in {c["name"] for c in insp.get_columns(table)}


def upgrade() -> None:
    # ensure_hours_loyalty_schema() builds all of this at boot on hosts without
    # alembic, so every step accepts finding its work already done.
    if not _inspector().has_table("opening_hours"):
        op.create_table(
            "opening_hours",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column(
                "restaurant_id",
                sa.Integer(),
                sa.ForeignKey("restaurants.id", ondelete="CASCADE"),
                nullable=False,
            ),
            sa.Column("weekday", sa.Integer(), nullable=False),
            sa.Column("opens", sa.Time(), nullable=False),
            sa.Column("closes", sa.Time(), nullable=False),
        )
        op.create_index("ix_opening_hours_restaurant_id", "opening_hours", ["restaurant_id"])
    if not _inspector().has_table("loyalty_entries"):
        op.create_table(
            "loyalty_entries",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column(
                "user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False
            ),
            sa.Column(
                "restaurant_id",
                sa.Integer(),
                sa.ForeignKey("restaurants.id", ondelete="CASCADE"),
                nullable=False,
            ),
            sa.Column(
                "order_id", sa.Integer(), sa.ForeignKey("orders.id", ondelete="SET NULL"), nullable=True
            ),
            sa.Column("kind", sa.String(length=12), nullable=False),
            sa.Column("amount", sa.Float(), nullable=False),
            sa.Column("created_at", sa.DateTime(), server_default=sa.func.now(), nullable=False),
            sa.UniqueConstraint("order_id", "kind", name="uq_loyalty_order_kind"),
        )
        op.create_index("ix_loyalty_entries_user_id", "loyalty_entries", ["user_id"])
        op.create_index("ix_loyalty_entries_restaurant_id", "loyalty_entries", ["restaurant_id"])
    for table, column in _COLUMNS:
        if not _has_column(table, column.name):
            with op.batch_alter_table(table) as batch:
                batch.add_column(column)


def downgrade() -> None:
    for table, column in reversed(_COLUMNS):
        if _has_column(table, column.name):
            with op.batch_alter_table(table) as batch:
                batch.drop_column(column.name)
    if _inspector().has_table("loyalty_entries"):
        op.drop_table("loyalty_entries")
    if _inspector().has_table("opening_hours"):
        op.drop_table("opening_hours")
