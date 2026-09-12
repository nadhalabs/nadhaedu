"""Academic context is presentation state; history remains keyed by original IDs."""

from datetime import UTC, datetime

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool

from app import dependencies
from app.main import app
from app.models import (
    Base,
    User,
    UserRole,
    Curriculum,
    Standard,
    Stream,
    Subject,
    Course,
    CourseModule,
    Lesson,
    Lifecycle,
    PolicyKind,
    Enrollment,
    Bookmark,
    RecentlyViewed,
    LessonProgress,
    Assessment,
    AssessmentAttempt,
    AttemptStatus,
    Entitlement,
    EntitlementSource,
    EntitlementStatus,
    ResourceType,
    MediaAsset,
    Certificate,
    LessonContentItem,
    VideoWatchProgress,
)
from app.security import hash_password


@pytest_asyncio.fixture
async def academic_env():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:", poolclass=StaticPool)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    factory = async_sessionmaker(engine, expire_on_commit=False)

    async def session():
        async with factory() as db:
            yield db

    app.dependency_overrides[dependencies.get_session] = session
    async with factory() as db:
        db.add_all(
            [
                User(
                    id="learner",
                    email="academic@example.com",
                    password_hash=hash_password("Passw0rd!abc"),
                    display_name="Learner",
                    onboarding_complete=True,
                ),
                User(
                    id="admin",
                    email="academic-admin@example.com",
                    password_hash=hash_password("Passw0rd!abc"),
                    display_name="Admin",
                    role=UserRole.admin,
                ),
            ]
        )
        db.add_all(
            [
                Curriculum(id="cbse", name="CBSE", code="CBSE"),
                Curriculum(id="kerala", name="Kerala State", code="KERALA"),
                Subject(id="physics", name="Physics", code="PHY"),
            ]
        )
        await db.flush()
        db.add_all(
            [
                Standard(id="10", curriculum_id="cbse", name="Class 10", code="10"),
                Standard(id="11", curriculum_id="kerala", name="Plus One", code="11"),
            ]
        )
        await db.flush()
        db.add(Stream(id="science", standard_id="11", name="Science", code="SCI"))
        for key, board, standard, stream in [
            ("a", "cbse", "10", None),
            ("b", "kerala", "11", "science"),
            ("legacy", None, None, None),
        ]:
            db.add(
                Course(
                    id=key,
                    title=f"Physics {key}",
                    subtitle="",
                    description="",
                    level="allLevels",
                    language_code="en",
                    policy_kind=PolicyKind.free,
                    status=Lifecycle.published,
                    published_at=datetime.now(UTC),
                    curriculum_id=board,
                    standard_id=standard,
                    stream_id=stream,
                    subject_id="physics" if board else None,
                )
            )
            await db.flush()
            db.add(CourseModule(id=f"{key}-chapter", course_id=key, title="Chapter", position=1))
            await db.flush()
            db.add(
                Lesson(
                    id=f"{key}-lesson",
                    module_id=f"{key}-chapter",
                    title="Lesson",
                    position=1,
                    duration_seconds=60,
                    content_type="video",
                    content_ref=f"{key}-video",
                )
            )
        await db.flush()
        db.add_all(
            [
                Assessment(
                    id="quiz",
                    course_id="a",
                    title="Quiz",
                    description="",
                    passing_percentage=70,
                    max_attempts=3,
                    status=Lifecycle.published,
                ),
                Assessment(
                    id="foreign-quiz",
                    course_id="b",
                    title="Other quiz",
                    description="",
                    passing_percentage=70,
                    max_attempts=3,
                    status=Lifecycle.published,
                ),
                MediaAsset(
                    id="media",
                    lesson_id="a-lesson",
                    asset_id="a-video",
                    kind="hls",
                    origin_key="a/video.m3u8",
                ),
            ]
        )
        await db.commit()
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        tokens = {}
        for who, email in [
            ("learner", "academic@example.com"),
            ("admin", "academic-admin@example.com"),
        ]:
            response = await client.post(
                "/api/v1/auth/login", json={"email": email, "password": "Passw0rd!abc"}
            )
            assert response.status_code == 200, response.text
            tokens[who] = {"Authorization": f"Bearer {response.json()['accessToken']}"}
        yield client, tokens, factory
    app.dependency_overrides.clear()
    await engine.dispose()


def selection(board="cbse", standard="10", stream=None):
    return {"activeCurriculumId": board, "activeStandardId": standard, "activeStreamId": stream}


@pytest.mark.asyncio
async def test_profile_validation_and_version(academic_env):
    client, headers, _ = academic_env
    h = headers["learner"]
    assert (await client.get("/api/v1/academic-profile", headers=h)).json()["profile"] is None
    for body in [
        selection("cbse", "11"),
        selection(stream="science"),
        selection("kerala", "11"),
        selection("missing"),
    ]:
        assert (
            await client.put("/api/v1/academic-profile", headers=h, json=body)
        ).status_code == 422
    for body, version in [
        (selection(), 1),
        (selection(), 1),
        (selection("kerala", "11", "science"), 2),
        (selection(), 3),
    ]:
        response = await client.put("/api/v1/academic-profile", headers=h, json=body)
        assert response.status_code == 200, response.text
        assert response.json()["profile"]["profileVersion"] == version
    assert (await client.get("/v1/academic-profile", headers=h)).json()["profile"][
        "profileVersion"
    ] == 3
    assert (await client.get("/api/v1/academic-profile")).status_code == 401


