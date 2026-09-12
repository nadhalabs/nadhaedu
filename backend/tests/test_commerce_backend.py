import asyncio
import hashlib
import hmac
import time
import uuid
from datetime import UTC, datetime, timedelta

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool

from app.commerce_providers import StripePaymentVerifier
from app.commerce_services import (
    cancel_subscription_service,
    change_subscription_plan_service,
    process_provider_webhook,
)
from app.config import Settings
from app.errors import APIError
from app.main import app
from app.models import (
    Base,
    BillingInterval,
    CommerceProduct,
    CommerceProductType,
    Coupon,
    Course,
    DiscountType,
    Entitlement,
    EntitlementStatus,
    Lifecycle,
    PaymentProvider,
    PaymentTransaction,
    PolicyKind,
    ProviderProductMapping,
    Subscription,
    SubscriptionPlan,
    SubscriptionStatus,
    SubscriptionTier,
    User,
)
from app.security import hash_password


@pytest_asyncio.fixture(autouse=True)
async def setup_test_db():
    engine = create_async_engine(
        "sqlite+aiosqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    test_session = async_sessionmaker(engine, expire_on_commit=False)

    # Seed core commerce catalog
    async with test_session() as db:
        # 1. Course
        course1 = Course(
            id="course-1",
            title="Flutter Architecture Masterclass",
            subtitle="Clean code",
            description="Deep dive",
            level="intermediate",
            language_code="en",
            policy_kind=PolicyKind.premium,
            status=Lifecycle.published,
            published_at=datetime.now(UTC),
        )
        course2 = Course(
            id="course-2",
            title="Advanced Dart Patterns",
            subtitle="Functional programming",
            description="Master patterns",
            level="advanced",
            language_code="en",
            policy_kind=PolicyKind.premium,
            status=Lifecycle.published,
            published_at=datetime.now(UTC),
        )
        course3 = Course(
            id="course-3",
            title="Unrelated Premium Course",
            subtitle="Not in bundle",
            description="Must remain locked",
            level="advanced",
            language_code="en",
            policy_kind=PolicyKind.premium,
            status=Lifecycle.published,
            published_at=datetime.now(UTC),
        )
        db.add_all([course1, course2, course3])
        await db.flush()

        # 2. Subscription Plans
        plan_monthly = SubscriptionPlan(
            id="plan_pro_monthly",
            tier=SubscriptionTier.pro,
            billing_interval=BillingInterval.monthly,
            name="Pro Monthly",
            description="Unlimited access",
            price_cents=1499,
            formatted_price="$14.99",
            trial_days=7,
            benefits=["All courses", "Certificates"],
            is_popular=False,
            is_recommended=False,
            savings_percent=0,
        )
        plan_annual = SubscriptionPlan(
            id="plan_pro_annual",
            tier=SubscriptionTier.pro,
            billing_interval=BillingInterval.annual,
            name="Pro Annual",
            description="Best value",
            price_cents=11999,
            formatted_price="$119.99",
            trial_days=14,
            benefits=["All courses", "Certificates", "Priority support"],
            is_popular=True,
            is_recommended=True,
            savings_percent=33,
        )
        db.add_all([plan_monthly, plan_annual])

        # 3. Commercial Products
        c_prod = CommerceProduct(
            id="prod_course_1",
            product_type=CommerceProductType.course,
            course_id="course-1",
            title="Flutter Architecture Masterclass",
            description="Lifetime access",
            price_cents=4900,
            formatted_price="$49.00",
            features=["Lifetime updates", "Certificate"],
        )
        b_prod = CommerceProduct(
            id="prod_bundle_mobile",
            product_type=CommerceProductType.bundle,
            bundle_id="bundle_mobile_dev",
            course_ids=["course-1", "course-2"],
            title="Complete Mobile Engineering Bundle",
            description="Two master courses",
            price_cents=8900,
            formatted_price="$89.00",
            features=["2 courses", "Lifetime access"],
        )
        db.add_all([c_prod, b_prod])

        # 4. Provider Mappings
        m1 = ProviderProductMapping(
            internal_product_type="plan",
            internal_product_id="plan_pro_monthly",
            provider=PaymentProvider.mock,
            provider_product_id="com.learningplatform.subscription.pro.monthly",
        )
        m2 = ProviderProductMapping(
            internal_product_type="course",
            internal_product_id="prod_course_1",
            provider=PaymentProvider.mock,
            provider_product_id="com.learningplatform.course.flutter_arch",
        )
        m3 = ProviderProductMapping(
            internal_product_type="plan",
            internal_product_id="plan_pro_annual",
            provider=PaymentProvider.mock,
            provider_product_id="com.learningplatform.subscription.pro.annual",
        )
        m4 = ProviderProductMapping(
            internal_product_type="bundle",
            internal_product_id="prod_bundle_mobile",
            provider=PaymentProvider.mock,
            provider_product_id="com.learningplatform.bundle.mobile_arch",
        )
        db.add_all([m1, m2, m3, m4])

        # 5. Coupons
        c1 = Coupon(
            code="SAVE20",
            discount_type=DiscountType.percentage,
            discount_value=20,
            valid_from=datetime.now(UTC) - timedelta(days=1),
            valid_until=datetime.now(UTC) + timedelta(days=30),
            description="20% off promotion",
        )
        c2 = Coupon(
            code="EXPIRED10",
            discount_type=DiscountType.percentage,
            discount_value=10,
            valid_from=datetime.now(UTC) - timedelta(days=30),
            valid_until=datetime.now(UTC) - timedelta(days=1),
            description="Expired coupon",
        )
        c3 = Coupon(
            code="COURSEONLY",
            discount_type=DiscountType.fixed_amount,
            discount_value=500,
            valid_from=datetime.now(UTC) - timedelta(days=1),
            valid_until=datetime.now(UTC) + timedelta(days=30),
            applicable_product_ids=["prod_course_1"],
            description="$5 off course 1",
        )
        db.add_all([c1, c2, c3])

        # 6. Test Users
        user1 = User(
            id="test-learner-1",
            email="learner1@example.com",
            password_hash=hash_password("password12345"),
            display_name="Learner One",
            onboarding_complete=True,
        )
        user2 = User(
            id="test-learner-2",
            email="learner2@example.com",
            password_hash=hash_password("password12345"),
            display_name="Learner Two",
            onboarding_complete=True,
        )
        db.add_all([user1, user2])
        await db.commit()

    # Override app session factory with in-memory test session
    import app.dependencies as dep_mod

    async def override_get_session():
        async with test_session() as s:
            yield s

    app.dependency_overrides[dep_mod.get_session] = override_get_session

    yield test_session

    app.dependency_overrides.clear()
    await engine.dispose()


async def get_auth_token(client: AsyncClient, email: str = "learner1@example.com") -> str:
    res = await client.post(
        "/api/v1/auth/login",
        json={"email": email, "password": "password12345"},
    )
    return res.json()["accessToken"]


@pytest.mark.asyncio
async def test_get_subscription_plans_and_products():
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://testserver"
    ) as client:
        # Plans
        plans_res = await client.get("/api/v1/commerce/plans")
        assert plans_res.status_code == 200
        plans = plans_res.json()["items"]
        assert len(plans) >= 2
        monthly = next(p for p in plans if p["id"] == "plan_pro_monthly")
        assert monthly["tier"] == "pro"
        assert monthly["billingInterval"] == "monthly"
        assert monthly["priceCents"] == 1499
        assert monthly["trialDays"] == 7
        assert monthly["storeProductId"] == "com.learningplatform.subscription.pro.monthly"

        # Courses
        courses_res = await client.get("/api/v1/commerce/products/courses")
        assert courses_res.status_code == 200
        courses = courses_res.json()["items"]
        assert len(courses) >= 1
        assert courses[0]["id"] == "prod_course_1"
        assert courses[0]["courseId"] == "course-1"

        # Bundles
        bundles_res = await client.get("/api/v1/commerce/products/bundles")
        assert bundles_res.status_code == 200
        bundles = bundles_res.json()["items"]
        assert len(bundles) >= 1
        assert "course-1" in bundles[0]["courseIds"]
        assert "course-2" in bundles[0]["courseIds"]


