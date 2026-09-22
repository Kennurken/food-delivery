"""map pins: restaurant, address, order, courier

Revision ID: a9c2d4e6f8b0
Revises: f3c9e8a1b7d2
Create Date: 2026-09-22 18:20:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "a9c2d4e6f8b0"
down_revision: Union[str, Sequence[str], None] = "f3c9e8a1b7d2"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("restaurants", sa.Column("lat", sa.Float(), nullable=True))
    op.add_column("restaurants", sa.Column("lng", sa.Float(), nullable=True))
    op.add_column("addresses", sa.Column("lat", sa.Float(), nullable=True))
    op.add_column("addresses", sa.Column("lng", sa.Float(), nullable=True))
    op.add_column("orders", sa.Column("dest_lat", sa.Float(), nullable=True))
    op.add_column("orders", sa.Column("dest_lng", sa.Float(), nullable=True))
    op.add_column("orders", sa.Column("pickup_lat", sa.Float(), nullable=True))
    op.add_column("orders", sa.Column("pickup_lng", sa.Float(), nullable=True))
    op.add_column("users", sa.Column("last_lat", sa.Float(), nullable=True))
    op.add_column("users", sa.Column("last_lng", sa.Float(), nullable=True))
    op.add_column("users", sa.Column("last_heading", sa.Float(), nullable=True))
    op.add_column("users", sa.Column("last_seen_at", sa.DateTime(), nullable=True))


def downgrade() -> None:
    op.drop_column("users", "last_seen_at")
    op.drop_column("users", "last_heading")
    op.drop_column("users", "last_lng")
    op.drop_column("users", "last_lat")
    op.drop_column("orders", "pickup_lng")
    op.drop_column("orders", "pickup_lat")
    op.drop_column("orders", "dest_lng")
    op.drop_column("orders", "dest_lat")
    op.drop_column("addresses", "lng")
    op.drop_column("addresses", "lat")
    op.drop_column("restaurants", "lng")
    op.drop_column("restaurants", "lat")