@pytest.mark.asyncio
async def test_switch_catalog_and_preserve_history(academic_env):
    client, headers, factory = academic_env
    h = headers["learner"]
    now = datetime.now(UTC)
    async with factory() as db:
        db.add_all(
            [
                Enrollment(learner_id="learner", course_id="a"),
                Bookmark(learner_id="learner", course_id="a"),
                RecentlyViewed(learner_id="learner", course_id="a"),
                LessonProgress(
                    learner_id="learner",
                    lesson_id="a-lesson",
                    position_seconds=45,
                    duration_seconds=60,
                    completed=True,
                ),
                AssessmentAttempt(
                    learner_id="learner",
                    assessment_id="quiz",
                    attempt_number=1,
                    started_at=now,
                    status=AttemptStatus.submitted,
                    passed=True,
                    result_json={"preserved": True},
                ),
                Entitlement(
                    learner_id="learner",
                    source=EntitlementSource.admin_grant,
                    status=EntitlementStatus.active,
                    resource_type=ResourceType.course,
                    resource_id="a",
                    starts_at=now,
                ),
                Certificate(
                    learner_id="learner",
                    course_id="a",
                    credential_id="academic-credential",
                    learner_name="Learner",
                    course_title="Physics a",
                    issued_at=now,
                ),
            ]
        )
        await db.commit()
    models = [
        Enrollment,
        Bookmark,
        RecentlyViewed,
        LessonProgress,
        AssessmentAttempt,
        Entitlement,
        Certificate,
        User,
        MediaAsset,
    ]

    async def snapshot():
        async with factory() as db:
            return {
                m.__tablename__: [
                    dict(row)
                    for row in (await db.execute(select(m.__table__).order_by(m.id))).mappings()
                ]
                for m in models
            }

    before = await snapshot()
    for body, course_id in [
        (selection(), "a"),
        (selection("kerala", "11", "science"), "b"),
        (selection(), "a"),
    ]:
        assert (
            await client.put("/api/v1/academic-profile", headers=h, json=body)
        ).status_code == 200
        for query in ["", "?search=Physics", "?categoryId=physics"]:
            catalog = await client.get("/api/v1/courses" + query, headers=h)
            assert {x["id"] for x in catalog.json()["items"]} == {course_id}, catalog.text
        home = (await client.get("/api/v1/home", headers=h)).json()
        ids = {
            x["id"]
            for section in home["sections"]
            if section["kind"] != "popularCategories"
            for x in section["items"]
        }
        assert ids <= {course_id} and course_id in ids
        assert (await client.get("/api/v1/academic/subjects", headers=h)).json()["items"][0][
            "id"
        ] == "physics"
        assert (await client.get("/api/v1/bookmarks", headers=h)).json()["items"] == ["a"]
        assert (
            await client.get("/api/v1/courses/a", headers=h)
        ).status_code == 200  # historical detail/download access
        assert await snapshot() == before
    assert {x["id"] for x in (await client.get("/api/v1/courses")).json()["items"]} == {
        "a",
        "b",
        "legacy",
    }
    for path in [
        "/admin/courses/a",
        "/admin/courses/a/modules/a-chapter",
        "/admin/courses/a/modules/a-chapter/lessons/a-lesson",
        "/admin/assessments/quiz",
    ]:
        response = await client.delete("/api/v1" + path, headers=headers["admin"])
        assert response.status_code == 409, (path, response.text)


@pytest.mark.asyncio
async def test_cms_classification_and_taxonomy(academic_env):
    client, headers, _ = academic_env
    h = headers["admin"]
    good = {"curriculumId": "cbse", "standardId": "10", "subjectId": "physics", "streamId": None}
    for fields in [
        {**good, "standardId": "11"},
        {**good, "streamId": "science"},
        {**good, "subjectId": None},
    ]:
        assert (
            await client.put("/api/v1/admin/courses/legacy", headers=h, json=fields)
        ).status_code == 422
    response = await client.put("/api/v1/admin/courses/legacy", headers=h, json=good)
    assert response.status_code == 200, response.text
    assert response.json()["curriculumId"] == "cbse"
    inventory = await client.get(
        "/api/v1/admin/courses?curriculumId=kerala&standardId=11&streamId=science&subjectId=physics",
        headers=h,
    )
    assert [r["id"] for r in inventory.json()["items"]] == ["b"]
    assert inventory.json()["items"][0]["curriculumId"] == "kerala"
    assert (
        await client.post(
            "/api/v1/admin/academic/subjects",
            headers=headers["learner"],
            json={"name": "Math", "code": "MATH"},
        )
    ).status_code == 403
    disabled = await client.put(
        "/api/v1/admin/academic/subjects/physics",
        headers=h,
        json={"name": "Physics", "code": "PHY", "isActive": False},
    )
    assert disabled.status_code == 200
    await client.put("/api/v1/academic-profile", headers=headers["learner"], json=selection())
    assert (await client.get("/api/v1/courses", headers=headers["learner"])).json()["items"] == []