@pytest.mark.asyncio
async def test_rating_pagination_uses_rating_keyset_without_duplicates():
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://testserver"
    ) as client:
        first = await client.get("/api/v1/courses?sort=rating&pageSize=1")
        assert first.status_code == 200
        first_data = first.json()
        assert first_data["nextCursor"] is not None

        second = await client.get(
            "/api/v1/courses",
            params={"sort": "rating", "pageSize": 1, "cursor": first_data["nextCursor"]},
        )
        assert second.status_code == 200
        assert second.json()["items"][0]["id"] != first_data["items"][0]["id"]


@pytest.mark.asyncio
async def test_coupon_validation_rules():
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://testserver"
    ) as client:
        # Valid coupon
        v1 = await client.post("/api/v1/commerce/coupons/validate", json={"code": "save20"})
        assert v1.status_code == 200
        assert v1.json()["valid"] is True
        assert v1.json()["discountType"] == "percentage"
        assert v1.json()["discountValue"] == 20

        # Expired coupon
        v2 = await client.post("/api/v1/commerce/coupons/validate", json={"code": "EXPIRED10"})
        assert v2.status_code == 200
        assert v2.json()["valid"] is False

        # Non-existent coupon
        v3 = await client.post("/api/v1/commerce/coupons/validate", json={"code": "DOESNOTEXIST"})
        assert v3.status_code == 200
        assert v3.json()["valid"] is False

        # Product-restricted coupon: matches
        v4 = await client.post(
            "/api/v1/commerce/coupons/validate",
            json={"code": "COURSEONLY", "productId": "prod_course_1"},
        )
        assert v4.status_code == 200
        assert v4.json()["valid"] is True

        # Product-restricted coupon: mismatched product
        v5 = await client.post(
            "/api/v1/commerce/coupons/validate",
            json={"code": "COURSEONLY", "productId": "plan_pro_monthly"},
        )
        assert v5.status_code == 200
        assert v5.json()["valid"] is False


