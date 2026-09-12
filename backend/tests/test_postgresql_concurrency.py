import asyncio
import json
import os
import uuid
from datetime import UTC, datetime, timedelta

import pytest
import pytest_asyncio
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.commerce_services import process_provider_webhook, verify_and_process_transaction
from app.config import Settings
from app.errors import APIError
from app.models import (
    Assessment,
    BillingInterval,
    Certificate,
    Course,
    Entitlement,
    Lifecycle,
    PaymentProvider,
    PaymentTransaction,
    PolicyKind,
    ProviderEvent,
    ProviderProductMapping,
    Subscription,
    SubscriptionPlan,
    SubscriptionTier,
    User,
)
from app.schemas import TransactionVerifyIn
from app.security import hash_password
from app.services import start_attempt

pytestmark = pytest.mark.skipif(
    not os.getenv("POSTGRES_TEST_URL"), reason="POSTGRES_TEST_URL is required"
)


@pytest_asyncio.fixture
async def factory():
    engine = create_async_engine(os.environ["POSTGRES_TEST_URL"])
    try:
        yield async_sessionmaker(engine, expire_on_commit=False)
    finally:
        await engine.dispose()


async def seed(factory, max_attempts=1):
    suffix = uuid.uuid4().hex
    async with factory() as db:
        user = User(
            email=f"{suffix}@example.com",
            password_hash=hash_password("correct-horse-battery"),
            display_name="Learner",
            onboarding_complete=True,
        )
        course = Course(
            title=f"Course {suffix}",
            subtitle="",
            description="",
            level="beginner",
            language_code="en",
            policy_kind=PolicyKind.free,
            status=Lifecycle.published,
            published_at=datetime.now(UTC),
        )
        db.add_all([user, course])
        await db.flush()
        assessment = Assessment(
            course_id=course.id,
            title="Assessment",
            description="",
            passing_percentage=70,
            max_attempts=max_attempts,
            status=Lifecycle.published,
        )
        db.add(assessment)
        await db.commit()
        return user.id, course.id, assessment.id


@pytest.mark.asyncio
async def test_final_attempt_allocation_is_serialized(factory):
    user_id, _, assessment_id = await seed(factory)

    async def begin():
        async with factory() as db:
            return await start_attempt(db, user_id, await db.get(Assessment, assessment_id))

    results = await asyncio.gather(begin(), begin(), return_exceptions=True)
    assert sum(not isinstance(x, Exception) for x in results) == 1
    assert [x.code for x in results if isinstance(x, APIError)] == ["ATTEMPT_LIMIT_REACHED"]


@pytest.mark.asyncio
async def test_certificate_context_constraint_rejects_duplicate(factory):
    user_id, course_id, _ = await seed(factory)

    async def insert(credential):
        async with factory() as db:
            db.add(
                Certificate(
                    learner_id=user_id,
                    course_id=course_id,
                    credential_id=credential,
                    learner_name="Learner",
                    course_title="Course",
                    issued_at=datetime.now(UTC),
                )
            )
            try:
                await db.commit()
                return True
            except IntegrityError:
                await db.rollback()
                return False

    assert sorted(await asyncio.gather(insert(uuid.uuid4().hex), insert(uuid.uuid4().hex))) == [
        False,
        True,
    ]


