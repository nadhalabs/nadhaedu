"""Phase 7B Commerce, Subscriptions, and Entitlement Integration.

Revision ID: 0003_commerce
Revises: 0002_operations
"""

import sqlalchemy as sa

from alembic import op

revision = "0003_commerce"
down_revision = "0002_operations"
branch_labels = None
depends_on = None


def upgrade():
    inspector = sa.inspect(op.get_bind())
    existing_tables = inspector.get_table_names()

    if "subscription_plans" not in existing_tables:
        op.create_table(
            "subscription_plans",
            sa.Column("id", sa.String(64), primary_key=True),
            sa.Column("tier", sa.String(30), nullable=False),
            sa.Column("billing_interval", sa.String(30), nullable=False),
            sa.Column("name", sa.String(120), nullable=False),
            sa.Column("description", sa.Text(), nullable=False, server_default=""),
            sa.Column("price_cents", sa.Integer(), nullable=False),
            sa.Column("formatted_price", sa.String(30), nullable=False),
            sa.Column("currency_code", sa.String(10), nullable=False, server_default="USD"),
            sa.Column("trial_days", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("introductory_offer_json", sa.JSON(), nullable=True),
            sa.Column("benefits", sa.JSON(), nullable=False),
            sa.Column("is_popular", sa.Boolean(), nullable=False, server_default=sa.false()),
            sa.Column("is_recommended", sa.Boolean(), nullable=False, server_default=sa.false()),
            sa.Column("savings_percent", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        )
        op.create_index("ix_subscription_plans_is_active", "subscription_plans", ["is_active"])

    if "commerce_products" not in existing_tables:
        op.create_table(
            "commerce_products",
            sa.Column("id", sa.String(64), primary_key=True),
            sa.Column("product_type", sa.String(30), nullable=False, server_default="course"),
            sa.Column(
                "course_id",
                sa.String(36),
                sa.ForeignKey("courses.id", ondelete="SET NULL"),
                nullable=True,
            ),
            sa.Column("bundle_id", sa.String(64), nullable=True),
            sa.Column("course_ids", sa.JSON(), nullable=False),
            sa.Column("title", sa.String(200), nullable=False),
            sa.Column("description", sa.Text(), nullable=False, server_default=""),
            sa.Column("price_cents", sa.Integer(), nullable=False),
            sa.Column("formatted_price", sa.String(30), nullable=False),
            sa.Column("currency_code", sa.String(10), nullable=False, server_default="USD"),
            sa.Column("original_price_cents", sa.Integer(), nullable=True),
            sa.Column("discount_percent", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("features", sa.JSON(), nullable=False),
            sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        )
        op.create_index("ix_commerce_products_course_id", "commerce_products", ["course_id"])
        op.create_index("ix_commerce_products_bundle_id", "commerce_products", ["bundle_id"])
        op.create_index("ix_commerce_products_is_active", "commerce_products", ["is_active"])

    if "provider_product_mappings" not in existing_tables:
        op.create_table(
            "provider_product_mappings",
            sa.Column("id", sa.String(36), primary_key=True),
            sa.Column("internal_product_type", sa.String(30), nullable=False),
            sa.Column("internal_product_id", sa.String(64), nullable=False),
            sa.Column("provider", sa.String(30), nullable=False),
            sa.Column("provider_product_id", sa.String(255), nullable=False),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
            sa.UniqueConstraint("provider", "provider_product_id", name="uq_provider_product"),
        )
        op.create_index(
            "ix_provider_mappings_internal",
            "provider_product_mappings",
            ["internal_product_id"],
        )

    if "payment_transactions" not in existing_tables:
        op.create_table(
            "payment_transactions",
            sa.Column("id", sa.String(36), primary_key=True),
            sa.Column(
                "learner_id",
                sa.String(36),
                sa.ForeignKey("users.id", ondelete="CASCADE"),
                nullable=False,
            ),
            sa.Column("provider", sa.String(30), nullable=False),
            sa.Column("provider_transaction_id", sa.String(255), nullable=False),
            sa.Column("idempotency_key", sa.String(120), nullable=True),
            sa.Column("status", sa.String(30), nullable=False, server_default="pending"),
            sa.Column("amount_cents", sa.Integer(), nullable=True),
            sa.Column("currency_code", sa.String(10), nullable=True),
            sa.Column("receipt_payload", sa.Text(), nullable=True),
            sa.Column("error_message", sa.Text(), nullable=True),
            sa.Column("raw_response_json", sa.JSON(), nullable=False),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
            sa.UniqueConstraint(
                "provider", "provider_transaction_id", name="uq_provider_transaction"
            ),
        )
        op.create_index("ix_payment_transactions_learner", "payment_transactions", ["learner_id"])
        op.create_index(
            "ix_payment_transactions_idemp", "payment_transactions", ["idempotency_key"]
        )

    if "purchases" not in existing_tables:
        op.create_table(
            "purchases",
            sa.Column("id", sa.String(36), primary_key=True),
            sa.Column(
                "learner_id",
                sa.String(36),
                sa.ForeignKey("users.id", ondelete="CASCADE"),
                nullable=False,
            ),
            sa.Column("product_id", sa.String(64), nullable=False),
            sa.Column("product_type", sa.String(30), nullable=False),
            sa.Column("order_id", sa.String(100), nullable=False, unique=True),
            sa.Column(
                "transaction_id",
                sa.String(36),
                sa.ForeignKey("payment_transactions.id", ondelete="SET NULL"),
                nullable=True,
            ),
            sa.Column("status", sa.String(30), nullable=False, server_default="completed"),
            sa.Column("purchased_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("amount_cents", sa.Integer(), nullable=True),
            sa.Column("currency_code", sa.String(10), nullable=True),
            sa.Column("metadata_json", sa.JSON(), nullable=False),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        )
        op.create_index("ix_purchases_learner", "purchases", ["learner_id"])
        op.create_index("ix_purchases_order_id", "purchases", ["order_id"], unique=True)
        op.create_index("ix_purchases_product_id", "purchases", ["product_id"])

    if "subscriptions" not in existing_tables:
        op.create_table(
            "subscriptions",
            sa.Column("id", sa.String(36), primary_key=True),
            sa.Column(
                "learner_id",
                sa.String(36),
                sa.ForeignKey("users.id", ondelete="CASCADE"),
                nullable=False,
            ),
            sa.Column("plan_id", sa.String(64), nullable=False),
            sa.Column("tier", sa.String(30), nullable=False),
            sa.Column("billing_interval", sa.String(30), nullable=False),
            sa.Column("status", sa.String(30), nullable=False, server_default="active"),
            sa.Column("current_period_start", sa.DateTime(timezone=True), nullable=False),
            sa.Column("current_period_end", sa.DateTime(timezone=True), nullable=False),
            sa.Column(
                "cancel_at_period_end", sa.Boolean(), nullable=False, server_default=sa.false()
            ),
            sa.Column("renews_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("trial_start_date", sa.DateTime(timezone=True), nullable=True),
            sa.Column("trial_end_date", sa.DateTime(timezone=True), nullable=True),
            sa.Column("trial_duration_days", sa.Integer(), nullable=True),
            sa.Column("introductory_price_cents", sa.Integer(), nullable=True),
            sa.Column("cancellation_reason", sa.String(500), nullable=True),
            sa.Column("original_transaction_id", sa.String(255), nullable=True),
            sa.Column("latest_transaction_id", sa.String(255), nullable=True),
            sa.Column("metadata_json", sa.JSON(), nullable=False),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        )
        op.create_index("ix_subscriptions_learner", "subscriptions", ["learner_id"])
        op.create_index("ix_subscriptions_plan_id", "subscriptions", ["plan_id"])
        op.create_index("ix_subscriptions_status", "subscriptions", ["status"])

    if "coupons" not in existing_tables:
        op.create_table(
            "coupons",
            sa.Column("id", sa.String(36), primary_key=True),
            sa.Column("code", sa.String(50), nullable=False, unique=True),
            sa.Column("discount_type", sa.String(30), nullable=False),
            sa.Column("discount_value", sa.Integer(), nullable=False),
            sa.Column("valid_from", sa.DateTime(timezone=True), nullable=False),
            sa.Column("valid_until", sa.DateTime(timezone=True), nullable=True),
            sa.Column("max_redemptions", sa.Integer(), nullable=True),
            sa.Column("redemption_count", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("applicable_product_ids", sa.JSON(), nullable=False),
            sa.Column("description", sa.String(255), nullable=True),
            sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        )
        op.create_index("ix_coupons_code", "coupons", ["code"], unique=True)
        op.create_index("ix_coupons_is_active", "coupons", ["is_active"])

    if "coupon_redemptions" not in existing_tables:
        op.create_table(
            "coupon_redemptions",
            sa.Column("id", sa.String(36), primary_key=True),
            sa.Column(
                "coupon_id",
                sa.String(36),
                sa.ForeignKey("coupons.id", ondelete="CASCADE"),
                nullable=False,
            ),
            sa.Column(
                "learner_id",
                sa.String(36),
                sa.ForeignKey("users.id", ondelete="CASCADE"),
                nullable=False,
            ),
            sa.Column("order_id", sa.String(100), nullable=True),
            sa.Column("redeemed_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
            sa.UniqueConstraint("coupon_id", "learner_id", name="uq_coupon_learner_redemption"),
        )
        op.create_index("ix_coupon_redemptions_learner", "coupon_redemptions", ["learner_id"])

    if "provider_events" not in existing_tables:
        op.create_table(
            "provider_events",
            sa.Column("id", sa.String(36), primary_key=True),
            sa.Column("provider", sa.String(30), nullable=False),
            sa.Column("event_id", sa.String(255), nullable=False),
            sa.Column("event_type", sa.String(100), nullable=False),
            sa.Column("payload_json", sa.JSON(), nullable=False),
            sa.Column("status", sa.String(30), nullable=False, server_default="pending"),
            sa.Column("occurred_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("processed_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("error_message", sa.Text(), nullable=True),
            sa.UniqueConstraint("provider", "event_id", name="uq_provider_event"),
        )
        op.create_index(
            "ix_provider_events_provider_event", "provider_events", ["provider", "event_id"]
        )
        op.create_index("ix_provider_events_status", "provider_events", ["status"])


def downgrade():
    inspector = sa.inspect(op.get_bind())
    existing = inspector.get_table_names()
    for table in [
        "provider_events",
        "coupon_redemptions",
        "coupons",
        "subscriptions",
        "purchases",
        "payment_transactions",
        "provider_product_mappings",
        "commerce_products",
        "subscription_plans",
    ]:
        if table in existing:
            op.drop_table(table)
