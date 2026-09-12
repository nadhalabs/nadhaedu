import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool

import app.dependencies as dep_mod
from app.main import app
from app.models import (
    Base,
    Notification,
    NotificationPriority,
    NotificationType,
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
        u1 = User(
            id="user_1",
            email="user1@example.com",
            password_hash=hash_password("Password123!"),
            display_name="Learner One",
            phone="+1234567890",
            learning_interests=["Flutter", "Dart"],
            language_preference="en",
            onboarding_complete=True,
        )
        u2 = User(
            id="user_2",
            email="user2@example.com",
            password_hash=hash_password("Password123!"),
            display_name="Learner Two",
            onboarding_complete=True,
        )
        db.add_all([u1, u2])

        # Notifications for user 1
        n1 = Notification(
            id="notif_1",
            user_id="user_1",
            type=NotificationType.course_update,
            title="Course Updated",
            body="New lessons added to Flutter 101",
            destination_type="course",
            destination_payload={"courseId": "c1"},
            priority=NotificationPriority.normal,
        )
        n2 = Notification(
            id="notif_2",
            user_id="user_1",
            type=NotificationType.certificate_issued,
            title="Certificate Ready",
            body="Congratulations on completing the course!",
            destination_type="certificate",
            destination_payload={"certificateId": "cert_1"},
            priority=NotificationPriority.high,
        )
        # Notification for user 2
        n3 = Notification(
            id="notif_3",
            user_id="user_2",
            type=NotificationType.system_announcement,
            title="System Maintenance",
            body="Maintenance tonight at 2 AM",
            destination_type="none",
            destination_payload={},
            priority=NotificationPriority.low,
        )
        db.add_all([n1, n2, n3])
        await db.commit()

    async def override_get_session():
        async with test_session() as session:
            yield session

    app.dependency_overrides[dep_mod.get_session] = override_get_session
    yield
    app.dependency_overrides.clear()
    await engine.dispose()


async def get_auth_token(
    client: AsyncClient, email: str = "user1@example.com", password: str = "Password123!"
):
    resp = await client.post("/api/v1/auth/login", json={"email": email, "password": password})
    assert resp.status_code == 200
    data = resp.json()
    return data["accessToken"], data["sessionId"]


@pytest.mark.asyncio
async def test_notifications_pagination_and_unread_count():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        token, _ = await get_auth_token(client)
        resp = await client.get(
            "/api/v1/notifications", headers={"Authorization": f"Bearer {token}"}
        )
        assert resp.status_code == 200
        data = resp.json()
        assert "items" in data
        assert len(data["items"]) == 2
        assert data["unreadCount"] == 2
        assert data["items"][0]["title"] in ["Course Updated", "Certificate Ready"]


@pytest.mark.asyncio
async def test_notification_mark_read_and_read_all():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        token, _ = await get_auth_token(client)

        # Mark single read
        resp = await client.post(
            "/api/v1/notifications/notif_1/read", headers={"Authorization": f"Bearer {token}"}
        )
        assert resp.status_code == 200
        assert resp.json()["notification"]["readAt"] is not None

        # Check unread count is now 1
        resp = await client.get(
            "/api/v1/notifications", headers={"Authorization": f"Bearer {token}"}
        )
        assert resp.json()["unreadCount"] == 1

        # Mark all read
        resp = await client.post(
            "/api/v1/notifications/read-all", headers={"Authorization": f"Bearer {token}"}
        )
        assert resp.status_code == 200
        assert resp.json()["markedCount"] == 1

        # Check unread count is now 0
        resp = await client.get(
            "/api/v1/notifications", headers={"Authorization": f"Bearer {token}"}
        )
        assert resp.json()["unreadCount"] == 0


@pytest.mark.asyncio
async def test_notification_cross_user_isolation():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        token, _ = await get_auth_token(client, email="user1@example.com")

        # user 1 cannot mark user 2's notification as read
        resp = await client.post(
            "/api/v1/notifications/notif_3/read", headers={"Authorization": f"Bearer {token}"}
        )
        assert resp.status_code == 404


@pytest.mark.asyncio
async def test_notification_preferences_get_and_update():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        token, _ = await get_auth_token(client)

        # Get defaults
        resp = await client.get(
            "/api/v1/notifications/preferences", headers={"Authorization": f"Bearer {token}"}
        )
        assert resp.status_code == 200
        prefs = resp.json()["preferences"]
        assert prefs["pushCourseUpdates"] is True
        assert prefs["emailSecurityAlerts"] is True

        # Update
        resp = await client.put(
            "/api/v1/notifications/preferences",
            headers={"Authorization": f"Bearer {token}"},
            json={"pushCourseUpdates": False, "emailMarketing": True},
        )
        assert resp.status_code == 200
        updated = resp.json()["preferences"]
        assert updated["pushCourseUpdates"] is False
        assert updated["emailMarketing"] is True
        assert updated["emailSecurityAlerts"] is True  # Non-suppressible


@pytest.mark.asyncio
async def test_push_token_registration_and_revocation():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        token, _ = await get_auth_token(client)

        # Register token
        resp = await client.post(
            "/api/v1/notifications/push-tokens",
            headers={"Authorization": f"Bearer {token}"},
            json={"token": "test_fcm_token_12345", "platform": "android", "deviceName": "Pixel 8"},
        )
        assert resp.status_code == 200
        assert resp.json()["success"] is True

        # Revoke token
        resp = await client.delete(
            "/api/v1/notifications/push-tokens/test_fcm_token_12345",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 204


@pytest.mark.asyncio
async def test_push_token_cannot_be_reassigned_to_another_user():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        token1, _ = await get_auth_token(client, "user1@example.com")
        token2, _ = await get_auth_token(client, "user2@example.com")
        push_token = "shared_fcm_token_123456789"

        first = await client.post(
            "/api/v1/notifications/push-tokens",
            headers={"Authorization": f"Bearer {token1}"},
            json={"token": push_token, "platform": "android"},
        )
        assert first.status_code == 200

        conflict = await client.post(
            "/api/v1/notifications/push-tokens",
            headers={"Authorization": f"Bearer {token2}"},
            json={"token": push_token, "platform": "android"},
        )
        assert conflict.status_code == 409
        assert conflict.json()["error"]["code"] == "PUSH_TOKEN_OWNERSHIP_CONFLICT"


@pytest.mark.asyncio
async def test_learner_profile_get_and_update():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        token, _ = await get_auth_token(client)

        # Get profile
        resp = await client.get("/api/v1/profile", headers={"Authorization": f"Bearer {token}"})
        assert resp.status_code == 200
        profile = resp.json()["profile"]
        assert profile["displayName"] == "Learner One"
        assert profile["learningInterests"] == ["Flutter", "Dart"]

        # Update profile
        resp = await client.put(
            "/api/v1/profile",
            headers={"Authorization": f"Bearer {token}"},
            json={
                "displayName": "Senior Learner",
                "phone": "+9876543210",
                "learningInterests": ["Flutter", "Architecture", "Cloud"],
                "languagePreference": "es",
            },
        )
        assert resp.status_code == 200
        updated = resp.json()["profile"]
        assert updated["displayName"] == "Senior Learner"
        assert updated["phone"] == "+9876543210"
        assert "Architecture" in updated["learningInterests"]
        assert updated["languagePreference"] == "es"


@pytest.mark.asyncio
async def test_avatar_upload_intent_and_update():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        token, _ = await get_auth_token(client)

        resp = await client.post(
            "/api/v1/profile/avatar/upload-url", headers={"Authorization": f"Bearer {token}"}
        )
        assert resp.status_code == 200
        data = resp.json()
        assert "uploadUrl" in data
        assert "publicUrl" in data
        assert data["maxBytes"] == 5 * 1024 * 1024

        resp = await client.post(
            "/api/v1/profile/avatar",
            headers={"Authorization": f"Bearer {token}"},
            json={"avatarUrl": data["publicUrl"]},
        )
        assert resp.status_code == 200
        assert resp.json()["avatarUrl"] == data["publicUrl"]


@pytest.mark.asyncio
async def test_session_listing_and_individual_revocation():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # Create 2 sessions
        token1, sid1 = await get_auth_token(client)
        token2, sid2 = await get_auth_token(client)

        resp = await client.get(
            "/api/v1/account/sessions", headers={"Authorization": f"Bearer {token2}"}
        )
        assert resp.status_code == 200
        sessions = resp.json()["sessions"]
        assert len(sessions) >= 2

        # Check current session marking
        current_session = next((s for s in sessions if s["id"] == sid2), None)
        assert current_session is not None
        assert current_session["isCurrent"] is True

        other_session = next((s for s in sessions if s["id"] == sid1), None)
        assert other_session is not None
        assert other_session["isCurrent"] is False

        # Revoke session 1
        resp = await client.post(
            f"/api/v1/account/sessions/{sid1}/revoke", headers={"Authorization": f"Bearer {token2}"}
        )
        assert resp.status_code == 200

        # Session 1 token should now be rejected as revoked
        resp = await client.get("/api/v1/profile", headers={"Authorization": f"Bearer {token1}"})
        assert resp.status_code == 401
        assert resp.json()["error"]["code"] == "SESSION_REVOKED"


@pytest.mark.asyncio
async def test_revoke_other_sessions():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        token1, _ = await get_auth_token(client)
        await get_auth_token(client)
        token3, _ = await get_auth_token(client)

        # Using token 3, revoke others
        resp = await client.post(
            "/api/v1/account/sessions/revoke-others", headers={"Authorization": f"Bearer {token3}"}
        )
        assert resp.status_code == 200
        assert resp.json()["revokedCount"] >= 2

        # Tokens 1 & 2 are now revoked
        resp1 = await client.get("/api/v1/profile", headers={"Authorization": f"Bearer {token1}"})
        assert resp1.status_code == 401

        # Token 3 remains valid
        resp3 = await client.get("/api/v1/profile", headers={"Authorization": f"Bearer {token3}"})
        assert resp3.status_code == 200


@pytest.mark.asyncio
async def test_synced_user_settings_get_and_update():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        token, _ = await get_auth_token(client)

        # Get settings
        resp = await client.get("/api/v1/settings", headers={"Authorization": f"Bearer {token}"})
        assert resp.status_code == 200
        st = resp.json()["settings"]
        assert st["themeMode"] == "system"
        assert st["downloadWifiOnly"] is True

        # Update settings
        resp = await client.put(
            "/api/v1/settings",
            headers={"Authorization": f"Bearer {token}"},
            json={
                "themeMode": "dark",
                "autoplayNextLesson": False,
                "preferredPlaybackSpeed": 1.25,
                "reducedMotion": True,
                "downloadQuality": "high",
            },
        )
        assert resp.status_code == 200
        updated = resp.json()["settings"]
        assert updated["themeMode"] == "dark"
        assert updated["autoplayNextLesson"] is False
        assert updated["preferredPlaybackSpeed"] == 1.25
        assert updated["reducedMotion"] is True
        assert updated["downloadQuality"] == "high"


@pytest.mark.asyncio
async def test_account_deletion_with_confirmation():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        token, _ = await get_auth_token(client, email="user2@example.com")

        # Wrong confirmation text
        resp = await client.post(
            "/api/v1/account/delete",
            headers={"Authorization": f"Bearer {token}"},
            json={"password": "Password123!", "confirmationText": "NO"},
        )
        assert resp.status_code == 400

        # Wrong password
        resp = await client.post(
            "/api/v1/account/delete",
            headers={"Authorization": f"Bearer {token}"},
            json={"password": "WrongPassword", "confirmationText": "DELETE"},
        )
        assert resp.status_code == 400

        # Valid deletion
        resp = await client.post(
            "/api/v1/account/delete",
            headers={"Authorization": f"Bearer {token}"},
            json={"password": "Password123!", "confirmationText": "DELETE"},
        )
        assert resp.status_code == 200

        # Login should now fail because user is deleted
        login_resp = await client.post(
            "/api/v1/auth/login", json={"email": "user2@example.com", "password": "Password123!"}
        )
        assert login_resp.status_code == 401


@pytest.mark.asyncio
async def test_legacy_account_deletion_endpoint_requires_password_confirmation():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        token, _ = await get_auth_token(client, email="user1@example.com")

        response = await client.post(
            "/api/v1/auth/delete-account",
            headers={"Authorization": f"Bearer {token}"},
        )

        assert response.status_code == 410
        assert response.json()["error"]["code"] == "PASSWORD_CONFIRMATION_REQUIRED"
        assert (
            await client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {token}"})
        ).status_code == 200


@pytest.mark.asyncio
async def test_mark_all_notifications_read_set_based():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        token, _ = await get_auth_token(client, email="user1@example.com")
        headers = {"Authorization": f"Bearer {token}"}

        # Check initial unread count (2 unread notifications for user 1)
        resp = await client.get("/api/v1/notifications", headers=headers)
        assert resp.status_code == 200
        data = resp.json()
        assert data["unreadCount"] == 2

        # Mark all read
        mark_resp = await client.post("/api/v1/notifications/read-all", headers=headers)
        assert mark_resp.status_code == 200
        assert mark_resp.json()["markedCount"] == 2

        # Verify unread count is now 0
        resp_after = await client.get("/api/v1/notifications", headers=headers)
        assert resp_after.status_code == 200
        assert resp_after.json()["unreadCount"] == 0

        # Verify second user's notification is still unread
        token2, _ = await get_auth_token(client, email="user2@example.com")
        resp2 = await client.get(
            "/api/v1/notifications", headers={"Authorization": f"Bearer {token2}"}
        )
        assert resp2.status_code == 200
        assert resp2.json()["unreadCount"] == 1


@pytest.mark.asyncio
async def test_commerce_catalog_batching_and_purchase_cursor_pagination():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # Check plans and courses catalog endpoints
        plans_resp = await client.get("/api/v1/commerce/plans")
        assert plans_resp.status_code == 200
        assert "items" in plans_resp.json()

        courses_resp = await client.get("/api/v1/commerce/products/courses")
        assert courses_resp.status_code == 200
        assert "items" in courses_resp.json()

        bundles_resp = await client.get("/api/v1/commerce/products/bundles")
        assert bundles_resp.status_code == 200
        assert "items" in bundles_resp.json()

        # Check purchases cursor pagination
        token, _ = await get_auth_token(client, email="user1@example.com")
        purchases_resp = await client.get(
            "/api/v1/commerce/purchases?limit=10",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert purchases_resp.status_code == 200
        purchases_data = purchases_resp.json()
        assert "items" in purchases_data
        assert "nextCursor" in purchases_data

        invalid_cursor = await client.get(
            "/api/v1/commerce/purchases?cursor=not-a-cursor",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert invalid_cursor.status_code == 400