@pytest.mark.asyncio
async def test_ordered_content_and_legacy_compatibility(academic_env):
    client, headers, factory = academic_env
    path = "/api/v1/admin/lessons/a-lesson/content-items"
    h = headers["admin"]
    legacy = (await client.get("/api/v1/courses/a")).json()["modules"][0]["lessons"][0]
    assert legacy["content"] == {"type": "video", "referenceId": "a-video"}
    assert not legacy["hasContentItems"]
    created = []
    for body in [
        dict(contentType="video", referenceId="a-video"),
        dict(contentType="note", body="Private learning note"),
        dict(contentType="quiz", assessmentId="quiz"),
    ]:
        response = await client.post(
            path,
            headers=h,
            json={
                **body,
                "position": len(created) + 1,
                "title": body["contentType"],
                "status": "published",
            },
        )
        assert response.status_code == 201, response.text
        created.append(response.json())
    for invalid in [
        dict(contentType="video", referenceId="not-registered"),
        dict(contentType="quiz", assessmentId="foreign-quiz"),
        dict(contentType="note", body=""),
    ]:
        assert (
            await client.post(path, headers=h, json={**invalid, "position": 4})
        ).status_code == 422
    response = await client.post(
        path + "/reorder", headers=h, json={"itemIds": [x["id"] for x in reversed(created)]}
    )
    assert response.status_code == 200, response.text
    assert [i["type"] for i in response.json()["items"]] == ["quiz", "note", "video"]
    public = (await client.get("/api/v1/courses/a")).json()["modules"][0]["lessons"][0]
    assert public["hasContentItems"] and len(public["contentItems"]) == 3
    assert all(i["body"] is None for i in public["contentItems"])
    assert (
        await client.get("/api/v1/lesson-content/" + created[1]["id"], headers=headers["learner"])
    ).json()["body"] == "Private learning note"
    assert (await client.get("/api/v1/lesson-content/" + created[1]["id"])).status_code == 401
    readiness = "/api/v1/lessons/a-lesson/completion-readiness"
    assert not (await client.get(readiness, headers=headers["learner"])).json()["canComplete"]
    async with factory() as db:
        db.add(
            AssessmentAttempt(
                learner_id="learner",
                assessment_id="quiz",
                attempt_number=1,
                started_at=datetime.now(UTC),
                status=AttemptStatus.submitted,
                passed=True,
            )
        )
        await db.commit()
    assert not (await client.get(readiness, headers=headers["learner"])).json()["canComplete"]
    async with factory() as db:
        db.add(VideoWatchProgress(learner_id="learner", media_asset_id="media", position_seconds=57,
            furthest_seconds=57, completed=True, checkpoint_at=datetime.now(UTC)))
        await db.commit()
    assert (await client.get(readiness, headers=headers["learner"])).json()["canComplete"]
    archived = {**created[0], "contentType": "video", "position": 3, "status": "archived"}
    assert (
        await client.put(path + "/" + created[0]["id"], headers=h, json=archived)
    ).status_code == 200
    assert (
        await client.get("/api/v1/playback/a-video", headers=headers["learner"])
    ).status_code == 404


@pytest.mark.asyncio
async def test_resource_download_uses_exact_asset_and_survives_profile_switch(academic_env):
    client, headers, factory = academic_env
    async with factory() as db:
        db.add_all(
            [
                MediaAsset(
                    lesson_id="a-lesson",
                    asset_id="notes-file",
                    kind="download",
                    origin_key="notes.pdf",
                    download_size_bytes=100,
                    checksum_sha256="a" * 64,
                ),
                MediaAsset(
                    lesson_id="a-lesson",
                    asset_id="different-file",
                    kind="download",
                    origin_key="other.pdf",
                    download_size_bytes=200,
                    checksum_sha256="b" * 64,
                ),
            ]
        )
        await db.commit()
    created = await client.post(
        "/api/v1/admin/lessons/a-lesson/content-items",
        headers=headers["admin"],
        json={
            "contentType": "resource",
            "referenceId": "notes-file",
            "position": 1,
            "title": "Resource",
            "status": "published",
        },
    )
    assert created.status_code == 201, created.text
    for body in [selection(), selection("kerala", "11", "science"), selection()]:
        await client.put("/api/v1/academic-profile", headers=headers["learner"], json=body)
        response = await client.post(
            "/api/v1/downloads/authorize",
            headers=headers["learner"],
            json={"resourceType": "resource", "resourceId": "notes-file", "quality": "standard"},
        )
        assert response.status_code == 200, response.text
        assert response.json()["resourceId"] == "notes-file"
        assert response.json()["checksumSha256"] == "a" * 64
        assert response.json()["resourceType"] == "resource"
        lease = await client.post(
            "/api/v1/downloads/revalidate",
            headers=headers["learner"],
            json={"resourceIds": ["notes-file"]},
        )
        assert lease.json()["results"][0]["status"] == "valid"
