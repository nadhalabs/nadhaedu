from datetime import UTC, datetime, timedelta

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool

import app.dependencies as dep_mod
from app.main import app
from app.models import (
    AuditEvent,
    AuthSession,
    Base,
    Course,
    Lifecycle,
    PolicyKind,
    User,
    UserRole,
)
from app.security import access_token, hash_password, token_hash


@pytest_asyncio.fixture(autouse=True)
async def database():
    engine = create_async_engine(
        "sqlite+aiosqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)
    factory = async_sessionmaker(engine, expire_on_commit=False)
    now = datetime.now(UTC)
    async with factory() as db:
        users = [
            User(
                id="owner",
                email="owner@example.com",
                password_hash=hash_password("OwnerPass123!"),
                display_name="Owner",
                role=UserRole.super_admin,
                onboarding_complete=True,
            ),
            User(
                id="admin",
                email="admin@example.com",
                password_hash=hash_password("AdminPass123!"),
                display_name="Admin",
                role=UserRole.admin,
                onboarding_complete=True,
            ),
            User(
                id="support",
                email="support@example.com",
                password_hash=hash_password("SupportPass123!"),
                display_name="Support",
                role=UserRole.support,
                onboarding_complete=True,
            ),
            User(
                id="learner",
                email="learner@example.com",
                password_hash=hash_password("LearnerPass123!"),
                display_name="Learner",
                role=UserRole.learner,
                onboarding_complete=True,
            ),
        ]
        db.add_all(users)
        for user in users:
            db.add(
                AuthSession(
                    id=f"session-{user.id}",
                    user_id=user.id,
                    refresh_token_hash=token_hash(f"refresh-{user.id}"),
                    expires_at=now + timedelta(days=1),
                )
            )
        db.add(
            Course(
                id="course",
                title="Course",
                subtitle="",
                level="all",
                status=Lifecycle.published,
                policy_kind=PolicyKind.premium,
                published_at=now,
            )
        )
        await db.commit()

    async def override_session():
        async with factory() as db:
            yield db

    app.dependency_overrides[dep_mod.get_session] = override_session
    yield factory
    app.dependency_overrides.clear()
    await engine.dispose()


def headers(user_id: str, role: UserRole):
    token, _ = access_token(user_id, f"session-{user_id}", role.value)
    return {"Authorization": f"Bearer {token}"}


@pytest.mark.asyncio
async def test_learner_search_detail_and_support_boundaries():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        response = await client.get(
            "/api/v1/admin/learners?search=learner", headers=headers("support", UserRole.support)
        )
        assert response.status_code == 200
        assert response.json()["items"][0]["email"] == "learner@example.com"
        detail = await client.get(
            "/api/v1/admin/learners/learner", headers=headers("support", UserRole.support)
        )
        assert detail.status_code == 200
        assert "passwordHash" not in str(detail.json())
        denied = await client.get(
            "/api/v1/admin/commerce", headers=headers("support", UserRole.support)
        )
        assert denied.status_code == 403


@pytest.mark.asyncio
async def test_manual_entitlement_reason_audit_and_stale_version(database):
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        missing_reason = await client.post(
            "/api/v1/admin/learners/learner/entitlements",
            json={"resourceType": "course", "resourceId": "course", "reason": "short"},
            headers=headers("admin", UserRole.admin),
        )
        assert missing_reason.status_code == 422
        granted = await client.post(
            "/api/v1/admin/learners/learner/entitlements",
            json={
                "resourceType": "course",
                "resourceId": "course",
                "reason": "Approved support review",
            },
            headers=headers("admin", UserRole.admin),
        )
        assert granted.status_code == 201
        item = granted.json()
        assert item["source"] == "admin_grant"
        expiry = (datetime.now(UTC) + timedelta(days=14)).isoformat()
        extended = await client.post(
            f"/api/v1/admin/entitlements/{item['id']}/extend",
            json={
                "expectedVersion": 1,
                "expiresAt": expiry,
                "reason": "Extend after support evidence",
            },
            headers=headers("admin", UserRole.admin),
        )
        assert extended.status_code == 200 and extended.json()["version"] == 2
        stale = await client.post(
            f"/api/v1/admin/entitlements/{item['id']}/revoke",
            json={"expectedVersion": 1, "reason": "Revoke after duplicate evidence"},
            headers=headers("admin", UserRole.admin),
        )
        assert stale.status_code == 409
    async with database() as db:
        events = (
            await db.scalars(select(AuditEvent).where(AuditEvent.subject_type == "entitlement"))
        ).all()
        assert len(events) == 2


@pytest.mark.asyncio
async def test_super_admin_is_server_enforced_and_last_owner_protected():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        denied = await client.get(
            "/api/v1/admin/super/admins", headers=headers("admin", UserRole.admin)
        )
        assert denied.status_code == 403
        self_promote = await client.post(
            "/api/v1/admin/super/admins/admin/role",
            json={"role": "super_admin", "reason": "Unauthorized privilege attempt"},
            headers=headers("admin", UserRole.admin),
        )
        assert self_promote.status_code == 403
        last_owner = await client.post(
            "/api/v1/admin/super/users/owner/suspend",
            json={"reason": "Would lock out platform ownership"},
            headers=headers("owner", UserRole.super_admin),
        )
        assert last_owner.status_code == 409


@pytest.mark.asyncio
async def test_suspended_account_cannot_login_or_refresh_and_existing_session_is_revoked(database):
    async with database() as db:
        learner = await db.get(User, "learner")
        learner.is_active = False
        learner.suspended_at = datetime.now(UTC)
        await db.commit()

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        login_response = await client.post(
            "/api/v1/auth/login",
            json={"email": "learner@example.com", "password": "LearnerPass123!"},
        )
        assert login_response.status_code == 401
        assert login_response.json()["error"]["code"] == "ACCOUNT_UNAVAILABLE"

        refresh_response = await client.post(
            "/api/v1/auth/refresh", json={"refreshToken": "refresh-learner"}
        )
        assert refresh_response.status_code == 401
        assert refresh_response.json()["error"]["code"] == "ACCOUNT_UNAVAILABLE"

    async with database() as db:
        session = await db.get(AuthSession, "session-learner")
        assert session.revoked_at is not None


@pytest.mark.asyncio
async def test_access_token_is_rejected_after_authoritative_session_expiry(database):
    async with database() as db:
        await db.execute(
            update(AuthSession)
            .where(AuthSession.id == "session-admin")
            .values(expires_at=datetime.now(UTC) - timedelta(seconds=1))
        )
        await db.commit()

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        response = await client.get(
            "/api/v1/admin/commerce", headers=headers("admin", UserRole.admin)
        )
        assert response.status_code == 401
        assert response.json()["error"]["code"] == "SESSION_EXPIRED"


@pytest.mark.asyncio
async def test_platform_settings_are_typed_versioned_and_enforced(database):
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        unknown = await client.put(
            "/api/v1/admin/super/settings/arbitrary_secret",
            json={"value": True, "expectedVersion": 0, "reason": "Unsafe arbitrary configuration"},
            headers=headers("owner", UserRole.super_admin),
        )
        assert unknown.status_code == 422
        changed = await client.put(
            "/api/v1/admin/super/settings/registrations_enabled",
            json={"value": False, "expectedVersion": 0, "reason": "Emergency abuse response"},
            headers=headers("owner", UserRole.super_admin),
        )
        assert changed.status_code == 200 and changed.json()["version"] == 1
        stale = await client.put(
            "/api/v1/admin/super/settings/registrations_enabled",
            json={"value": True, "expectedVersion": 0, "reason": "Stale operator action"},
            headers=headers("owner", UserRole.super_admin),
        )
        assert stale.status_code == 409
        registration = await client.post(
            "/api/v1/auth/register",
            json={"email": "new@example.com", "password": "NewPass123!", "displayName": "New"},
        )
        assert registration.status_code == 503


@pytest.mark.asyncio
async def test_notification_and_integrations_do_not_claim_delivery_or_leak_secrets():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        created = await client.post(
            "/api/v1/admin/notifications",
            json={"userId": "learner", "title": "Notice", "body": "Operational message"},
            headers=headers("admin", UserRole.admin),
        )
        assert created.status_code == 201
        assert created.json() == {
            "id": created.json()["id"],
            "deliveryState": "createdInApp",
            "delivered": False,
        }
        integrations = await client.get(
            "/api/v1/admin/super/integrations", headers=headers("owner", UserRole.super_admin)
        )
        payload = str(integrations.json()).lower()
        assert integrations.status_code == 200
        assert "development-only-change-me" not in payload
        assert "private_key" not in payload and "api_key" not in payload


@pytest.mark.asyncio
@pytest.mark.parametrize("value", [None, True, False])
async def test_registration_flag_and_production_restart(database, monkeypatch, value):
    from types import SimpleNamespace
    from unittest.mock import AsyncMock, Mock

    from test_hardening import production_settings

    from app import main
    from app.models import PlatformSetting
    from app.rate_limit import DistributedRateLimiter

    async with database() as db:
        db.add(PlatformSetting(key="maintenance_mode", value=True, description="Test"))
        await db.commit()
    if value is not None:
        async with database() as db:
            db.add(PlatformSetting(key="registrations_enabled", value=value, description="Test"))
            await db.commit()
    configured = production_settings()
    redis = SimpleNamespace(eval=AsyncMock(return_value=[1, 900]), aclose=AsyncMock())
    factory = Mock(kw={"bind": SimpleNamespace(dispose=AsyncMock())})
    monkeypatch.setattr(main, "settings", configured)
    monkeypatch.setattr(main.Redis, "from_url", Mock(return_value=redis))
    monkeypatch.setattr(main, "session_factory", Mock(return_value=factory))
    # Lifespan replaces these; restore them for other tests.
    for name in (
        "settings",
        "logger",
        "metrics",
        "redis",
        "rate_limiter",
        "password_reset_delivery",
    ):
        monkeypatch.setattr(app.state, name, getattr(app.state, name))
    for _ in range(2):
        async with main.lifespan(app):
            assert isinstance(app.state.rate_limiter, DistributedRateLimiter)
            async with AsyncClient(
                transport=ASGITransport(app=app), base_url="https://api.example.com"
            ) as client:
                listing = await client.get(
                    "/api/v1/admin/super/settings", headers=headers("owner", UserRole.super_admin)
                )
                setting = next(
                    x for x in listing.json()["items"] if x["key"] == "registrations_enabled"
                )
                assert setting["value"] is (True if value is None else value)
        async with database() as db:
            stored = await db.get(PlatformSetting, "registrations_enabled")
            if value is None:
                assert stored is None  # Neither startup nor CMS reads seed overrides.
            else:
                assert stored.value is value and stored.version == 1
    logger = Mock()
    monkeypatch.setattr(app.state, "logger", logger)
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="https://api.example.com"
    ) as client:
        response = await client.post(
            "/api/v1/auth/register",
            json={"email": "new@example.com", "password": "NewPass123!", "displayName": "New"},
        )
    assert response.status_code == (503 if value is False else 201)
    if value is False:
        assert response.json()["error"]["code"] == "REGISTRATIONS_DISABLED"
        fields = logger.info.call_args.kwargs["extra"]["fields"]
        assert fields["route"] == "/api/v1/auth/register"
        assert fields["error_code"] == "REGISTRATIONS_DISABLED"
    async with database() as db:
        user = await db.scalar(select(User).where(User.email == "new@example.com"))
        assert (user is not None) is (value is not False)


