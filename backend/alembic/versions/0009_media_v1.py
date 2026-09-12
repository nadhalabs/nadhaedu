"""Generic provider metadata and per-asset watch history; preserve all existing IDs."""

import sqlalchemy as sa
from alembic import op

revision = "0009_media_v1"
down_revision = "0008_academic_hierarchy"
branch_labels = depends_on = None


def upgrade():
    op.add_column("media_assets", sa.Column("provider", sa.String(30)))
    op.add_column("media_assets", sa.Column("provider_asset_id", sa.String(255)))
    op.add_column(
        "media_assets", sa.Column("metadata_json", sa.JSON(), nullable=False, server_default="{}")
    )
    op.add_column("courses", sa.Column("cover_reference", sa.String(1000)))
    op.create_table(
        "video_watch_progress",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column(
            "learner_id",
            sa.String(36),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "media_asset_id",
            sa.String(36),
            sa.ForeignKey("media_assets.id", ondelete="RESTRICT"),
            nullable=False,
        ),
        sa.Column("position_seconds", sa.Float(), nullable=False),
        sa.Column("furthest_seconds", sa.Float(), nullable=False),
        sa.Column("completed", sa.Boolean(), nullable=False),
        sa.Column("checkpoint_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("learner_id", "media_asset_id"),
    )


def downgrade():
    op.drop_table("video_watch_progress")
    op.drop_column("courses", "cover_reference")
    for column in ("metadata_json", "provider_asset_id", "provider"):
        op.drop_column("media_assets", column)
