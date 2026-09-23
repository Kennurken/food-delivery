"""public url slug on restaurants

Revision ID: b4e7c2a9d6f1
Revises: a7d3f1e9c2b5
Create Date: 2026-09-23 16:30:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "b4e7c2a9d6f1"
down_revision: Union[str, Sequence[str], None] = "a7d3f1e9c2b5"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _has_column(table: str, column: str) -> bool:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    if not inspector.has_table(table):
        return False
    return column in {c["name"] for c in inspector.get_columns(table)}


def _has_index(table: str, name: str) -> bool:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    if not inspector.has_table(table):
        return False
    return name in {i["name"] for i in inspector.get_indexes(table)}


def upgrade() -> None:
    # ensure_slug_schema() adds this at boot on hosts without alembic, so this
    # has to be safe to replay against a database that already has it.
    if not _has_column("restaurants", "slug"):
        op.add_column("restaurants", sa.Column("slug", sa.String(length=80), nullable=True))
    if not _has_index("restaurants", "ix_restaurants_slug"):
        op.create_index("ix_restaurants_slug", "restaurants", ["slug"], unique=True)


def downgrade() -> None:
    if _has_index("restaurants", "ix_restaurants_slug"):
        op.drop_index("ix_restaurants_slug", table_name="restaurants")
    if _has_column("restaurants", "slug"):
        op.drop_column("restaurants", "slug")