@pytest.mark.asyncio
async def test_enable_registration_preserves_versions_and_audit(database):
    from app.models import PlatformSetting

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        for version, value in enumerate([False, True]):
            response = await client.put(
                "/api/v1/admin/super/settings/registrations_enabled",
                headers=headers("owner", UserRole.super_admin),
                json={
                    "value": value,
                    "expectedVersion": version,
                    "reason": "Reviewed registration control",
                },
            )
            assert response.status_code == 200
            assert response.json()["version"] == version + 1
        response = await client.post(
            "/api/v1/auth/register",
            json={"email": "new@example.com", "password": "NewPass123!", "displayName": "New"},
        )
        assert response.status_code == 201
    async with database() as db:
        setting = await db.get(PlatformSetting, "registrations_enabled")
        assert setting.value is True and setting.version == 2 and setting.updated_by == "owner"
        events = (
            await db.scalars(
                select(AuditEvent)
                .where(AuditEvent.subject_id == "registrations_enabled")
                .order_by(AuditEvent.occurred_at)
            )
        ).all()
        assert len(events) == 2
        assert all(event.actor_id == "owner" for event in events)
        assert events[-1].data["metadata"]["previousState"] is False
        assert events[-1].data["metadata"]["newState"] is True
        assert events[-1].data["metadata"]["version"] == 2


@pytest.mark.asyncio
async def test_production_seed_refuses_before_database_access(monkeypatch):
    from unittest.mock import Mock

    from test_hardening import production_settings

    import app.seed_staging as seed

    monkeypatch.setattr(seed, "get_settings", production_settings)
    factory = Mock()
    monkeypatch.setattr(seed, "session_factory", factory)
    monkeypatch.setenv("ALLOW_STAGING_SEED", "true")
    with pytest.raises(RuntimeError, match="Staging seed is disabled"):
        await seed.seed()
    factory.assert_not_called()
