import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool

import app.dependencies as dep_mod
from app.main import app
from app.models import (
    Assessment,
    Base,
    ContentProtectionPolicy,
    Course,
    CourseModule,
    Lesson,
    Lifecycle,
    PolicyKind,
)


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

    async def override_get_session():
        async with test_session() as s:
            yield s

    app.dependency_overrides[dep_mod.get_session] = override_get_session

    yield test_session

    app.dependency_overrides.clear()
    await engine.dispose()


@pytest.mark.asyncio
async def test_course_and_lesson_protection_policy_serialization(setup_test_db):
    test_session = setup_test_db
    async with test_session() as db:
        course = Course(
            title="Protected Flutter Mastery",
            subtitle="Advanced screen protection",
            description="Deep dive into Flutter security",
            policy_kind=PolicyKind.premium,
            protection_policy=ContentProtectionPolicy.block_capture,
            status=Lifecycle.published,
            rating=5.0,
            rating_count=10,
            duration_seconds=3600,
        )
        db.add(course)
        await db.flush()

        module = CourseModule(
            course_id=course.id,
            title="Module 1",
            position=1,
            policy_kind=PolicyKind.inherit,
        )
        db.add(module)
        await db.flush()

        lesson = Lesson(
            module_id=module.id,
            title="Protected Video Lesson",
            position=1,
            duration_seconds=600,
            content_type="video",
            content_ref="protected-asset-001",
            is_preview=False,
            policy_kind=PolicyKind.inherit,
            protection_policy=ContentProtectionPolicy.block_capture,
        )
        db.add(lesson)

        assessment = Assessment(
            course_id=course.id,
            title="Certification Exam",
            description="Final quiz",
            instructions=["Answer honestly"],
            passing_percentage=80,
            time_limit_seconds=1200,
            max_attempts=2,
            protection_policy=ContentProtectionPolicy.block_capture,
            status=Lifecycle.published,
        )
        db.add(assessment)
        await db.commit()

        course_id = course.id

    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://testserver"
    ) as client:
        res = await client.get(f"/api/v1/courses/{course_id}")
        assert res.status_code == 200
        data = res.json()

        # Verify course summary contains protection policy
        assert "protectionPolicy" in data["summary"]
        assert data["summary"]["protectionPolicy"] == "blockCaptureWhereSupported"

        # Verify lesson contains protection policy
        lesson_data = data["modules"][0]["lessons"][0]
        assert "protectionPolicy" in lesson_data
        assert lesson_data["protectionPolicy"] == "blockCaptureWhereSupported"


@pytest.mark.asyncio
async def test_free_course_protection_policy_none(setup_test_db):
    test_session = setup_test_db
    async with test_session() as db:
        course = Course(
            title="Free Flutter Intro",
            subtitle="Learn Flutter for free",
            description="Introductory material",
            policy_kind=PolicyKind.free,
            protection_policy=ContentProtectionPolicy.none,
            status=Lifecycle.published,
            rating=4.5,
            rating_count=50,
            duration_seconds=1200,
        )
        db.add(course)
        await db.flush()

        module = CourseModule(
            course_id=course.id,
            title="Public Module",
            position=1,
            policy_kind=PolicyKind.free,
        )
        db.add(module)
        await db.flush()

        lesson = Lesson(
            module_id=module.id,
            title="Public Video",
            position=1,
            duration_seconds=300,
            content_type="video",
            content_ref="free-asset-001",
            is_preview=True,
            policy_kind=PolicyKind.free,
            protection_policy=ContentProtectionPolicy.none,
        )
        db.add(lesson)
        await db.commit()
        course_id = course.id

    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://testserver"
    ) as client:
        res = await client.get(f"/api/v1/courses/{course_id}")
        assert res.status_code == 200
        data = res.json()
        assert data["summary"]["protectionPolicy"] == "none"
        assert data["modules"][0]["lessons"][0]["protectionPolicy"] == "none"
