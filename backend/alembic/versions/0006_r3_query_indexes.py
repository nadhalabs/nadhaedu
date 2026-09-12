"""R3 query-aligned composite indexes and performance optimization.

Revision ID: 0006_r3_query_indexes
Revises: 0005_p0_integrity
"""

import sqlalchemy as sa

from alembic import op

revision = "0006_r3_query_indexes"
down_revision = "0005_p0_integrity"
branch_labels = None
depends_on = None


def _indexes(inspector, table):
    return {index["name"] for index in inspector.get_indexes(table)}


def upgrade():
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    tables = set(inspector.get_table_names())

    if "auth_sessions" in tables:
        indexes = _indexes(sa.inspect(bind), "auth_sessions")
        if "ix_auth_sessions_user_active" not in indexes:
            op.create_index(
                "ix_auth_sessions_user_active",
                "auth_sessions",
                ["user_id", "revoked_at", "expires_at"],
            )

    if "notifications" in tables:
        indexes = _indexes(sa.inspect(bind), "notifications")
        if "ix_notifications_user_created" not in indexes:
            op.create_index(
                "ix_notifications_user_created",
                "notifications",
                ["user_id", "created_at", "id"],
            )
        if "ix_notifications_user_unread" not in indexes:
            op.create_index(
                "ix_notifications_user_unread",
                "notifications",
                ["user_id", "read_at", "expires_at"],
            )

    if "purchases" in tables:
        indexes = _indexes(sa.inspect(bind), "purchases")
        if "ix_purchases_learner_purchased_at" not in indexes:
            op.create_index(
                "ix_purchases_learner_purchased_at",
                "purchases",
                ["learner_id", "purchased_at", "id"],
            )

    if "subscriptions" in tables:
        indexes = _indexes(sa.inspect(bind), "subscriptions")
        if "ix_subscriptions_learner_status_created" not in indexes:
            op.create_index(
                "ix_subscriptions_learner_status_created",
                "subscriptions",
                ["learner_id", "status", "created_at"],
            )


def downgrade():
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    tables = set(inspector.get_table_names())

    if "subscriptions" in tables:
        indexes = _indexes(sa.inspect(bind), "subscriptions")
        if "ix_subscriptions_learner_status_created" in indexes:
            op.drop_index("ix_subscriptions_learner_status_created", table_name="subscriptions")

    if "purchases" in tables:
        indexes = _indexes(sa.inspect(bind), "purchases")
        if "ix_purchases_learner_purchased_at" in indexes:
            op.drop_index("ix_purchases_learner_purchased_at", table_name="purchases")

    if "notifications" in tables:
        indexes = _indexes(sa.inspect(bind), "notifications")
        if "ix_notifications_user_unread" in indexes:
            op.drop_index("ix_notifications_user_unread", table_name="notifications")
        if "ix_notifications_user_created" in indexes:
            op.drop_index("ix_notifications_user_created", table_name="notifications")

    if "auth_sessions" in tables:
        indexes = _indexes(sa.inspect(bind), "auth_sessions")
        if "ix_auth_sessions_user_active" in indexes:
            op.drop_index("ix_auth_sessions_user_active", table_name="auth_sessions")