@pytest.mark.asyncio
async def test_subscription_transaction_verification_and_entitlement_flow():
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://testserver"
    ) as client:
        token = await get_auth_token(client, "learner1@example.com")
        headers = {
            "Authorization": f"Bearer {token}",
            "Idempotency-Key": "idemp_sub_001",
        }

        # 1. Before purchase: course-1 is locked
        decision_before = await client.get(
            "/api/v1/access-decisions/course/course-1", headers=headers
        )
        assert decision_before.json()["allowed"] is False
        assert decision_before.json()["accessLevel"] == "locked"

        # 2. Verify subscription transaction
        tx_body = {
            "transactionId": "tx_local_001",
            "provider": "mock",
            "providerTransactionId": "com.learningplatform.subscription.pro.monthly",
            "receiptPayload": "com.learningplatform.subscription.pro.monthly valid_receipt",
            "amountCents": 1499,
            "currencyCode": "USD",
            "learnerId": "test-learner-1",
            "couponCode": "SAVE20",
        }
        res = await client.post(
            "/api/v1/commerce/transactions/verify",
            json=tx_body,
            headers=headers,
        )
        assert res.status_code == 200
        data = res.json()
        assert data["verified"] is True
        assert data["subscription"] is not None
        assert data["subscription"]["planId"] == "plan_pro_monthly"
        assert len(data["grantedEntitlements"]) >= 1

        # 3. After purchase: course-1 and course-2 are unlocked via active subscription!
        decision_after = await client.get(
            "/api/v1/access-decisions/course/course-1", headers=headers
        )
        assert decision_after.json()["allowed"] is True
        assert decision_after.json()["reason"] in ("ACTIVE_SUBSCRIPTION", "TRIAL_ACCESS")

        # 4. Check active subscription endpoint
        active_sub_res = await client.get("/api/v1/commerce/subscriptions/active", headers=headers)
        assert active_sub_res.status_code == 200
        assert active_sub_res.json()["subscription"]["planId"] == "plan_pro_monthly"


@pytest.mark.asyncio
async def test_course_purchase_verification_and_perpetual_entitlement():
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://testserver"
    ) as client:
        token = await get_auth_token(client, "learner2@example.com")
        headers = {
            "Authorization": f"Bearer {token}",
            "Idempotency-Key": "idemp_course_pur_001",
        }

        # Verify course purchase transaction
        tx_body = {
            "transactionId": "tx_course_local_002",
            "provider": "mock",
            "providerTransactionId": "com.learningplatform.course.flutter_arch",
            "receiptPayload": "com.learningplatform.course.flutter_arch receipt_ok",
            "learnerId": "test-learner-2",
        }
        res = await client.post(
            "/api/v1/commerce/transactions/verify",
            json=tx_body,
            headers=headers,
        )
        assert res.status_code == 200
        data = res.json()
        assert data["verified"] is True
        assert data["purchase"] is not None
        assert data["purchase"]["productId"] == "prod_course_1"
        assert data["purchase"]["productType"] == "course"

        # Check course-1 access is granted with PURCHASED reason
        decision = await client.get("/api/v1/access-decisions/course/course-1", headers=headers)
        assert decision.json()["allowed"] is True
        assert decision.json()["accessLevel"] == "purchased"

        # Check course-2 remains locked
        decision2 = await client.get("/api/v1/access-decisions/course/course-2", headers=headers)
        assert decision2.json()["allowed"] is False


@pytest.mark.asyncio
async def test_invalid_transaction_fails_closed_and_grants_no_entitlements():
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://testserver"
    ) as client:
        token = await get_auth_token(client, "learner1@example.com")
        headers = {"Authorization": f"Bearer {token}"}

        # Send invalid receipt payload
        tx_body = {
            "transactionId": "tx_fraud_001",
            "provider": "mock",
            "providerTransactionId": "tx_fraud_token_001",
            "receiptPayload": "INVALID_FORGED_RECEIPT_TOKEN",
            "learnerId": "test-learner-1",
        }
        res = await client.post(
            "/api/v1/commerce/transactions/verify",
            json=tx_body,
            headers=headers,
        )
        assert res.status_code == 200
        data = res.json()
        assert data["verified"] is False
        assert data["purchase"] is None
        assert data["subscription"] is None
        assert data["grantedEntitlements"] == []


@pytest.mark.asyncio
async def test_idempotent_duplicate_submission_and_cross_user_rejection():
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://testserver"
    ) as client:
        token1 = await get_auth_token(client, "learner1@example.com")
        headers1 = {
            "Authorization": f"Bearer {token1}",
            "Idempotency-Key": "idemp_duplicate_test_key",
        }

        tx_body = {
            "transactionId": "tx_idemp_001",
            "provider": "mock",
            "providerTransactionId": "com.learningplatform.subscription.pro.annual",
            "receiptPayload": "com.learningplatform.subscription.pro.annual valid",
            "learnerId": "test-learner-1",
        }

        # First request
        res1 = await client.post(
            "/api/v1/commerce/transactions/verify",
            json=tx_body,
            headers=headers1,
        )
        assert res1.status_code == 200
        sub_id = res1.json()["subscription"]["id"]

        # Exact duplicate with same Idempotency-Key returns cached response
        res2 = await client.post(
            "/api/v1/commerce/transactions/verify",
            json=tx_body,
            headers=headers1,
        )
        assert res2.status_code == 200
        assert res2.json()["subscription"]["id"] == sub_id

        # Same Idempotency-Key with conflicting body returns 409 conflict
        conflicting_body = dict(tx_body)
        conflicting_body["transactionId"] = "different_tx_id"
        res_conflict = await client.post(
            "/api/v1/commerce/transactions/verify",
            json=conflicting_body,
            headers=headers1,
        )
        assert res_conflict.status_code == 409

        # Cross-user transaction claim rejection
        token2 = await get_auth_token(client, "learner2@example.com")
        headers2 = {"Authorization": f"Bearer {token2}"}
        cross_user_body = dict(tx_body)
        cross_user_body["learnerId"] = "test-learner-1"  # trying to act as learner1

        res_cross = await client.post(
            "/api/v1/commerce/transactions/verify",
            json=cross_user_body,
            headers=headers2,
        )
        assert res_cross.status_code == 403


