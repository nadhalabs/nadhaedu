from datetime import UTC, datetime, timedelta

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool

import app.dependencies as dep_mod
from app.main import app
from app.models import (
    AuditEvent,
    AuthSession,
    Base,
    Certificate,
    CertificateStatus,
    CommerceProductType,
    Course,
    CourseModule,
    Enrollment,
    Lesson,
    Lifecycle,
    PolicyKind,
    Purchase,
    PurchaseStatus,
    User,
    UserRole,
)
from app.security import hash_password, token_hash
from app.services import sanitize_audit_metadata


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
        # Users with different roles
        admin = User(
            id="admin_1",
            email="admin@example.com",
            password_hash=hash_password("AdminPass123!"),
            display_name="Admin User",
            role=UserRole.admin,
            onboarding_complete=True,
        )
        content_mgr = User(
            id="cm_1",
            email="content@example.com",
            password_hash=hash_password("ContentPass123!"),
            display_name="Content Manager",
            role=UserRole.content_manager,
            onboarding_complete=True,
        )
        support = User(
            id="support_1",
            email="support@example.com",
            password_hash=hash_password("SupportPass123!"),
            display_name="Support Staff",
            role=UserRole.support,
            onboarding_complete=True,
        )
        learner = User(
            id="learner_1",
            email="learner@example.com",
            password_hash=hash_password("LearnerPass123!"),
            display_name="Learner One",
            role=UserRole.learner,
            onboarding_complete=True,
        )
        db.add_all([admin, content_mgr, support, learner])

        # Active session for learner
        now_ts = datetime.now(UTC)
        s_learner = AuthSession(
            id="sess_learner",
            user_id="learner_1",
            refresh_token_hash=token_hash("refresh_learner"),
            expires_at=now_ts + timedelta(days=7),
            last_active_at=now_ts,
        )
        db.add(s_learner)

        # Courses
        c1 = Course(
            id="course_1",
            title="Flutter Masterclass",
            subtitle="Deep dive into Flutter",
            level="advanced",
            status=Lifecycle.published,
            policy_kind=PolicyKind.premium,
            published_at=now_ts,
        )
        c2 = Course(
            id="course_2",
            title="Dart Essentials",
            subtitle="Learn Dart from scratch",
            level="beginner",
            status=Lifecycle.draft,
            policy_kind=PolicyKind.free,
        )
        db.add_all([c1, c2])

        m1 = CourseModule(id="mod_1", course_id="course_1", title="Module 1", position=1)
        db.add(m1)

        l1 = Lesson(
            id="less_1",
            module_id="mod_1",
            title="Lesson 1",
            position=1,
            content_type="video",
            content_ref="ref_1",
        )
        db.add(l1)

        # Enrollment
        e1 = Enrollment(id="enr_1", learner_id="learner_1", course_id="course_1")
        db.add(e1)

        # Purchase
        p1 = Purchase(
            id="pur_1",
            learner_id="learner_1",
            product_id="prod_1",
            product_type=CommerceProductType.course,
            order_id="ORD-1001",
            amount_cents=4900,
            currency_code="USD",
            status=PurchaseStatus.completed,
            purchased_at=now_ts,
        )
        db.add(p1)

        # Certificate
        cert1 = Certificate(
            id="cert_1",
            learner_id="learner_1",
            course_id="course_1",
            credential_id="CRED-12345",
            learner_name="Learner One",
            course_title="Flutter Masterclass",
            issued_at=now_ts,
            status=CertificateStatus.issued,
        )
        db.add(cert1)

        # Audit event
        aud1 = AuditEvent(
            id="aud_1",
            actor_id="admin_1",
            event_type="course.status_updated",
            subject_type="course",
            subject_id="course_1",
            occurred_at=now_ts,
            data={"result": "success", "reason": "Initial launch", "metadata": {}},
        )
        db.add(aud1)

        await db.commit()

    async def override_get_session():
        async with test_session() as session:
            yield session

    app.dependency_overrides[dep_mod.get_session] = override_get_session
    yield
    app.dependency_overrides.clear()
    await engine.dispose()


async def get_token_for_user(client: AsyncClient, email: str, password: str) -> str:
    resp = await client.post("/api/v1/auth/login", json={"email": email, "password": password})
    assert resp.status_code == 200, resp.text
    return resp.json()["accessToken"]


@pytest.mark.asyncio
async def test_cms_dashboard_unauthenticated_rejected():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        resp = await client.get("/api/v1/admin/dashboard")
        assert resp.status_code == 401
        assert resp.json()["error"]["code"] == "AUTHENTICATION_REQUIRED"


@pytest.mark.asyncio
async def test_cms_dashboard_learner_role_forbidden():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        token = await get_token_for_user(client, "learner@example.com", "LearnerPass123!")
        resp = await client.get(
            "/api/v1/admin/dashboard", headers={"Authorization": f"Bearer {token}"}
        )
        assert resp.status_code == 403
        assert resp.json()["error"]["code"] == "FORBIDDEN"


