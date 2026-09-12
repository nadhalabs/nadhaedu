"""Content protection policy metadata.

Revision ID: 0004_protection
Revises: 0003_commerce
"""

import sqlalchemy as sa

from alembic import op

revision = "0004_protection"
down_revision = "0003_commerce"
branch_labels = None
depends_on = None


def upgrade():
    inspector = sa.inspect(op.get_bind())
    existing_tables = inspector.get_table_names()

    if "courses" in existing_tables:
        columns = [c["name"] for c in inspector.get_columns("courses")]
        if "protection_policy" not in columns:
            op.add_column(
                "courses",
                sa.Column(
                    "protection_policy",
                    sa.String(40),
                    nullable=False,
                    server_default="blockCaptureWhereSupported",
                ),
            )

    if "lessons" in existing_tables:
        columns = [c["name"] for c in inspector.get_columns("lessons")]
        if "protection_policy" not in columns:
            op.add_column(
                "lessons",
                sa.Column(
                    "protection_policy",
                    sa.String(40),
                    nullable=False,
                    server_default="blockCaptureWhereSupported",
                ),
            )

    if "assessments" in existing_tables:
        columns = [c["name"] for c in inspector.get_columns("assessments")]
        if "protection_policy" not in columns:
            op.add_column(
                "assessments",
                sa.Column(
                    "protection_policy",
                    sa.String(40),
                    nullable=False,
                    server_default="blockCaptureWhereSupported",
                ),
            )


def downgrade():
    inspector = sa.inspect(op.get_bind())
    existing_tables = inspector.get_table_names()

    if "assessments" in existing_tables:
        columns = [c["name"] for c in inspector.get_columns("assessments")]
        if "protection_policy" in columns:
            op.drop_column("assessments", "protection_policy")

    if "lessons" in existing_tables:
        columns = [c["name"] for c in inspector.get_columns("lessons")]
        if "protection_policy" in columns:
            op.drop_column("lessons", "protection_policy")

    if "courses" in existing_tables:
        columns = [c["name"] for c in inspector.get_columns("courses")]
        if "protection_policy" in columns:
            op.drop_column("courses", "protection_policy")
