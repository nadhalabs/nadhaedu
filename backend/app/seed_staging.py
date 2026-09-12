import asyncio
import os
from datetime import UTC, datetime, timedelta

from sqlalchemy import select

from .config import get_settings
from .db import session_factory
from .models import (
    Assessment,
    BillingInterval,
    Category,
    CommerceProduct,
    CommerceProductType,
    Coupon,
    Course,
    CourseModule,
    DiscountType,
    Enrollment,
    Entitlement,
    EntitlementSource,
    EntitlementStatus,
    Lesson,
    Lifecycle,
    MediaAsset,
    PaymentProvider,
    PolicyKind,
    ProviderProductMapping,
    ResourceType,
    SubscriptionPlan,
    SubscriptionTier,
    User,
)
from .security import hash_password


async def seed() -> None:
    settings = get_settings()
    if settings.environment == "production" or os.getenv("ALLOW_STAGING_SEED") != "true":
        raise RuntimeError(
            "Staging seed is disabled. Set ALLOW_STAGING_SEED=true outside production."
        )
    password = os.getenv("STAGING_SEED_PASSWORD")
    if not password or len(password) < 16:
        raise RuntimeError("STAGING_SEED_PASSWORD must contain at least 16 characters.")
    async with session_factory()() as db:
        category = await db.scalar(select(Category).where(Category.name == "Staging curriculum"))
        if not category:
            category = Category(name="Staging curriculum", icon_name="school")
            db.add(category)
            await db.flush()
        courses = []
        for slug, title, policy in [
            ("free-foundations", "Free foundations", PolicyKind.free),
            ("premium-practice", "Premium practice", PolicyKind.premium),
            ("certificate-path", "Certificate path", PolicyKind.free),
        ]:
            course = await db.scalar(select(Course).where(Course.title == title))
            if not course:
                course = Course(
                    title=title,
                    subtitle="Representative staging content",
                    description="Isolated non-production curriculum.",
                    level="beginner",
                    language_code="en",
                    policy_kind=policy,
                    status=Lifecycle.published,
                    published_at=datetime.now(UTC),
                    learning_outcomes=["Validate staging learning flows"],
                    prerequisites=[],
                )
                db.add(course)
                await db.flush()
                module = CourseModule(
                    course_id=course.id,
                    title="Core module",
                    position=1,
                    policy_kind=PolicyKind.inherit,
                )
                db.add(module)
                await db.flush()
                video = Lesson(
                    module_id=module.id,
                    title="Adaptive video",
                    position=1,
                    duration_seconds=300,
                    content_type="video",
                    content_ref=f"{slug}-video",
                    is_preview=policy == PolicyKind.premium,
                    policy_kind=PolicyKind.preview
                    if policy == PolicyKind.premium
                    else PolicyKind.inherit,
                )
                text = Lesson(
                    module_id=module.id,
                    title="Reading",
                    position=2,
                    duration_seconds=180,
                    content_type="article",
                    content_ref=f"{slug}-article",
                    is_preview=False,
                    policy_kind=PolicyKind.inherit,
                )
                resource = Lesson(
                    module_id=module.id,
                    title="Download",
                    position=3,
                    duration_seconds=60,
                    content_type="resource",
                    content_ref=f"{slug}-resource",
                    is_preview=False,
                    policy_kind=PolicyKind.inherit,
                )
                db.add_all([video, text, resource])
                await db.flush()
                db.add_all(
                    [
                        MediaAsset(
                            lesson_id=video.id,
                            asset_id=video.content_ref,
                            kind="hls",
                            origin_key=f"courses/{course.id}/video/master.m3u8",
                        ),
                        MediaAsset(
                            lesson_id=resource.id,
                            asset_id=resource.content_ref,
                            kind="download",
                            origin_key=f"courses/{course.id}/resources/guide.pdf",
                        ),
                    ]
                )
                db.add(
                    Assessment(
                        course_id=course.id,
                        title="Timed staging assessment",
                        description="Operational validation",
                        instructions=["Answer all questions"],
                        passing_percentage=70,
                        time_limit_seconds=600,
                        max_attempts=2,
                        required_for_certificate=slug == "certificate-path",
                        status=Lifecycle.published,
                    )
                )
            courses.append(course)
        users = []
        for label in ["free", "premium", "expired", "assessment", "certificate", "administrator"]:
            email = f"staging-{label}@example.invalid"
            user = await db.scalar(select(User).where(User.email == email))
            if not user:
                user = User(
                    email=email,
                    password_hash=hash_password(password),
                    display_name=f"Staging {label.title()}",
                    onboarding_complete=True,
                    role="admin" if label == "administrator" else "learner",
                )
                db.add(user)
                await db.flush()
            users.append(user)
        for user in users[:-1]:
            for course in courses:
                if not await db.scalar(
                    select(Enrollment.id).where(
                        Enrollment.learner_id == user.id, Enrollment.course_id == course.id
                    )
                ):
                    db.add(Enrollment(learner_id=user.id, course_id=course.id, status="active"))
        premium = users[1]
        expired = users[2]
        admin = users[5]
        if not await db.scalar(select(Entitlement.id).where(Entitlement.learner_id == premium.id)):
            db.add(
                Entitlement(
                    learner_id=premium.id,
                    source=EntitlementSource.subscription,
                    status=EntitlementStatus.active,
                    resource_type=ResourceType.course,
                    resource_id=courses[1].id,
                    starts_at=datetime.now(UTC) - timedelta(days=1),
                    expires_at=datetime.now(UTC) + timedelta(days=30),
                    metadata_json={"tier": "staging-premium"},
                )
            )
        if not await db.scalar(select(Entitlement.id).where(Entitlement.learner_id == expired.id)):
            db.add(
                Entitlement(
                    learner_id=expired.id,
                    source=EntitlementSource.promotion,
                    status=EntitlementStatus.expired,
                    resource_type=ResourceType.course,
                    resource_id=courses[1].id,
                    starts_at=datetime.now(UTC) - timedelta(days=30),
                    expires_at=datetime.now(UTC) - timedelta(days=1),
                    metadata_json={},
                )
            )
        if not await db.scalar(select(Entitlement.id).where(Entitlement.learner_id == admin.id)):
            db.add(
                Entitlement(
                    learner_id=admin.id,
                    source=EntitlementSource.admin_grant,
                    status=EntitlementStatus.active,
                    resource_type=None,
                    resource_id=None,
                    starts_at=datetime.now(UTC),
                    metadata_json={"reason": "staging operations"},
                )
            )

        # Commerce Seed Data
        plans_data = [
            (
                "plan_pro_monthly",
                SubscriptionTier.pro,
                BillingInterval.monthly,
                "Pro Monthly",
                "Unlimited access to all courses, projects, and certificates.",
                1499,
                "$14.99",
                7,
                ["Full access to all courses", "Official certificates", "Offline downloads"],
                False,
                False,
                0,
                "com.learningplatform.subscription.pro.monthly",
            ),
            (
                "plan_pro_annual",
                SubscriptionTier.pro,
                BillingInterval.annual,
                "Pro Annual",
                "Best value for committed learners. Save 33% compared to monthly.",
                11999,
                "$119.99",
                14,
                ["All Pro Monthly features", "14-day free trial included", "33% annual discount"],
                True,
                True,
                33,
                "com.learningplatform.subscription.pro.annual",
            ),
            (
                "plan_student_monthly",
                SubscriptionTier.student,
                BillingInterval.monthly,
                "Student Pro",
                "Discounted plan for verified students and academic learners.",
                799,
                "$7.99",
                7,
                ["Full Pro access during academic terms", "Student credentials"],
                False,
                False,
                46,
                "com.learningplatform.subscription.student.monthly",
            ),
            (
                "plan_family_annual",
                SubscriptionTier.family,
                BillingInterval.annual,
                "Family Plan",
                "One plan for up to 5 family members with individual profiles.",
                19999,
                "$199.99",
                14,
                ["Up to 5 learner accounts", "Family progress dashboard"],
                False,
                False,
                40,
                "com.learningplatform.subscription.family.annual",
            ),
            (
                "plan_institution_annual",
                SubscriptionTier.institution,
                BillingInterval.annual,
                "Institution & Enterprise",
                "Enterprise grade learning with centralized team analytics.",
                99900,
                "$999.00",
                0,
                ["Enterprise organization license", "Custom learning paths"],
                False,
                False,
                0,
                "com.learningplatform.subscription.institution.annual",
            ),
        ]

        for (
            pid,
            tier,
            interval,
            name,
            desc,
            cents,
            fmt,
            trial,
            benefits,
            pop,
            rec,
            save,
            store_id,
        ) in plans_data:
            plan = await db.get(SubscriptionPlan, pid)
            if not plan:
                plan = SubscriptionPlan(
                    id=pid,
                    tier=tier,
                    billing_interval=interval,
                    name=name,
                    description=desc,
                    price_cents=cents,
                    formatted_price=fmt,
                    trial_days=trial,
                    benefits=benefits,
                    is_popular=pop,
                    is_recommended=rec,
                    savings_percent=save,
                )
                db.add(plan)
                await db.flush()

                # Add store mappings
                db.add(
                    ProviderProductMapping(
                        internal_product_type="plan",
                        internal_product_id=pid,
                        provider=PaymentProvider.apple_app_store,
                        provider_product_id=store_id,
                    )
                )
                db.add(
                    ProviderProductMapping(
                        internal_product_type="plan",
                        internal_product_id=pid,
                        provider=PaymentProvider.google_play,
                        provider_product_id=store_id,
                    )
                )

        # Seed Course and Bundle Products
        if not await db.get(CommerceProduct, "prod_course_1"):
            c_prod = CommerceProduct(
                id="prod_course_1",
                product_type=CommerceProductType.course,
                course_id=courses[0].id if courses else None,
                title="Modern Flutter Architecture Masterclass",
                description="Master clean architecture, state orchestration, and testing.",
                price_cents=4900,
                formatted_price="$49.00",
                original_price_cents=5900,
                discount_percent=17,
                features=["Lifetime access", "Official certificate", "Code repos"],
            )
            db.add(c_prod)
            db.add(
                ProviderProductMapping(
                    internal_product_type="course",
                    internal_product_id="prod_course_1",
                    provider=PaymentProvider.apple_app_store,
                    provider_product_id="com.learningplatform.course.flutter_arch",
                )
            )

        if not await db.get(CommerceProduct, "prod_bundle_mobile"):
            b_prod = CommerceProduct(
                id="prod_bundle_mobile",
                product_type=CommerceProductType.bundle,
                bundle_id="bundle_mobile_dev",
                course_ids=[c.id for c in courses],
                title="Complete Mobile Engineering Bundle",
                description="Everything you need to build production-grade mobile applications.",
                price_cents=8900,
                formatted_price="$89.00",
                original_price_cents=12900,
                discount_percent=31,
                features=["All bundled courses", "Lifetime access", "2 certificates"],
            )
            db.add(b_prod)
            db.add(
                ProviderProductMapping(
                    internal_product_type="bundle",
                    internal_product_id="prod_bundle_mobile",
                    provider=PaymentProvider.apple_app_store,
                    provider_product_id="com.learningplatform.bundle.mobile_arch",
                )
            )

        # Seed Coupons
        coupons_data = [
            ("SAVE20", DiscountType.percentage, 20, "20% off any subscription or course"),
            ("PRO10", DiscountType.fixed_amount, 1000, "$10 off your order"),
            ("WELCOME50", DiscountType.percentage, 50, "50% off welcome promotion"),
        ]
        for code, dtype, val, cdesc in coupons_data:
            if not await db.scalar(select(Coupon).where(Coupon.code == code)):
                db.add(
                    Coupon(
                        code=code,
                        discount_type=dtype,
                        discount_value=val,
                        valid_from=datetime.now(UTC),
                        valid_until=datetime.now(UTC) + timedelta(days=90),
                        description=cdesc,
                    )
                )

        await db.commit()


if __name__ == "__main__":
    asyncio.run(seed())
