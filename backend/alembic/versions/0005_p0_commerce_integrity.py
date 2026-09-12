"""P0 commerce provenance, scope, and deterministic schema reconciliation.

Revision ID: 0005_p0_integrity
Revises: 0004_protection
"""

import sqlalchemy as sa

from alembic import op

revision = "0005_p0_integrity"
down_revision = "0004_protection"
branch_labels = None
depends_on = None


def _columns(inspector, table):
    return {column["name"] for column in inspector.get_columns(table)}


def _indexes(inspector, table):
    return {index["name"] for index in inspector.get_indexes(table)}


def upgrade():
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    tables = set(inspector.get_table_names())

    if "payment_transactions" in tables:
        columns = _columns(inspector, "payment_transactions")
        if "provider_product_id" not in columns:
            op.add_column(
                "payment_transactions",
                sa.Column("provider_product_id", sa.String(255), nullable=True),
            )
            op.execute(
                """
                UPDATE payment_transactions AS tx
                   SET provider_product_id = mapping.provider_product_id
                  FROM provider_product_mappings AS mapping
                 WHERE mapping.provider = tx.provider
                   AND mapping.provider_product_id = tx.provider_transaction_id
                """
            )
        if "ix_payment_transactions_provider_product_id" not in _indexes(
            sa.inspect(bind), "payment_transactions"
        ):
            op.create_index(
                "ix_payment_transactions_provider_product_id",
                "payment_transactions",
                ["provider_product_id"],
            )

    if "subscriptions" in tables:
        columns = _columns(inspector, "subscriptions")
        if "provider" not in columns:
            op.add_column("subscriptions", sa.Column("provider", sa.String(30), nullable=True))
            op.execute(
                """
                UPDATE subscriptions AS s
                   SET provider = tx.provider
                  FROM payment_transactions AS tx
                 WHERE tx.provider_transaction_id IN (
                     s.original_transaction_id, s.latest_transaction_id
                 )
                """
            )
            missing_provider = bind.execute(
                sa.text("SELECT id FROM subscriptions WHERE provider IS NULL LIMIT 1")
            ).scalar()
            if missing_provider:
                raise RuntimeError(
                    "Cannot establish subscription provider ownership for legacy rows."
                )
            op.alter_column("subscriptions", "provider", nullable=False)
        if "provider_state_updated_at" not in columns:
            op.add_column(
                "subscriptions",
                sa.Column("provider_state_updated_at", sa.DateTime(timezone=True), nullable=True),
            )
        duplicate = bind.execute(
            sa.text(
                """
                SELECT provider, original_transaction_id
                  FROM subscriptions
                 WHERE original_transaction_id IS NOT NULL
                 GROUP BY provider, original_transaction_id
                HAVING count(*) > 1
                 LIMIT 1
                """
            )
        ).scalar()
        if duplicate:
            raise RuntimeError(
                "Cannot enforce subscription provider ownership: duplicate original transaction IDs exist."
            )
        unique_names = {
            constraint["name"]
            for constraint in sa.inspect(bind).get_unique_constraints("subscriptions")
        }
        if "uq_subscription_provider_original_transaction" not in unique_names:
            op.create_unique_constraint(
                "uq_subscription_provider_original_transaction",
                "subscriptions",
                ["provider", "original_transaction_id"],
            )
        if "ix_subscriptions_provider" not in _indexes(sa.inspect(bind), "subscriptions"):
            op.create_index("ix_subscriptions_provider", "subscriptions", ["provider"])
        if "ix_subscriptions_provider_state_updated_at" not in _indexes(
            sa.inspect(bind), "subscriptions"
        ):
            op.create_index(
                "ix_subscriptions_provider_state_updated_at",
                "subscriptions",
                ["provider_state_updated_at"],
            )

    if "entitlements" not in tables:
        return

    columns = _columns(inspector, "entitlements")
    if "purchase_id" not in columns:
        op.add_column("entitlements", sa.Column("purchase_id", sa.String(36), nullable=True))
    if "subscription_id" not in columns:
        op.add_column("entitlements", sa.Column("subscription_id", sa.String(36), nullable=True))

    # Legacy metadata is used only for deterministic provenance backfill. New code
    # writes relational links and never authorizes from metadata.
    if bind.dialect.name == "postgresql":
        op.execute(
            """
            UPDATE entitlements AS e
               SET purchase_id = p.id
              FROM purchases AS p
             WHERE e.purchase_id IS NULL
               AND e.source IN ('purchase', 'bundle')
               AND e.metadata_json ->> 'orderId' = p.order_id
            """
        )
        op.execute(
            """
            UPDATE entitlements AS e
               SET subscription_id = s.id
              FROM subscriptions AS s
             WHERE e.subscription_id IS NULL
               AND e.source IN ('subscription', 'trial')
               AND e.metadata_json ->> 'subscriptionId' = s.id
            """
        )
        op.execute(
            """
            INSERT INTO entitlements (
                id, learner_id, source, status, resource_type, resource_id,
                starts_at, expires_at, revoked_at, purchase_id, subscription_id,
                metadata_json, created_at, updated_at
            )
            SELECT
                substr(md5(e.id || ':' || course_id), 1, 8) || '-' ||
                substr(md5(e.id || ':' || course_id), 9, 4) || '-' ||
                substr(md5(e.id || ':' || course_id), 13, 4) || '-' ||
                substr(md5(e.id || ':' || course_id), 17, 4) || '-' ||
                substr(md5(e.id || ':' || course_id), 21, 12),
                e.learner_id, e.source, e.status, 'course', course_id,
                e.starts_at, e.expires_at, e.revoked_at, e.purchase_id, NULL,
                (e.metadata_json::jsonb - 'courseIds')::json, e.created_at, e.updated_at
              FROM entitlements AS e
              CROSS JOIN LATERAL json_array_elements_text(
                  COALESCE(e.metadata_json -> 'courseIds', '[]'::json)
              ) AS course_id
             WHERE e.source = 'bundle'
               AND e.resource_id IS NULL
            """
        )
        op.execute(
            """
            DELETE FROM entitlements
             WHERE source = 'bundle'
               AND resource_id IS NULL
            """
        )

    foreign_key_names = {
        constraint["name"] for constraint in sa.inspect(bind).get_foreign_keys("entitlements")
    }
    if "fk_entitlements_purchase_id" not in foreign_key_names:
        op.create_foreign_key(
            "fk_entitlements_purchase_id",
            "entitlements",
            "purchases",
            ["purchase_id"],
            ["id"],
            ondelete="CASCADE",
        )
    if "fk_entitlements_subscription_id" not in foreign_key_names:
        op.create_foreign_key(
            "fk_entitlements_subscription_id",
            "entitlements",
            "subscriptions",
            ["subscription_id"],
            ["id"],
            ondelete="CASCADE",
        )

    check_names = {
        constraint["name"] for constraint in sa.inspect(bind).get_check_constraints("entitlements")
    }
    if "ck_entitlement_single_commerce_source" not in check_names:
        op.create_check_constraint(
            "ck_entitlement_single_commerce_source",
            "entitlements",
            "NOT (purchase_id IS NOT NULL AND subscription_id IS NOT NULL)",
        )
    indexes = _indexes(sa.inspect(bind), "entitlements")
    if "ix_entitlements_purchase_id" not in indexes:
        op.create_index("ix_entitlements_purchase_id", "entitlements", ["purchase_id"])
    if "ix_entitlements_subscription_id" not in indexes:
        op.create_index("ix_entitlements_subscription_id", "entitlements", ["subscription_id"])


def downgrade():
    # Removing provenance would recreate the authorization ambiguity fixed here.
    raise RuntimeError("0005_p0_integrity is intentionally irreversible")