@pytest.mark.asyncio
async def test_multi_grant_entitlement_coexistence_and_revocation():
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://testserver"
    ) as client:
        token = await get_auth_token(client, "learner1@example.com")
        headers = {"Authorization": f"Bearer {token}"}

        # 1. Purchase course-1 individually
        await client.post(
            "/api/v1/commerce/transactions/verify",
            json={
                "transactionId": "tx_multi_course_1",
                "provider": "mock",
                "providerTransactionId": "com.learningplatform.course.flutter_arch",
                "learnerId": "test-learner-1",
            },
            headers=headers,
        )

        # 2. Subscribe to Pro Annual
        sub_res = await client.post(
            "/api/v1/commerce/transactions/verify",
            json={
                "transactionId": "tx_multi_sub_1",
                "provider": "mock",
                "providerTransactionId": "com.learningplatform.subscription.pro.annual",
                "learnerId": "test-learner-1",
            },
            headers=headers,
        )
        assert sub_res.json()["subscription"]["id"]

        # Both course-1 and course-2 accessible
        assert (
            await client.get("/api/v1/access-decisions/course/course-1", headers=headers)
        ).json()["allowed"] is True
        assert (
            await client.get("/api/v1/access-decisions/course/course-2", headers=headers)
        ).json()["allowed"] is True

        # 3. Simulate subscription refund/revocation via provider webhook
        webhook_body = {
            "eventId": f"evt_revocation_{uuid.uuid4().hex[:8]}",
            "eventType": "REVOCATION",
            "transactionId": "com.learningplatform.subscription.pro.annual",
            "originalTransactionId": "com.learningplatform.subscription.pro.annual",
        }
        wb_res = await client.post("/api/v1/commerce/webhooks/mock", json=webhook_body)
        assert wb_res.status_code == 200

        # Multi-grant invariant verification:
        # course-1 STILL accessible because of perpetual individual purchase!
        d1 = await client.get("/api/v1/access-decisions/course/course-1", headers=headers)
        assert d1.json()["allowed"] is True
        assert d1.json()["accessLevel"] == "purchased"

        # course-2 (only covered by subscription) is now locked!
        d2 = await client.get("/api/v1/access-decisions/course/course-2", headers=headers)
        assert d2.json()["allowed"] is False


@pytest.mark.asyncio
async def test_subscription_cancellation_and_plan_change():
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://testserver"
    ) as client:
        token = await get_auth_token(client, "learner1@example.com")
        headers = {"Authorization": f"Bearer {token}"}

        # Subscribe
        sub_res = await client.post(
            "/api/v1/commerce/transactions/verify",
            json={
                "transactionId": "tx_lifecycle_001",
                "provider": "mock",
                "providerTransactionId": "com.learningplatform.subscription.pro.monthly",
                "learnerId": "test-learner-1",
            },
            headers=headers,
        )
        sub_id = sub_res.json()["subscription"]["id"]

        # Change plan to Pro Annual
        change_res = await client.post(
            f"/api/v1/commerce/subscriptions/{sub_id}/change-plan",
            json={"learnerId": "test-learner-1", "newPlanId": "plan_pro_annual"},
            headers=headers,
        )
        assert change_res.status_code == 200
        assert change_res.json()["subscription"]["planId"] == "plan_pro_annual"

        # Cancel subscription
        cancel_res = await client.post(
            f"/api/v1/commerce/subscriptions/{sub_id}/cancel",
            json={"learnerId": "test-learner-1", "reason": "Too expensive"},
            headers=headers,
        )
        assert cancel_res.status_code == 200
        assert cancel_res.json()["subscription"]["cancelAtPeriodEnd"] is True
        assert cancel_res.json()["subscription"]["cancellationReason"] == "Too expensive"

        # Still entitled until period end
        d = await client.get("/api/v1/access-decisions/course/course-1", headers=headers)
        assert d.json()["allowed"] is True


@pytest.mark.asyncio
async def test_restore_purchases_reconciliation(setup_test_db):
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://testserver"
    ) as client:
        token = await get_auth_token(client, "learner2@example.com")
        headers = {"Authorization": f"Bearer {token}"}

        restore_res = await client.post(
            "/api/v1/commerce/restore",
            json={
                "learnerId": "test-learner-2",
                "transactions": [
                    {
                        "transactionId": "tx_restored_001",
                        "provider": "mock",
                        "providerTransactionId": "com.learningplatform.subscription.pro.annual",
                        "receiptPayload": "com.learningplatform.subscription.pro.annual valid",
                    }
                ],
            },
            headers=headers,
        )
        assert restore_res.status_code == 200
        data = restore_res.json()
        assert data["success"] is True
        assert data["restoredCount"] == 1
        assert len(data["restoredEntitlements"]) == 1
        async with setup_test_db() as verification_db:
            restored = await verification_db.scalar(
                select(Subscription).where(
                    Subscription.learner_id == "test-learner-2",
                    Subscription.original_transaction_id
                    == "com.learningplatform.subscription.pro.annual",
                )
            )
            assert restored is not None