@pytest.mark.asyncio
async def test_duplicate_payment_and_webhook_are_serialized(factory):
    suffix = uuid.uuid4().hex
    product_id = f"com.learningplatform.test.plan.{suffix}"
    learner_id = None
    async with factory() as db:
        learner = User(
            email=f"commerce-{suffix}@example.test",
            password_hash=hash_password("correct-horse-battery"),
            display_name="Commerce Learner",
            onboarding_complete=True,
        )
        plan = SubscriptionPlan(
            id=f"plan_{suffix}",
            tier=SubscriptionTier.pro,
            billing_interval=BillingInterval.monthly,
            name="Concurrency Plan",
            price_cents=100,
            formatted_price="$1.00",
        )
        db.add_all([learner, plan])
        await db.flush()
        learner_id = learner.id
        db.add(
            ProviderProductMapping(
                internal_product_type="plan",
                internal_product_id=plan.id,
                provider=PaymentProvider.mock,
                provider_product_id=product_id,
            )
        )
        await db.commit()

    settings = Settings(environment="test")
    body = TransactionVerifyIn(
        transactionId=f"client_{suffix}",
        provider="mock",
        providerTransactionId=product_id,
        learnerId=learner_id,
    )

    async def verify():
        async with factory() as db:
            result = await verify_and_process_transaction(db, learner_id, body, settings)
            await db.commit()
            return result

    first, second = await asyncio.gather(verify(), verify())
    assert first["verified"] is second["verified"] is True

    async with factory() as db:
        assert (
            await db.scalar(
                select(func.count())
                .select_from(PaymentTransaction)
                .where(
                    PaymentTransaction.provider == PaymentProvider.mock,
                    PaymentTransaction.provider_transaction_id == product_id,
                )
            )
            == 1
        )

    older = datetime.now(UTC)
    newer = older + timedelta(minutes=1)
    expiration_event = json.dumps(
        {
            "eventId": f"expire_{suffix}",
            "eventType": "EXPIRATION",
            "transactionId": f"expire_tx_{suffix}",
            "originalTransactionId": product_id,
            "effectiveDate": older.isoformat(),
        }
    ).encode()
    renewal_event = json.dumps(
        {
            "eventId": f"renew_{suffix}",
            "eventType": "RENEWAL",
            "transactionId": f"renew_tx_{suffix}",
            "originalTransactionId": product_id,
            "effectiveDate": newer.isoformat(),
            "expirationDate": (newer + timedelta(days=30)).isoformat(),
        }
    ).encode()

    async def deliver_event(payload):
        async with factory() as db:
            return await process_provider_webhook(db, "mock", {}, payload, settings)

    await asyncio.gather(deliver_event(renewal_event), deliver_event(expiration_event))
    async with factory() as db:
        subscription = await db.scalar(
            select(Subscription).where(
                Subscription.provider == PaymentProvider.mock,
                Subscription.original_transaction_id == product_id,
            )
        )
        assert subscription.status.value == "active"
        assert subscription.provider_state_updated_at == newer
        assert (
            await db.scalar(
                select(func.count())
                .select_from(Subscription)
                .where(
                    Subscription.learner_id == learner_id,
                    Subscription.original_transaction_id == product_id,
                )
            )
            == 1
        )
        assert (
            await db.scalar(
                select(func.count())
                .select_from(Entitlement)
                .where(
                    Entitlement.learner_id == learner_id,
                    Entitlement.subscription_id.is_not(None),
                )
            )
            == 1
        )

    event_id = f"evt_{suffix}"
    webhook = (
        '{"eventId":"'
        + event_id
        + '","eventType":"RENEWAL","transactionId":"renew_'
        + suffix
        + '","originalTransactionId":"'
        + product_id
        + '"}'
    ).encode()

    async def deliver():
        async with factory() as db:
            return await process_provider_webhook(db, "mock", {}, webhook, settings)

    webhook_results = await asyncio.gather(deliver(), deliver())
    assert {result.get("idempotent", False) for result in webhook_results} == {
        False,
        True,
    }
    async with factory() as db:
        assert (
            await db.scalar(
                select(func.count())
                .select_from(ProviderEvent)
                .where(
                    ProviderEvent.provider == PaymentProvider.mock,
                    ProviderEvent.event_id == event_id,
                )
            )
            == 1
        )


@pytest.mark.asyncio
async def test_refresh_token_is_consumed_once_under_concurrency(factory):
    from app.api import create_session, refresh
    from app.schemas import Refresh

    user_id, _, _ = await seed(factory)
    async with factory() as db:
        session = await create_session(db, await db.get(User, user_id))

    async def rotate():
        async with factory() as db:
            return await refresh(Refresh(refreshToken=session["refreshToken"]), db)

    results = await asyncio.gather(rotate(), rotate(), return_exceptions=True)
    assert sum(isinstance(result, dict) for result in results) == 1, results
    assert [result.code for result in results if isinstance(result, APIError)] == [
        "SESSION_EXPIRED"
    ]


@pytest.mark.asyncio
async def test_reset_token_is_consumed_once_and_invalidates_sibling_codes(factory):
    from app.api import password_reset_confirm
    from app.models import PasswordResetCode
    from app.schemas import ResetConfirm
    from app.security import token_hash

    user_id, _, _ = await seed(factory)
    async with factory() as db:
        user = await db.get(User, user_id)
        email = user.email
        for raw in ("first-token", "second-token"):
            db.add(
                PasswordResetCode(
                    user_id=user_id,
                    code_hash=token_hash(raw),
                    expires_at=datetime.now(UTC) + timedelta(minutes=15),
                )
            )
        await db.commit()

    async def reset(raw):
        async with factory() as db:
            return await password_reset_confirm(
                ResetConfirm(
                    email=email, verificationCode=raw, newPassword="new-correct-horse-battery"
                ),
                db,
            )

    results = await asyncio.gather(
        reset("first-token"), reset("first-token"), return_exceptions=True
    )
    assert sum(isinstance(result, dict) for result in results) == 1, results
    assert [result.code for result in results if isinstance(result, APIError)] == [
        "EXPIRED_RESOURCE"
    ]
    with pytest.raises(APIError):
        await reset("second-token")


