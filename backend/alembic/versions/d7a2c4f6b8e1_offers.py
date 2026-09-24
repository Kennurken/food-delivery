"""campaign pages

Revision ID: d7a2c4f6b8e1
Revises: c5f8a3b1e7d9
Create Date: 2026-09-24 07:10:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "d7a2c4f6b8e1"
down_revision: Union[str, Sequence[str], None] = "c5f8a3b1e7d9"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _has_table(name: str) -> bool:
    return sa.inspect(op.get_bind()).has_table(name)


def upgrade() -> None:
    # ensure_offer_schema() creates this at boot on hosts without alembic.
    if _has_table("offers"):
        return
    op.create_table(
        "offers",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "restaurant_id",
            sa.Integer(),
            sa.ForeignKey("restaurants.id", ondelete="CASCADE"),
            nullable=True,
        ),
        sa.Column("slug", sa.String(length=80), nullable=False),
        sa.Column("title", sa.String(length=160), nullable=False),
        sa.Column("subtitle", sa.String(length=300), nullable=False, server_default=""),
        sa.Column("body", sa.Text(), nullable=False, server_default=""),
        sa.Column("image_url", sa.String(length=500), nullable=True),
        sa.Column("promo_code", sa.String(length=24), nullable=True),
        sa.Column("starts_at", sa.DateTime(), nullable=True),
        sa.Column("ends_at", sa.DateTime(), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("sort_order", sa.Integer(), nullable=False, server_default="0"),
    )
    op.create_index("ix_offers_slug", "offers", ["slug"], unique=True)
    op.create_index("ix_offers_restaurant_id", "offers", ["restaurant_id"])


def downgrade() -> None:
    if _has_table("offers"):
        op.drop_table("offers")