@pytest.mark.asyncio
async def test_webhook_renewal_and_idempotent_replay():
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://testserver"
    ) as client:
        token = await get_auth_token(client, "learner1@example.com")
        headers = {"Authorization": f"Bearer {token}"}

        # Subscribe first
        await client.post(
            "/api/v1/commerce/transactions/verify",
            json={
                "transactionId": "tx_webhook_test_001",
                "provider": "mock",
                "providerTransactionId": "com.learningplatform.subscription.pro.monthly",
                "learnerId": "test-learner-1",
            },
            headers=headers,
        )

        event_id = f"evt_renew_{uuid.uuid4().hex[:10]}"
        webhook_payload = {
            "eventId": event_id,
            "eventType": "RENEWAL",
            "transactionId": "tx_renew_002",
            "originalTransactionId": "com.learningplatform.subscription.pro.monthly",
        }

        # First webhook delivery
        wb_res1 = await client.post("/api/v1/commerce/webhooks/mock", json=webhook_payload)
        assert wb_res1.status_code == 200
        assert wb_res1.json()["status"] == "processed"

        # Duplicate replay of exact same event
        wb_res2 = await client.post("/api/v1/commerce/webhooks/mock", json=webhook_payload)
        assert wb_res2.status_code == 200
        assert wb_res2.json()["idempotent"] is True


@pytest.mark.asyncio
async def test_bundle_purchase_and_entitlements():
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://testserver"
    ) as client:
        token = await get_auth_token(client, "learner2@example.com")
        headers = {"Authorization": f"Bearer {token}"}

        tx_body = {
            "transactionId": "tx_bundle_001",
            "provider": "mock",
            "providerTransactionId": "com.learningplatform.bundle.mobile_arch",
            "receiptPayload": "com.learningplatform.bundle.mobile_arch valid",
            "learnerId": "test-learner-2",
        }
        res = await client.post(
            "/api/v1/commerce/transactions/verify",
            json=tx_body,
            headers=headers,
        )
        assert res.status_code == 200
        data = res.json()
        assert data["verified"] is True
        assert data["purchase"]["productType"] == "bundle"
        assert len(data["grantedEntitlements"]) >= 1
        assert data["grantedEntitlements"][0]["source"]["type"] == "bundle"

        unrelated = await client.get("/api/v1/access-decisions/course/course-3", headers=headers)
        assert unrelated.status_code == 200
        assert unrelated.json()["allowed"] is False

        # Purchases list
        purchases_res = await client.get("/api/v1/commerce/purchases", headers=headers)
        assert purchases_res.status_code == 200
        assert len(purchases_res.json()["items"]) >= 1


@pytest.mark.asyncio
async def test_fail_closed_unconfigured_provider_in_production():
    from app.commerce_providers import AppleStoreKitVerifier

    prod_settings = Settings(
        environment="production",
        database_url="postgresql+asyncpg://mock:mock@localhost:5432/mock",
        jwt_secret="test_secret_32_bytes_long_exact_secret",
        public_base_url="https://api.example.com",
    )
    verifier = AppleStoreKitVerifier(prod_settings)
    with pytest.raises(APIError) as exc_info:
        await verifier.verify_transaction(
            provider_transaction_id="any_tx",
            receipt_payload="any_receipt",
        )
    assert exc_info.value.status == 503
    assert exc_info.value.code == "PROVIDER_UNAVAILABLE"


@pytest.mark.asyncio
async def test_real_provider_name_never_delegates_to_mock_in_test():
    from app.commerce_providers import AppleStoreKitVerifier

    verifier = AppleStoreKitVerifier(Settings(environment="test"))
    with pytest.raises(APIError) as exc_info:
        await verifier.verify_transaction(
            provider_transaction_id="com.learningplatform.subscription.pro.monthly",
            receipt_payload="com.learningplatform.subscription.pro.monthly valid",
        )
    assert exc_info.value.status == 503
    assert exc_info.value.code == "PROVIDER_UNAVAILABLE"


@pytest.mark.asyncio
async def test_admin_reconciliation_endpoint(setup_test_db):
    from app.models import UserRole

    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://testserver"
    ) as client:
        # Create an admin user in test session
        async with setup_test_db() as db:
            admin = User(
                id="admin-recon-1",
                email="admin_recon@example.com",
                password_hash=hash_password("adminpassword123"),
                display_name="Admin Recon",
                role=UserRole.admin,
                onboarding_complete=True,
            )
            db.add(admin)
            await db.commit()

        login_res = await client.post(
            "/api/v1/auth/login",
            json={"email": "admin_recon@example.com", "password": "adminpassword123"},
        )
        assert login_res.status_code == 200
        admin_token = login_res.json()["accessToken"]
        admin_headers = {"Authorization": f"Bearer {admin_token}"}

        recon_res = await client.post("/api/v1/admin/commerce/reconcile", headers=admin_headers)
        assert recon_res.status_code == 200
        assert "reconciledCount" in recon_res.json()


