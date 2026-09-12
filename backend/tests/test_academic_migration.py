"""Run only against an explicitly supplied, disposable empty PostgreSQL database.

Never resets or drops an existing database. The fixture remains for inspection.
"""

import asyncio
import os
import subprocess
import sys
from datetime import UTC, datetime
from pathlib import Path

import pytest
import sqlalchemy as sa
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

URL = os.getenv("ACADEMIC_MIGRATION_TEST_URL")
pytestmark = pytest.mark.skipif(
    not URL, reason="ACADEMIC_MIGRATION_TEST_URL must identify an empty disposable database"
)


def test_existing_schema_upgrade_preserves_ids_and_backfills_valid_references():
    from app import schema_baseline_snapshot as old

    root = Path(__file__).resolve().parents[1]

    async def assert_empty():
        engine = create_async_engine(URL)
        async with engine.connect() as conn:
            assert not await conn.run_sync(lambda c: sa.inspect(c).get_table_names()), (
                "Refusing to use a nonempty migration-test database"
            )
        await engine.dispose()

    asyncio.run(assert_empty())
    env = {**os.environ, "LEARNING_PLATFORM_DATABASE_URL": URL}

    def upgrade(revision):
        subprocess.run(
            [sys.executable, "-m", "alembic", "upgrade", revision], cwd=root, env=env, check=True
        )

    upgrade("0007_cms_phase34")

    async def seed_and_snapshot():
        engine = create_async_engine(URL)
        factory = async_sessionmaker(engine, expire_on_commit=False)
        async with factory() as db:
            db.add(
                old.User(
                    id="migration-learner",
                    email="migration@example.com",
                    password_hash="not-a-login",
                    display_name="Migration learner",
                )
            )
            db.add(
                old.Course(
                    id="migration-course",
                    title="Legacy course",
                    subtitle="",
                    description="",
                    level="beginner",
                    language_code="en",
                    policy_kind=old.PolicyKind.free,
                    status=old.Lifecycle.published,
                )
            )
            await db.flush()
            db.add(
                old.CourseModule(
                    id="migration-chapter",
                    course_id="migration-course",
                    title="Original chapter",
                    position=1,
                )
            )
            await db.flush()
            for index, kind in enumerate(["video", "article", "quiz", "resource"]):
                db.add(
                    old.Lesson(
                        id=f"migration-lesson-{index}",
                        module_id="migration-chapter",
                        title=kind,
                        position=index + 1,
                        duration_seconds=60,
                        content_type=kind,
                        content_ref="migration-assessment"
                        if kind == "quiz"
                        else f"migration-ref-{index}",
                    )
                )
            db.add(
                old.Assessment(
                    id="migration-assessment",
                    course_id="migration-course",
                    title="Quiz",
                    description="",
                    passing_percentage=70,
                    max_attempts=3,
                    status=old.Lifecycle.published,
                )
            )
            await db.flush()
            db.add(
                old.LessonProgress(
                    id="migration-progress",
                    learner_id="migration-learner",
                    lesson_id="migration-lesson-0",
                    position_seconds=45,
                    duration_seconds=60,
                    completed=True,
                )
            )
            db.add(
                old.Enrollment(
                    id="migration-enrollment",
                    learner_id="migration-learner",
                    course_id="migration-course",
                )
            )
            db.add(
                old.Bookmark(
                    id="migration-bookmark",
                    learner_id="migration-learner",
                    course_id="migration-course",
                )
            )
            for index, kind in [(0, "hls"), (3, "download")]:
                await db.execute(
                    sa.text(
                        "INSERT INTO media_assets (id, lesson_id, asset_id, kind, origin_key, public, status, created_at, updated_at) VALUES (:id, :lesson, :asset, :kind, :origin, false, 'active', :now, :now)"
                    ),
                    {
                        "id": f"migration-media-{index}",
                        "lesson": f"migration-lesson-{index}",
                        "asset": f"migration-ref-{index}",
                        "kind": kind,
                        "origin": f"migration/{index}",
                        "now": datetime.now(UTC),
                    },
                )
            await db.commit()
        async with engine.connect() as conn:
            before = {
                table: [
                    dict(row)
                    for row in (
                        await conn.execute(sa.text(f"SELECT * FROM {table} ORDER BY id"))
                    ).mappings()
                ]
                for table in [
                    "users",
                    "courses",
                    "course_modules",
                    "lessons",
                    "assessments",
                    "lesson_progress",
                    "enrollments",
                    "bookmarks",
                    "media_assets",
                ]
            }
        await engine.dispose()
        return before

    before = asyncio.run(seed_and_snapshot())
    upgrade("head")
    upgrade("head")  # A second invocation does not create duplicate content.

    async def verify():
        engine = create_async_engine(URL)
        async with engine.connect() as conn:
            for table, rows in before.items():
                after = [
                    dict(row)
                    for row in (
                        await conn.execute(sa.text(f"SELECT * FROM {table} ORDER BY id"))
                    ).mappings()
                ]
                assert [{key: row[key] for key in rows[0]} for row in after] == rows
            assert await conn.scalar(sa.text("SELECT count(*) FROM lesson_content_items")) == 3
            assert (
                await conn.scalar(
                    sa.text("SELECT count(*) FROM courses WHERE curriculum_id IS NOT NULL")
                )
                == 0
            )
            assert await conn.scalar(sa.text("SELECT count(*) FROM student_academic_profiles")) == 0
            assert (
                await conn.scalar(
                    sa.text("SELECT count(*) FROM media_assets WHERE content_item_id IS NOT NULL")
                )
                == 2
            )
            assert (
                await conn.scalar(
                    sa.text(
                        "SELECT assessment_id FROM lesson_content_items WHERE content_type='quiz'"
                    )
                )
                == "migration-assessment"
            )
            assert (
                await conn.scalar(sa.text("SELECT version_num FROM alembic_version"))
                == "0009_media_v1"
            )
        await engine.dispose()

    asyncio.run(verify())
