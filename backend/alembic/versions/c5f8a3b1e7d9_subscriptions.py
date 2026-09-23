"""stripe billing columns on restaurants

Revision ID: c5f8a3b1e7d9
Revises: b4e7c2a9d6f1
Create Date: 2026-09-23 17:40:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "c5f8a3b1e7d9"
down_revision: Union[str, Sequence[str], None] = "b4e7c2a9d6f1"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

_COLUMNS = (
    ("stripe_customer_id", sa.String(length=80)),
    ("stripe_subscription_id", sa.String(length=80)),
    ("plan_renews_at", sa.DateTime()),
)


def _has_column(table: str, column: str) -> bool:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    if not inspector.has_table(table):
        return False
    return column in {c["name"] for c in inspector.get_columns(table)}


def upgrade() -> None:
    # ensure_subscription_schema() adds these at boot on hosts without alembic,
    # so this has to be safe to replay.
    for name, kind in _COLUMNS:
        if not _has_column("restaurants", name):
            op.add_column("restaurants", sa.Column(name, kind, nullable=True))


def downgrade() -> None:
    for name, _ in reversed(_COLUMNS):
        if _has_column("restaurants", name):
            op.drop_column("restaurants", name)