@pytest.mark.asyncio
async def test_concurrent_distinct_transaction_verifications():
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://testserver"
    ) as client:
        token1 = await get_auth_token(client, "learner1@example.com")
        token2 = await get_auth_token(client, "learner2@example.com")

        tx_body1 = {
            "transactionId": "tx_concurrent_001",
            "provider": "mock",
            "providerTransactionId": "com.learningplatform.subscription.pro.monthly",
            "receiptPayload": "com.learningplatform.subscription.pro.monthly valid",
            "learnerId": "test-learner-1",
        }
        tx_body2 = {
            "transactionId": "tx_concurrent_002",
            "provider": "mock",
            "providerTransactionId": "com.learningplatform.course.flutter_arch",
            "receiptPayload": "com.learningplatform.course.flutter_arch valid",
            "learnerId": "test-learner-2",
        }

        res1, res2 = await asyncio.gather(
            client.post(
                "/api/v1/commerce/transactions/verify",
                json=tx_body1,
                headers={
                    "Authorization": f"Bearer {token1}",
                    "Idempotency-Key": "key_concurrent_1",
                },
            ),
            client.post(
                "/api/v1/commerce/transactions/verify",
                json=tx_body2,
                headers={
                    "Authorization": f"Bearer {token2}",
                    "Idempotency-Key": "key_concurrent_2",
                },
            ),
        )

        assert res1.status_code == 200
        assert res2.status_code == 200
        assert res1.json()["verified"] is True
        assert res2.json()["verified"] is True


@pytest.mark.asyncio
async def test_unauthorized_subscription_management_rejections():
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://testserver"
    ) as client:
        token1 = await get_auth_token(client, "learner1@example.com")
        token2 = await get_auth_token(client, "learner2@example.com")

        # Learner 1 subscribes
        sub_res = await client.post(
            "/api/v1/commerce/transactions/verify",
            json={
                "transactionId": "tx_ownership_001",
                "provider": "mock",
                "providerTransactionId": "com.learningplatform.subscription.pro.monthly",
                "learnerId": "test-learner-1",
            },
            headers={"Authorization": f"Bearer {token1}"},
        )
        sub_id = sub_res.json()["subscription"]["id"]

        # Learner 2 attempts to cancel Learner 1's subscription -> 403 Forbidden
        cancel_unauth = await client.post(
            f"/api/v1/commerce/subscriptions/{sub_id}/cancel",
            json={"learnerId": "test-learner-2", "reason": "Malicious cancellation"},
            headers={"Authorization": f"Bearer {token2}"},
        )
        assert cancel_unauth.status_code == 403

        # Learner 2 attempts to change Learner 1's plan -> 403 Forbidden
        change_unauth = await client.post(
            f"/api/v1/commerce/subscriptions/{sub_id}/change-plan",
            json={"learnerId": "test-learner-2", "newPlanId": "plan_pro_annual"},
            headers={"Authorization": f"Bearer {token2}"},
        )
        assert change_unauth.status_code == 403


@pytest.mark.asyncio
async def test_real_provider_subscription_mutations_fail_closed(setup_test_db):
    async with setup_test_db() as db:
        sub = Subscription(
            learner_id="test-learner-1",
            provider=PaymentProvider.stripe,
            plan_id="plan_pro_monthly",
            tier=SubscriptionTier.pro,
            billing_interval=BillingInterval.monthly,
            status=SubscriptionStatus.active,
            current_period_start=datetime.now(UTC),
            current_period_end=datetime.now(UTC) + timedelta(days=30),
            original_transaction_id=f"stripe_{uuid.uuid4().hex}",
        )
        db.add(sub)
        await db.commit()

        production = Settings(environment="production")
        with pytest.raises(APIError) as cancel_error:
            await cancel_subscription_service(db, "test-learner-1", sub.id, "requested", production)
        assert cancel_error.value.code == "PROVIDER_OPERATION_UNAVAILABLE"
        with pytest.raises(APIError) as change_error:
            await change_subscription_plan_service(
                db,
                "test-learner-1",
                sub.id,
                "plan_pro_annual",
                settings=production,
            )
        assert change_error.value.code == "PROVIDER_OPERATION_UNAVAILABLE"
        await db.refresh(sub)
        assert sub.cancel_at_period_end is False
        assert sub.plan_id == "plan_pro_monthly"


@pytest.mark.asyncio
async def test_valid_stripe_webhook_signature_produces_verified_reconciliation_event():
    secret = "whsec_test_secret"
    body = b'{"id":"evt_1","type":"invoice.paid","created":1,"data":{"object":{"id":"in_1","subscription":"sub_1","payment_intent":"pi_1","metadata":{"product_id":"plan_pro_monthly"}}}}'
    timestamp = str(int(time.time()))
    signature = hmac.new(
        secret.encode(), f"{timestamp}.".encode() + body, hashlib.sha256
    ).hexdigest()
    verifier = StripePaymentVerifier(
        Settings(environment="test", stripe_api_key="sk_test", stripe_webhook_secret=secret)
    )

    event = await verifier.parse_and_verify_webhook(
        {"stripe-signature": f"t={timestamp},v1={signature}"}, body
    )

    assert event.event_id == "evt_1"
    assert event.event_type == "RENEWAL"
    assert event.provider_transaction_id == "pi_1"
    assert event.original_transaction_id == "sub_1"


