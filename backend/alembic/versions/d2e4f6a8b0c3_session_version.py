"""users: session version, to sign someone out everywhere

Revision ID: d2e4f6a8b0c3
Revises: c1d3e5f7a9b2
Create Date: 2026-10-02 18:00:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "d2e4f6a8b0c3"
down_revision: Union[str, Sequence[str], None] = "c1d3e5f7a9b2"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _has_column(table: str, column: str) -> bool:
    insp = sa.inspect(op.get_bind())
    return insp.has_table(table) and column in {c["name"] for c in insp.get_columns(table)}


def upgrade() -> None:
    # ensure_hours_loyalty_schema() adds it at boot on hosts without alembic.
    if not _has_column("users", "token_version"):
        with op.batch_alter_table("users") as batch:
            batch.add_column(
                sa.Column("token_version", sa.Integer(), nullable=False, server_default="0")
            )


def downgrade() -> None:
    if _has_column("users", "token_version"):
        with op.batch_alter_table("users") as batch:
            batch.drop_column("token_version")