@pytest.mark.asyncio
async def test_duplicate_progress_in_batch_and_parallel_requests_commit_once(factory):
    from app.api import sync_progress
    from app.models import CourseModule, Enrollment, Lesson, LessonProgress
    from app.schemas import ProgressSync

    user_id, course_id, _ = await seed(factory)
    async with factory() as db:
        module = CourseModule(course_id=course_id, title="Module", position=0)
        db.add(module)
        await db.flush()
        lesson = Lesson(
            module_id=module.id,
            title="Read",
            position=0,
            content_type="article",
            content_ref=uuid.uuid4().hex,
        )
        db.add_all([lesson, Enrollment(learner_id=user_id, course_id=course_id)])
        await db.commit()
        lesson_id = lesson.id
    mutation = dict(
        id=uuid.uuid4().hex,
        lessonId=lesson_id,
        kind="completion",
        positionSeconds=60,
        durationSeconds=60,
        completed=True,
        occurredAt=datetime.now(UTC).isoformat(),
        baseRevision=0,
    )
    body = ProgressSync(mutations=[mutation, mutation])

    async def save():
        async with factory() as db:
            return await sync_progress(course_id, body, await db.get(User, user_id), db)

    first, second = await asyncio.gather(save(), save())
    assert first["progress"]["lessons"][lesson_id]["completed"] is True
    assert first["progress"]["serverRevision"] == second["progress"]["serverRevision"] == 1
    async with factory() as db:
        assert (
            await db.scalar(
                select(func.count())
                .select_from(LessonProgress)
                .where(LessonProgress.learner_id == user_id)
            )
            == 1
        )


@pytest.mark.asyncio
async def test_duplicate_submission_replays_result_and_server_completes_quiz(factory):
    from app.api import submit, sync_progress
    from app.models import (
        AssessmentQuestion,
        CourseModule,
        Enrollment,
        Lesson,
        LessonProgress,
        QuestionType,
    )
    from app.schemas import ProgressSync, Submission

    user_id, course_id, assessment_id = await seed(factory)
    async with factory() as db:
        module = CourseModule(course_id=course_id, title="Module", position=0)
        db.add(module)
        await db.flush()
        lesson = Lesson(
            module_id=module.id,
            title="Knowledge check",
            position=0,
            duration_seconds=60,
            content_type="quiz",
            content_ref=assessment_id,
        )
        question = AssessmentQuestion(
            assessment_id=assessment_id,
            position=0,
            type=QuestionType.true_false,
            prompt="Ready?",
            points=1,
            grading_data={"correctValue": True},
            explanation="Yes",
        )
        db.add_all([lesson, question, Enrollment(learner_id=user_id, course_id=course_id)])
        await db.commit()
        lesson_id, question_id = lesson.id, question.id
        attempt = await start_attempt(db, user_id, await db.get(Assessment, assessment_id))
        attempt_id = attempt.id
    async with factory() as db:
        with pytest.raises(APIError) as denied:
            await sync_progress(
                course_id,
                ProgressSync(
                    mutations=[
                        dict(
                            id=uuid.uuid4().hex,
                            lessonId=lesson_id,
                            kind="completion",
                            positionSeconds=60,
                            durationSeconds=60,
                            completed=True,
                            occurredAt=datetime.now(UTC).isoformat(),
                            baseRevision=0,
                        )
                    ]
                ),
                await db.get(User, user_id),
                db,
            )
        assert denied.value.code == "SERVER_COMPLETION_REQUIRED"
    body = Submission(
        attemptId=attempt_id,
        answers=[dict(questionId=question_id, type="trueFalse", selectedValue=True)],
    )
    key = uuid.uuid4().hex

    async def send():
        async with factory() as db:
            return await submit(
                assessment_id,
                attempt_id,
                body,
                await db.get(User, user_id),
                db,
                idempotency_key=key,
            )

    results = await asyncio.gather(send(), send(), return_exceptions=True)
    accepted = [result for result in results if isinstance(result, dict)]
    assert accepted and accepted[0]["isPassed"] is True
    for result in results:
        assert (
            isinstance(result, dict)
            or isinstance(result, APIError)
            and result.code == "IDEMPOTENCY_IN_PROGRESS"
        )
    assert await send() == accepted[0]
    async with factory() as db:
        progress = await db.scalar(
            select(LessonProgress).where(
                LessonProgress.learner_id == user_id, LessonProgress.lesson_id == lesson_id
            )
        )
        assert progress.completed is True