@pytest.mark.asyncio
async def test_webhook_without_original_id_cannot_match_null_subscriptions(setup_test_db):
    async with setup_test_db() as db:
        sub = Subscription(
            learner_id="test-learner-1",
            provider=PaymentProvider.mock,
            plan_id="plan_pro_monthly",
            tier=SubscriptionTier.pro,
            billing_interval=BillingInterval.monthly,
            status=SubscriptionStatus.active,
            current_period_start=datetime.now(UTC),
            current_period_end=datetime.now(UTC) + timedelta(days=30),
            original_transaction_id=None,
            latest_transaction_id=None,
        )
        db.add(sub)
        await db.commit()
        body = (
            b'{"eventId":"evt_missing_original","eventType":"EXPIRATION",'
            b'"transactionId":"unrelated","originalTransactionId":null}'
        )

        result = await process_provider_webhook(db, "mock", {}, body, Settings(environment="test"))

        await db.refresh(sub)
        assert result["status"] == "processed"
        assert sub.status == SubscriptionStatus.active


@pytest.mark.asyncio
async def test_coupon_max_redemption_exhaustion(setup_test_db):
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://testserver"
    ) as client:
        token1 = await get_auth_token(client, "learner1@example.com")
        await get_auth_token(client, "learner2@example.com")

        # Create a coupon with max_redemptions = 1
        async with setup_test_db() as db:
            coupon = Coupon(
                code="LIMITED1",
                discount_type=DiscountType.percentage,
                discount_value=50,
                valid_from=datetime.now(UTC) - timedelta(days=1),
                valid_until=datetime.now(UTC) + timedelta(days=30),
                max_redemptions=1,
                description="Only 1 redemption permitted",
            )
            db.add(coupon)
            await db.commit()

        # Check validity initially -> True
        v1 = await client.post("/api/v1/commerce/coupons/validate", json={"code": "LIMITED1"})
        assert v1.status_code == 200
        assert v1.json()["valid"] is True

        # First redemption by learner 1
        tx1 = await client.post(
            "/api/v1/commerce/transactions/verify",
            json={
                "transactionId": "tx_coupon_burn_001",
                "provider": "mock",
                "providerTransactionId": "com.learningplatform.subscription.pro.monthly",
                "learnerId": "test-learner-1",
                "couponCode": "LIMITED1",
            },
            headers={"Authorization": f"Bearer {token1}"},
        )
        assert tx1.status_code == 200

        # Check validity now -> False (exhausted)
        v2 = await client.post("/api/v1/commerce/coupons/validate", json={"code": "LIMITED1"})
        assert v2.status_code == 200
        assert v2.json()["valid"] is False


@pytest.mark.asyncio
async def test_restore_empty_transactions():
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://testserver"
    ) as client:
        token = await get_auth_token(client, "learner1@example.com")
        res = await client.post(
            "/api/v1/commerce/restore",
            json={"learnerId": "test-learner-1", "transactions": []},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert res.status_code == 200
        assert res.json()["success"] is True


@pytest.mark.asyncio
async def test_unknown_verified_provider_product_fails_closed(setup_test_db):
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://testserver"
    ) as client:
        token = await get_auth_token(client, "learner1@example.com")
        response = await client.post(
            "/api/v1/commerce/transactions/verify",
            json={
                "transactionId": "tx_unknown_product",
                "provider": "mock",
                "providerTransactionId": "com.learningplatform.unknown.premium",
                "receiptPayload": "com.learningplatform.unknown.premium valid",
                "learnerId": "test-learner-1",
            },
            headers={"Authorization": f"Bearer {token}"},
        )
        assert response.status_code == 422
        assert response.json()["error"]["code"] == "UNKNOWN_PROVIDER_PRODUCT"

    async with setup_test_db() as db:
        transaction = await db.scalar(
            select(PaymentTransaction).where(
                PaymentTransaction.provider_transaction_id == "com.learningplatform.unknown.premium"
            )
        )
        assert transaction is None


@pytest.mark.asyncio
async def test_commerce_entitlements_have_relational_provenance(setup_test_db):
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://testserver"
    ) as client:
        token = await get_auth_token(client, "learner1@example.com")
        headers = {"Authorization": f"Bearer {token}"}
        purchase_response = await client.post(
            "/api/v1/commerce/transactions/verify",
            json={
                "transactionId": "tx_linked_purchase",
                "provider": "mock",
                "providerTransactionId": "com.learningplatform.course.flutter_arch",
                "learnerId": "test-learner-1",
            },
            headers=headers,
        )
        subscription_response = await client.post(
            "/api/v1/commerce/transactions/verify",
            json={
                "transactionId": "tx_linked_subscription",
                "provider": "mock",
                "providerTransactionId": "com.learningplatform.subscription.pro.annual",
                "learnerId": "test-learner-1",
            },
            headers=headers,
        )
        assert purchase_response.status_code == subscription_response.status_code == 200

    async with setup_test_db() as db:
        purchase_id = purchase_response.json()["purchase"]["id"]
        subscription_id = subscription_response.json()["subscription"]["id"]
        purchase_entitlements = (
            await db.scalars(select(Entitlement).where(Entitlement.purchase_id == purchase_id))
        ).all()
        subscription_entitlements = (
            await db.scalars(
                select(Entitlement).where(Entitlement.subscription_id == subscription_id)
            )
        ).all()
        assert purchase_entitlements and subscription_entitlements
        assert all(e.subscription_id is None for e in purchase_entitlements)
        assert all(e.purchase_id is None for e in subscription_entitlements)


