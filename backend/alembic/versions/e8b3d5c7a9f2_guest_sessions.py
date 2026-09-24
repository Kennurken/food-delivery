"""guest flag on users

Revision ID: e8b3d5c7a9f2
Revises: d7a2c4f6b8e1
Create Date: 2026-09-24 08:20:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "e8b3d5c7a9f2"
down_revision: Union[str, Sequence[str], None] = "d7a2c4f6b8e1"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _has_column(table: str, column: str) -> bool:
    inspector = sa.inspect(op.get_bind())
    if not inspector.has_table(table):
        return False
    return column in {c["name"] for c in inspector.get_columns(table)}


def upgrade() -> None:
    # ensure_guest_schema() adds this at boot on hosts without alembic.
    if not _has_column("users", "is_guest"):
        op.add_column(
            "users",
            sa.Column(
                "is_guest", sa.Boolean(), nullable=False, server_default=sa.false()
            ),
        )


def downgrade() -> None:
    if _has_column("users", "is_guest"):
        op.drop_column("users", "is_guest")
