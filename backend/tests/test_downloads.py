from datetime import UTC, datetime, timedelta

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool

import app.dependencies as dep_mod
from app.config import get_settings
from app.errors import APIError
from app.main import app
from app.media import issue_download_token, validate_download_token
from app.models import (
    Base,
    ContentProtectionPolicy,
    Course,
    CourseModule,
    Entitlement,
    EntitlementSource,
    EntitlementStatus,
    Lesson,
    Lifecycle,
    MediaAsset,
    PolicyKind,
    ResourceType,
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

    async with test_session() as db:
        # Seed users
        free_user = User(
            id="user_free",
            email="free@example.com",
            password_hash=hash_password("password12345"),
            display_name="Free Learner",
            onboarding_complete=True,
        )
        premium_user = User(
            id="user_premium",
            email="premium@example.com",
            password_hash=hash_password("password12345"),
            display_name="Premium Learner",
            onboarding_complete=True,
        )
        expired_user = User(
            id="user_expired",
            email="expired@example.com",
            password_hash=hash_password("password12345"),
            display_name="Expired Learner",
            onboarding_complete=True,
        )
        db.add_all([free_user, premium_user, expired_user])

        # Seed courses
        free_course = Course(
            id="course_free",
            title="Introduction to Programming",
            policy_kind=PolicyKind.free,
            status=Lifecycle.published,
            protection_policy=ContentProtectionPolicy.none,
            published_at=datetime.now(UTC),
        )
        premium_course = Course(
            id="course_premium",
            title="Advanced Architecture Mastery",
            policy_kind=PolicyKind.premium,
            status=Lifecycle.published,
            protection_policy=ContentProtectionPolicy.block_capture,
            published_at=datetime.now(UTC),
        )
        db.add_all([free_course, premium_course])

        # Seed modules
        mod_free = CourseModule(
            id="mod_free", course_id="course_free", title="Module 1", position=1
        )
        mod_prem = CourseModule(
            id="mod_prem", course_id="course_premium", title="Module 1", position=1
        )
        db.add_all([mod_free, mod_prem])

        # Seed lessons
        lesson_free = Lesson(
            id="lesson_free_1",
            module_id="mod_free",
            title="Welcome Video",
            position=1,
            duration_seconds=300,
            content_type="video",
            content_ref="asset_free_1",
            is_preview=False,
            is_downloadable=True,
            policy_kind=PolicyKind.free,
        )
        lesson_prem = Lesson(
            id="lesson_prem_1",
            module_id="mod_prem",
            title="Deep Dive Lecture",
            position=1,
            duration_seconds=1200,
            content_type="video",
            content_ref="asset_prem_1",
            is_preview=False,
            is_downloadable=True,
            policy_kind=PolicyKind.premium,
        )
        lesson_non_downloadable = Lesson(
            id="lesson_non_dl",
            module_id="mod_prem",
            title="Streaming Only Special",
            position=2,
            duration_seconds=600,
            content_type="video",
            content_ref="asset_non_dl",
            is_preview=False,
            is_downloadable=False,
            policy_kind=PolicyKind.premium,
        )
        db.add_all([lesson_free, lesson_prem, lesson_non_downloadable])

        # Seed media assets
        media_free = MediaAsset(
            lesson_id="lesson_free_1",
            asset_id="asset_free_1",
            kind="download",
            origin_key="courses/free/lesson1.mp4",
            download_size_bytes=1024 * 1024 * 10,
            checksum_sha256="a" * 64,
        )
        media_prem = MediaAsset(
            lesson_id="lesson_prem_1",
            asset_id="asset_prem_1",
            kind="download",
            origin_key="courses/premium/lesson1.mp4",
            download_size_bytes=1024 * 1024 * 45,
            checksum_sha256="b" * 64,
        )
        media_prem_sub = MediaAsset(
            lesson_id="lesson_prem_1",
            asset_id="asset_prem_1_sub_en",
            kind="subtitle",
            origin_key="courses/premium/lesson1_en.vtt",
        )
        db.add_all([media_free, media_prem, media_prem_sub])

        # Seed entitlements
        active_entitlement = Entitlement(
            learner_id="user_premium",
            source=EntitlementSource.subscription,
            status=EntitlementStatus.active,
            resource_type=ResourceType.course,
            resource_id="course_premium",
            starts_at=datetime.now(UTC) - timedelta(days=5),
            expires_at=datetime.now(UTC) + timedelta(days=25),
        )
        expired_entitlement = Entitlement(
            learner_id="user_expired",
            source=EntitlementSource.subscription,
            status=EntitlementStatus.expired,
            resource_type=ResourceType.course,
            resource_id="course_premium",
            starts_at=datetime.now(UTC) - timedelta(days=40),
            expires_at=datetime.now(UTC) - timedelta(days=10),
        )
        db.add_all([active_entitlement, expired_entitlement])
        await db.commit()

    async def override_get_session():
        async with test_session() as s:
            yield s

    app.dependency_overrides[dep_mod.get_session] = override_get_session
    yield test_session
    app.dependency_overrides.clear()
    await engine.dispose()


async def get_token(client: AsyncClient, email: str) -> str:
    res = await client.post(
        "/api/v1/auth/login",
        json={"email": email, "password": "password12345"},
    )
    return res.json()["accessToken"]


@pytest.mark.asyncio
async def test_free_lesson_download_authorized():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        token = await get_token(client, "free@example.com")
        resp = await client.post(
            "/api/v1/downloads/authorize",
            json={"resourceType": "lesson", "resourceId": "lesson_free_1", "quality": "standard"},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["resourceId"] == "lesson_free_1"
        assert data["courseId"] == "course_free"
        assert data["remoteAssetId"] == "asset_free_1"
        assert data["isDownloadable"] is True
        assert data["sizeBytes"] == 1024 * 1024 * 10
        assert data["checksumSha256"] == "a" * 64
        assert "downloadUrl" in data
        assert "downloadToken" in data
        assert "entitlementExpiresAt" in data


@pytest.mark.asyncio
async def test_download_fails_closed_without_authoritative_checksum(setup_test_db):
    async with setup_test_db() as db:
        asset = await db.scalar(select(MediaAsset).where(MediaAsset.asset_id == "asset_free_1"))
        assert asset is not None
        asset.checksum_sha256 = None
        await db.commit()

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        token = await get_token(client, "free@example.com")
        resp = await client.post(
            "/api/v1/downloads/authorize",
            json={"resourceType": "lesson", "resourceId": "lesson_free_1"},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 503
        assert resp.json()["error"]["code"] == "DOWNLOAD_ASSET_UNVERIFIED"


@pytest.mark.asyncio
async def test_premium_lesson_download_authorized_for_subscriber():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        token = await get_token(client, "premium@example.com")
        resp = await client.post(
            "/api/v1/downloads/authorize",
            json={"resourceType": "lesson", "resourceId": "lesson_prem_1", "quality": "high"},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["resourceId"] == "lesson_prem_1"
        assert data["courseId"] == "course_premium"
        assert data["sizeBytes"] == 1024 * 1024 * 45
        assert data["checksumSha256"] == "b" * 64
        assert len(data["subtitles"]) == 1
        assert data["subtitles"][0]["id"] == "asset_prem_1_sub_en"
        assert data["protectionPolicy"] == "blockCaptureWhereSupported"


@pytest.mark.asyncio
async def test_offline_lease_never_exceeds_short_entitlement_expiry(setup_test_db):
    authoritative_expiry = datetime.now(UTC) + timedelta(minutes=10)
    async with setup_test_db() as db:
        entitlement = await db.scalar(
            select(Entitlement).where(Entitlement.learner_id == "user_premium")
        )
        assert entitlement is not None
        entitlement.expires_at = authoritative_expiry
        await db.commit()

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        token = await get_token(client, "premium@example.com")
        resp = await client.post(
            "/api/v1/downloads/authorize",
            json={"resourceType": "lesson", "resourceId": "lesson_prem_1"},
            headers={"Authorization": f"Bearer {token}"},
        )

    assert resp.status_code == 200
    lease_expiry = datetime.fromisoformat(resp.json()["entitlementExpiresAt"])
    assert lease_expiry <= authoritative_expiry


@pytest.mark.asyncio
async def test_premium_lesson_download_denied_for_free_user():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        token = await get_token(client, "free@example.com")
        resp = await client.post(
            "/api/v1/downloads/authorize",
            json={"resourceType": "lesson", "resourceId": "lesson_prem_1"},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 403
        data = resp.json()
        assert data["error"]["code"] == "ENTITLEMENT_REQUIRED"


@pytest.mark.asyncio
async def test_premium_lesson_download_denied_for_expired_subscriber():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        token = await get_token(client, "expired@example.com")
        resp = await client.post(
            "/api/v1/downloads/authorize",
            json={"resourceType": "lesson", "resourceId": "lesson_prem_1"},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 403
        data = resp.json()
        assert data["error"]["code"] == "ENTITLEMENT_REQUIRED"


@pytest.mark.asyncio
async def test_non_downloadable_lesson_rejected():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        token = await get_token(client, "premium@example.com")
        resp = await client.post(
            "/api/v1/downloads/authorize",
            json={"resourceType": "lesson", "resourceId": "lesson_non_dl"},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 403
        data = resp.json()
        assert data["error"]["code"] == "DOWNLOAD_NOT_PERMITTED"


@pytest.mark.asyncio
async def test_download_revalidation():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        token_prem = await get_token(client, "premium@example.com")
        resp = await client.post(
            "/api/v1/downloads/revalidate",
            json={"resourceIds": ["lesson_prem_1", "lesson_free_1", "non_existent_id"]},
            headers={"Authorization": f"Bearer {token_prem}"},
        )
        assert resp.status_code == 200
        results = {r["resourceId"]: r for r in resp.json()["results"]}
        assert results["lesson_prem_1"]["status"] == "valid"
        assert results["lesson_prem_1"]["entitlementExpiresAt"] is not None
        assert results["lesson_free_1"]["status"] == "valid"
        assert results["non_existent_id"]["status"] == "notFound"

        token_exp = await get_token(client, "expired@example.com")
        resp_exp = await client.post(
            "/api/v1/downloads/revalidate",
            json={"resourceIds": ["lesson_prem_1"]},
            headers={"Authorization": f"Bearer {token_exp}"},
        )
        assert resp_exp.status_code == 200
        exp_res = resp_exp.json()["results"][0]
        assert exp_res["status"] in ("expired", "revoked")
        assert exp_res["entitlementExpiresAt"] is None


@pytest.mark.asyncio
async def test_course_offline_manifest():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        token = await get_token(client, "premium@example.com")
        resp = await client.get(
            "/api/v1/courses/course_premium/offline-manifest",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["courseId"] == "course_premium"
        assert data["totalDownloadableLessons"] == 1
        assert data["totalEstimatedSizeBytes"] == 1024 * 1024 * 45
        assert len(data["modules"]) == 1
        assert len(data["modules"][0]["lessons"]) == 2


def test_download_token_issuance_and_validation():
    settings = get_settings()
    token, _dl_exp, _lease_exp = issue_download_token(
        settings=settings,
        learner_id="user_123",
        asset_id="asset_456",
        lesson_id="lesson_789",
        course_id="course_abc",
        offline_hours=168,
        download_minutes=60,
    )
    assert token is not None
    payload = validate_download_token(settings=settings, token=token, asset_id="asset_456")
    assert payload["sub"] == "user_123"
    assert payload["asset"] == "asset_456"
    assert payload["lesson"] == "lesson_789"
    assert payload["course"] == "course_abc"
    assert "offline_exp" in payload

    with pytest.raises(APIError):
        validate_download_token(settings=settings, token=token, asset_id="wrong_asset")