@pytest.mark.asyncio
async def test_cms_dashboard_admin_allowed_with_real_metrics():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        token = await get_token_for_user(client, "admin@example.com", "AdminPass123!")
        resp = await client.get(
            "/api/v1/admin/dashboard", headers={"Authorization": f"Bearer {token}"}
        )
        assert resp.status_code == 200
        data = resp.json()
        metrics = data["metrics"]
        assert metrics["totalUsers"] == 4
        assert metrics["totalLearners"] == 1
        assert metrics["totalCourses"] == 2
        assert metrics["publishedCourses"] == 1
        assert metrics["draftCourses"] == 1
        assert metrics["totalEnrollments"] == 1
        assert metrics["totalPurchases"] == 1
        assert metrics["totalCertificatesIssued"] == 1

        # Recent purchases
        assert len(data["recentPurchases"]) == 1
        assert data["recentPurchases"][0]["orderId"] == "ORD-1001"

        # Recent activity
        assert len(data["recentActivity"]) >= 1
        assert data["recentActivity"][0]["action"] == "course.status_updated"
        assert data["recentActivity"][0]["actorEmail"] == "admin@example.com"

        # System readiness
        assert data["systemReadiness"]["isReady"] is True
        assert len(data["systemReadiness"]["warnings"]) > 0


@pytest.mark.asyncio
async def test_cms_dashboard_content_manager_and_support_allowed():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        cm_token = await get_token_for_user(client, "content@example.com", "ContentPass123!")
        resp1 = await client.get(
            "/api/v1/admin/dashboard", headers={"Authorization": f"Bearer {cm_token}"}
        )
        assert resp1.status_code == 200

        sup_token = await get_token_for_user(client, "support@example.com", "SupportPass123!")
        resp2 = await client.get(
            "/api/v1/admin/dashboard", headers={"Authorization": f"Bearer {sup_token}"}
        )
        assert resp2.status_code == 200


@pytest.mark.asyncio
async def test_cms_courses_list_and_status_update():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        cm_token = await get_token_for_user(client, "content@example.com", "ContentPass123!")

        # List courses
        resp = await client.get(
            "/api/v1/admin/courses", headers={"Authorization": f"Bearer {cm_token}"}
        )
        assert resp.status_code == 200
        courses = resp.json()["items"]
        assert len(courses) == 2

        # Update course 2 status from draft to published
        status_resp = await client.post(
            "/api/v1/admin/courses/course_2/status",
            headers={"Authorization": f"Bearer {cm_token}"},
            json={"status": "published", "reason": "Ready for student enrollment"},
        )
        assert status_resp.status_code == 200
        updated = status_resp.json()
        assert updated["status"] == "published"
        assert updated["publishedAt"] is not None

        # Check audit log was created
        support_token = await get_token_for_user(client, "support@example.com", "SupportPass123!")
        audit_resp = await client.get(
            "/api/v1/admin/audit-logs",
            headers={"Authorization": f"Bearer {support_token}"},
            params={"eventType": "course.status_updated", "subjectId": "course_2"},
        )
        assert audit_resp.status_code == 200
        audit_items = audit_resp.json()["items"]
        assert audit_items
        assert all(item["targetId"] == "course_2" for item in audit_items)


@pytest.mark.asyncio
async def test_content_manager_cannot_query_security_audit_explorer():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        token = await get_token_for_user(client, "content@example.com", "ContentPass123!")
        response = await client.get(
            "/api/v1/admin/audit-logs", headers={"Authorization": f"Bearer {token}"}
        )
        assert response.status_code == 403
        assert response.json()["error"]["code"] == "FORBIDDEN"


@pytest.mark.asyncio
async def test_cms_support_role_cannot_update_course_status():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        sup_token = await get_token_for_user(client, "support@example.com", "SupportPass123!")
        resp = await client.post(
            "/api/v1/admin/courses/course_2/status",
            headers={"Authorization": f"Bearer {sup_token}"},
            json={"status": "published"},
        )
        assert resp.status_code == 403


@pytest.mark.asyncio
async def test_cms_users_list_support_allowed():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        sup_token = await get_token_for_user(client, "support@example.com", "SupportPass123!")
        resp = await client.get(
            "/api/v1/admin/users", headers={"Authorization": f"Bearer {sup_token}"}
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["total"] == 4
        users = data["items"]
        assert any(u["role"] == "learner" and u["enrollmentCount"] == 1 for u in users)


@pytest.mark.asyncio
async def test_audit_metadata_sanitization():
    raw_metadata = {
        "userId": "u1",
        "courseId": "c1",
        "password": "secret_password",
        "accessToken": "secret_token",
        "nested": {
            "safeField": "visible",
            "receiptPayload": "sensitive_receipt",
        },
    }
    cleaned = sanitize_audit_metadata(raw_metadata)
    assert "userId" in cleaned
    assert "courseId" in cleaned
    assert "password" not in cleaned
    assert "accessToken" not in cleaned
    assert cleaned["nested"] == {"safeField": "visible"}
