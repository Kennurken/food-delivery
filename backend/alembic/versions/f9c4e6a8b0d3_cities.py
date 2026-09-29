"""cities

Revision ID: f9c4e6a8b0d3
Revises: e8b3d5c7a9f2
Create Date: 2026-09-29 20:40:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "f9c4e6a8b0d3"
down_revision: Union[str, Sequence[str], None] = "e8b3d5c7a9f2"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _inspector():
    return sa.inspect(op.get_bind())


def _has_column(table: str, column: str) -> bool:
    insp = _inspector()
    return insp.has_table(table) and column in {c["name"] for c in insp.get_columns(table)}


def upgrade() -> None:
    # ensure_city_schema() builds both of these at boot on hosts without
    # alembic, so each step has to accept finding its work already done.
    if not _inspector().has_table("cities"):
        op.create_table(
            "cities",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("slug", sa.String(length=40), nullable=False),
            sa.Column("name", sa.String(length=80), nullable=False),
            sa.Column("lat", sa.Float(), nullable=True),
            sa.Column("lng", sa.Float(), nullable=True),
            sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
            sa.Column("sort_order", sa.Integer(), nullable=False, server_default="0"),
        )
        op.create_index("ix_cities_slug", "cities", ["slug"], unique=True)
    if not _has_column("restaurants", "city_id"):
        # batch mode: SQLite cannot add a foreign key with a plain ALTER.
        with op.batch_alter_table("restaurants") as batch:
            batch.add_column(sa.Column("city_id", sa.Integer(), nullable=True))
            batch.create_foreign_key(
                "fk_restaurants_city_id", "cities", ["city_id"], ["id"], ondelete="SET NULL"
            )
            batch.create_index("ix_restaurants_city_id", ["city_id"])


def downgrade() -> None:
    if _has_column("restaurants", "city_id"):
        with op.batch_alter_table("restaurants") as batch:
            batch.drop_index("ix_restaurants_city_id")
            batch.drop_constraint("fk_restaurants_city_id", type_="foreignkey")
            batch.drop_column("city_id")
    if _inspector().has_table("cities"):
        op.drop_table("cities")