@pytest.mark.asyncio
async def test_purchase_refund_revokes_only_linked_entitlements(setup_test_db):
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://testserver"
    ) as client:
        token = await get_auth_token(client, "learner2@example.com")
        headers = {"Authorization": f"Bearer {token}"}
        purchase = await client.post(
            "/api/v1/commerce/transactions/verify",
            json={
                "transactionId": "tx_refund_course",
                "provider": "mock",
                "providerTransactionId": "com.learningplatform.course.flutter_arch",
                "learnerId": "test-learner-2",
            },
            headers=headers,
        )
        assert purchase.status_code == 200
        purchase_id = purchase.json()["purchase"]["id"]
        refund = await client.post(
            "/api/v1/commerce/webhooks/mock",
            json={
                "eventId": "evt_refund_course",
                "eventType": "REFUND",
                "transactionId": "com.learningplatform.course.flutter_arch",
            },
        )
        assert refund.status_code == 200
        decision = await client.get("/api/v1/access-decisions/course/course-1", headers=headers)
        assert decision.json()["allowed"] is False

    async with setup_test_db() as db:
        entitlements = (
            await db.scalars(select(Entitlement).where(Entitlement.purchase_id == purchase_id))
        ).all()
        assert entitlements
        assert all(e.status == EntitlementStatus.revoked for e in entitlements)


@pytest.mark.asyncio
async def test_webhook_mutates_only_target_subscription(setup_test_db):
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://testserver"
    ) as client:
        token = await get_auth_token(client, "learner1@example.com")
        headers = {"Authorization": f"Bearer {token}"}
        subscription_ids = []
        for suffix, product in (
            ("monthly", "com.learningplatform.subscription.pro.monthly"),
            ("annual", "com.learningplatform.subscription.pro.annual"),
        ):
            response = await client.post(
                "/api/v1/commerce/transactions/verify",
                json={
                    "transactionId": f"tx_isolated_{suffix}",
                    "provider": "mock",
                    "providerTransactionId": product,
                    "learnerId": "test-learner-1",
                },
                headers=headers,
            )
            assert response.status_code == 200
            subscription_ids.append(response.json()["subscription"]["id"])

        revoked = await client.post(
            "/api/v1/commerce/webhooks/mock",
            json={
                "eventId": "evt_isolated_annual",
                "eventType": "REVOCATION",
                "transactionId": "com.learningplatform.subscription.pro.annual",
                "originalTransactionId": "com.learningplatform.subscription.pro.annual",
            },
        )
        assert revoked.status_code == 200

    async with setup_test_db() as db:
        monthly = (
            await db.scalars(
                select(Entitlement).where(Entitlement.subscription_id == subscription_ids[0])
            )
        ).all()
        annual = (
            await db.scalars(
                select(Entitlement).where(Entitlement.subscription_id == subscription_ids[1])
            )
        ).all()
        assert monthly and annual
        assert all(e.status == EntitlementStatus.active for e in monthly)
        assert all(e.status == EntitlementStatus.revoked for e in annual)


@pytest.mark.asyncio
async def test_out_of_order_webhook_cannot_regress_subscription(setup_test_db):
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://testserver"
    ) as client:
        token = await get_auth_token(client, "learner1@example.com")
        headers = {"Authorization": f"Bearer {token}"}
        created = await client.post(
            "/api/v1/commerce/transactions/verify",
            json={
                "transactionId": "tx_ordered_subscription",
                "provider": "mock",
                "providerTransactionId": "com.learningplatform.subscription.pro.monthly",
                "learnerId": "test-learner-1",
            },
            headers=headers,
        )
        assert created.status_code == 200
        subscription_id = created.json()["subscription"]["id"]
        future = datetime.now(UTC) + timedelta(days=2)
        older = future - timedelta(days=1)
        renewal = await client.post(
            "/api/v1/commerce/webhooks/mock",
            json={
                "eventId": "evt_order_new",
                "eventType": "RENEWAL",
                "transactionId": "tx_order_new",
                "originalTransactionId": "com.learningplatform.subscription.pro.monthly",
                "effectiveDate": future.isoformat(),
            },
        )
        stale = await client.post(
            "/api/v1/commerce/webhooks/mock",
            json={
                "eventId": "evt_order_old",
                "eventType": "EXPIRATION",
                "transactionId": "tx_order_old",
                "originalTransactionId": "com.learningplatform.subscription.pro.monthly",
                "effectiveDate": older.isoformat(),
            },
        )
        assert renewal.status_code == 200
        assert stale.json()["status"] == "ignored"

    async with setup_test_db() as db:
        subscription = await db.get(Subscription, subscription_id)
        assert subscription.status == SubscriptionStatus.active


@pytest.mark.asyncio
async def test_mock_provider_is_disabled_in_production():
    from app.commerce_providers import (
        UnconfiguredPaymentProviderVerifier,
        get_payment_verifier,
    )

    verifier = get_payment_verifier(
        "mock",
        Settings(
            environment="production",
            jwt_secret="test_secret_32_bytes_long_exact_secret",
            media_signing_secret="test_media_secret_32_bytes_long_value",
        ),
    )
    assert isinstance(verifier, UnconfiguredPaymentProviderVerifier)
    with pytest.raises(APIError) as exc_info:
        await verifier.verify_transaction(provider_transaction_id="forged")
    assert exc_info.value.code == "PROVIDER_UNCONFIGURED"
