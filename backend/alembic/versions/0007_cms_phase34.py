"""CMS Phase 3 and 4 operational controls.

Revision ID: 0007_cms_phase34
Revises: 0006_r3_query_indexes
"""

import sqlalchemy as sa

from alembic import op

revision = "0007_cms_phase34"
down_revision = "0006_r3_query_indexes"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # PostgreSQL enum values are intentionally retained on downgrade because removing
    # an enum value is not transaction-safe and old rows may still reference it.
    op.execute("ALTER TYPE userrole ADD VALUE IF NOT EXISTS 'super_admin'")
    op.add_column("users", sa.Column("suspended_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("users", sa.Column("suspension_reason", sa.String(length=500), nullable=True))
    op.add_column(
        "entitlements",
        sa.Column("version", sa.Integer(), nullable=False, server_default="1"),
    )
    op.create_table(
        "platform_settings",
        sa.Column("key", sa.String(length=80), primary_key=True),
        sa.Column("value", sa.Boolean(), nullable=False),
        sa.Column("version", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("description", sa.String(length=300), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_by", sa.String(length=36), nullable=True),
        sa.ForeignKeyConstraint(["updated_by"], ["users.id"], ondelete="SET NULL"),
    )
    op.create_index(
        "ix_audit_events_subject_occurred",
        "audit_events",
        ["subject_type", "occurred_at", "id"],
    )


def downgrade() -> None:
    op.drop_index("ix_audit_events_subject_occurred", table_name="audit_events")
    op.drop_table("platform_settings")
    op.drop_column("entitlements", "version")
    op.drop_column("users", "suspension_reason")
    op.drop_column("users", "suspended_at")
