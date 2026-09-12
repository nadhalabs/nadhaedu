"""Operational readiness media registry.

Revision ID: 0002_operations
Revises: 0001_phase_a
"""

import sqlalchemy as sa

from alembic import op

revision = "0002_operations"
down_revision = "0001_phase_a"
branch_labels = None
depends_on = None


def upgrade():
    inspector = sa.inspect(op.get_bind())
    if "media_assets" not in inspector.get_table_names():
        op.create_table(
            "media_assets",
            sa.Column(
                "lesson_id",
                sa.String(36),
                sa.ForeignKey("lessons.id", ondelete="CASCADE"),
                nullable=False,
            ),
            sa.Column("asset_id", sa.String(100), nullable=False),
            sa.Column("kind", sa.String(20), nullable=False),
            sa.Column("origin_key", sa.String(500), nullable=False),
            sa.Column("public", sa.Boolean(), nullable=False, server_default=sa.false()),
            sa.Column("status", sa.String(20), nullable=False, server_default="active"),
            sa.Column("id", sa.String(36), primary_key=True),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
            sa.CheckConstraint("kind IN ('hls', 'download', 'subtitle', 'thumbnail')"),
            sa.UniqueConstraint("asset_id"),
            sa.UniqueConstraint("origin_key"),
        )
        op.create_index("ix_media_assets_lesson_id", "media_assets", ["lesson_id"])
        op.create_index("ix_media_assets_asset_id", "media_assets", ["asset_id"], unique=True)
        op.create_index("ix_media_assets_status", "media_assets", ["status"])


def downgrade():
    if "media_assets" in sa.inspect(op.get_bind()).get_table_names():
        op.drop_table("media_assets")
