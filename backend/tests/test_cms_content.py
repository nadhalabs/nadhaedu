import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool

import app.dependencies as dep_mod
from app.main import app
from app.models import (
    Base,
    User,
    UserRole,
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
async def test_category_management():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        support_token = await get_token_for_user(client, "support@example.com", "SupportPass123!")
        cm_token = await get_token_for_user(client, "content@example.com", "ContentPass123!")

        # Support cannot create categories (403)
        res_sup = await client.post(
            "/api/v1/admin/categories",
            json={"name": "Cloud Computing", "iconName": "cloud"},
            headers={"Authorization": f"Bearer {support_token}"},
        )
        assert res_sup.status_code == 403

        # Content Manager creates category
        res = await client.post(
            "/api/v1/admin/categories",
            json={"name": "Cloud Computing", "iconName": "cloud"},
            headers={"Authorization": f"Bearer {cm_token}"},
        )
        assert res.status_code == 201
        data = res.json()
        assert data["name"] == "Cloud Computing"

        # Categories list
        list_res = await client.get(
            "/api/v1/admin/categories", headers={"Authorization": f"Bearer {cm_token}"}
        )
        assert list_res.status_code == 200
        names = [c["name"] for c in list_res.json()]
        assert "Cloud Computing" in names


@pytest.mark.asyncio
async def test_course_crud_and_curriculum_workflow():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        cm_token = await get_token_for_user(client, "content@example.com", "ContentPass123!")
        headers = {"Authorization": f"Bearer {cm_token}"}

        # 1. Create Category
        cat_res = await client.post(
            "/api/v1/admin/categories",
            json={"name": "DevOps & SRE", "iconName": "build"},
            headers=headers,
        )
        assert cat_res.status_code == 201
        cat_id = cat_res.json()["id"]

        # 2. Create Course
        course_res = await client.post(
            "/api/v1/admin/courses",
            json={
                "title": "Kubernetes Mastery",
                "subtitle": "From beginner to production cluster operator",
                "description": "Comprehensive hands-on guide to container orchestration and production deployments.",
                "level": "intermediate",
                "languageCode": "en",
                "policyKind": "premium",
                "protectionPolicy": "blockCaptureWhereSupported",
                "categoryIds": [cat_id],
                "tags": ["kubernetes", "devops", "cloud"],
                "learningOutcomes": ["Deploy microservices", "Manage cluster state"],
                "prerequisites": ["Linux fundamentals", "Docker basics"],
            },
            headers=headers,
        )
        assert course_res.status_code == 201
        course = course_res.json()
        course_id = course["id"]
        assert course["title"] == "Kubernetes Mastery"
        assert course["status"] == "draft"
        assert len(course["categories"]) == 1
        assert course["categories"][0]["name"] == "DevOps & SRE"
        assert course["validation"]["isValid"] is False  # Missing modules

        # 3. Add Module (Section)
        mod_res = await client.post(
            f"/api/v1/admin/courses/{course_id}/modules",
            json={"title": "Introduction to Pods & Services", "policyKind": "inherit"},
            headers=headers,
        )
        assert mod_res.status_code == 201
        module = mod_res.json()
        mod_id = module["id"]
        assert module["title"] == "Introduction to Pods & Services"
        assert module["position"] == 1

        # 4. Add Lesson 1
        lesson1_res = await client.post(
            f"/api/v1/admin/courses/{course_id}/modules/{mod_id}/lessons",
            json={
                "title": "What is a Kubernetes Pod?",
                "durationSeconds": 480,
                "contentType": "video",
                "contentRef": "k8s-pod-intro-vid",
                "isPreview": True,
                "isDownloadable": True,
            },
            headers=headers,
        )
        assert lesson1_res.status_code == 201
        lesson1 = lesson1_res.json()
        assert lesson1["title"] == "What is a Kubernetes Pod?"
        assert lesson1["durationSeconds"] == 480
        assert lesson1["position"] == 1

        # 5. Add Lesson 2
        lesson2_res = await client.post(
            f"/api/v1/admin/courses/{course_id}/modules/{mod_id}/lessons",
            json={
                "title": "Configuring Services & Networking",
                "durationSeconds": 600,
                "contentType": "video",
                "contentRef": "k8s-svc-networking-vid",
                "isPreview": False,
                "isDownloadable": True,
            },
            headers=headers,
        )
        assert lesson2_res.status_code == 201
        lesson2 = lesson2_res.json()
        assert lesson2["position"] == 2

        # 6. Reorder Lessons
        reorder_res = await client.post(
            f"/api/v1/admin/courses/{course_id}/modules/{mod_id}/lessons/reorder",
            json={"lessonIds": [lesson2["id"], lesson1["id"]]},
            headers=headers,
        )
        assert reorder_res.status_code == 200
        reordered = reorder_res.json()
        assert reordered[0]["id"] == lesson2["id"]
        assert reordered[0]["position"] == 1
        assert reordered[1]["id"] == lesson1["id"]
        assert reordered[1]["position"] == 2

        # 7. Check Course Validation Report
        val_res = await client.get(
            f"/api/v1/admin/courses/{course_id}/validate",
            headers=headers,
        )
        assert val_res.status_code == 200
        validation = val_res.json()
        assert validation["canPublish"] is True

        # 8. Publish Course
        pub_res = await client.post(
            f"/api/v1/admin/courses/{course_id}/publish",
            json={"reason": "Curriculum reviewed and ready for release"},
            headers=headers,
        )
        assert pub_res.status_code == 200
        published_course = pub_res.json()
        assert published_course["status"] == "published"
        assert published_course["durationSeconds"] == 1080  # 480 + 600
        assert published_course["publishedAt"] is not None

        # 9. Unpublish Course
        unpub_res = await client.post(
            f"/api/v1/admin/courses/{course_id}/unpublish",
            json={"reason": "Fixing typo in section"},
            headers=headers,
        )
        assert unpub_res.status_code == 200
        assert unpub_res.json()["status"] == "draft"


@pytest.mark.asyncio
async def test_publishing_validation_gate():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        cm_token = await get_token_for_user(client, "content@example.com", "ContentPass123!")
        headers = {"Authorization": f"Bearer {cm_token}"}

        # Create empty course
        res = await client.post(
            "/api/v1/admin/courses",
            json={"title": "Incomplete Course", "description": "Too short"},
            headers=headers,
        )
        assert res.status_code == 201
        course_id = res.json()["id"]

        # Attempt to publish incomplete course -> Expect 422
        pub_res = await client.post(
            f"/api/v1/admin/courses/{course_id}/publish",
            json={"reason": "Trying to publish early"},
            headers=headers,
        )
        assert pub_res.status_code == 422
        err_json = pub_res.json()
        assert err_json["error"]["code"] == "COURSE_VALIDATION_FAILED"


@pytest.mark.asyncio
async def test_assessment_crud_and_zero_answer_leakage():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        cm_token = await get_token_for_user(client, "content@example.com", "ContentPass123!")
        learner_token = await get_token_for_user(client, "learner@example.com", "LearnerPass123!")
        cm_headers = {"Authorization": f"Bearer {cm_token}"}
        learner_headers = {"Authorization": f"Bearer {learner_token}"}

        # 1. Create a course first
        c_res = await client.post(
            "/api/v1/admin/courses",
            json={
                "title": "Python Certification Track",
                "description": "Complete Python programming certification with hands on quizzes.",
            },
            headers=cm_headers,
        )
        assert c_res.status_code == 201
        course_id = c_res.json()["id"]

        # 2. Create Assessment
        ass_res = await client.post(
            f"/api/v1/admin/courses/{course_id}/assessments",
            json={
                "title": "Python Core Quiz",
                "description": "Test your mastery of Python data structures and functions.",
                "instructions": ["Read each question carefully", "No external IDE allowed"],
                "passingPercentage": 80,
                "timeLimitSeconds": 1800,
                "maxAttempts": 3,
                "requiredForCertificate": True,
                "status": "published",
            },
            headers=cm_headers,
        )
        assert ass_res.status_code == 201
        assessment = ass_res.json()
        ass_id = assessment["id"]
        assert assessment["passingPercentage"] == 80
        assert assessment["requiredForCertificate"] is True

        # 3. Add Single Choice Question with Grading Data
        q1_res = await client.post(
            f"/api/v1/admin/assessments/{ass_id}/questions",
            json={
                "type": "singleChoice",
                "prompt": "What is the return type of `type(42)` in Python 3?",
                "points": 2,
                "explanation": "In Python 3, integers are instances of the `int` class.",
                "options": [
                    {"id": "opt-1", "text": "<class 'int'>"},
                    {"id": "opt-2", "text": "<type 'int'>"},
                    {"id": "opt-3", "text": "number"},
                    {"id": "opt-4", "text": "Integer"},
                ],
                "gradingData": {"correctOptionId": "opt-1"},
            },
            headers=cm_headers,
        )
        assert q1_res.status_code == 201
        q1 = q1_res.json()
        assert q1["gradingData"]["correctOptionId"] == "opt-1"
        assert len(q1["options"]) == 4

        # 4. Add True/False Question with Grading Data
        q2_res = await client.post(
            f"/api/v1/admin/assessments/{ass_id}/questions",
            json={
                "type": "trueFalse",
                "prompt": "In Python, tuples are immutable data structures.",
                "points": 1,
                "explanation": "Tuples cannot be modified after creation.",
                "gradingData": {"correctValue": True},
            },
            headers=cm_headers,
        )
        assert q2_res.status_code == 201
        q2 = q2_res.json()
        assert q2["gradingData"]["correctValue"] is True

        # 5. Fetch Full Assessment via Admin CMS API (Includes Grading Data)
        admin_get_res = await client.get(
            f"/api/v1/admin/assessments/{ass_id}",
            headers=cm_headers,
        )
        assert admin_get_res.status_code == 200
        admin_data = admin_get_res.json()
        assert len(admin_data["questions"]) == 2
        assert "gradingData" in admin_data["questions"][0]
        assert admin_data["questions"][0]["gradingData"]["correctOptionId"] == "opt-1"

        # 6. Verify Zero Leakage to Student API
        student_res = await client.get(
            f"/api/v1/assessments/{ass_id}",
            headers=learner_headers,
        )
        assert student_res.status_code == 200
        student_data = student_res.json()
        # Student payload must NOT have gradingData or correct answers anywhere!
        for sq in student_data["questions"]:
            assert "gradingData" not in sq
            assert "correctOptionId" not in sq
            assert "correctValue" not in sq


@pytest.mark.asyncio
async def test_role_enforcement_on_content_endpoints():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        support_token = await get_token_for_user(client, "support@example.com", "SupportPass123!")
        learner_token = await get_token_for_user(client, "learner@example.com", "LearnerPass123!")

        # Support role cannot create or delete courses (403)
        res_sup_create = await client.post(
            "/api/v1/admin/courses",
            json={"title": "Hacked Course"},
            headers={"Authorization": f"Bearer {support_token}"},
        )
        assert res_sup_create.status_code == 403

        # Learner role cannot access admin course endpoints (403)
        res_lrn_create = await client.post(
            "/api/v1/admin/courses",
            json={"title": "Learner Course"},
            headers={"Authorization": f"Bearer {learner_token}"},
        )
        assert res_lrn_create.status_code == 403

        res_lrn_get = await client.get(
            "/api/v1/admin/courses/any-id",
            headers={"Authorization": f"Bearer {learner_token}"},
        )
        assert res_lrn_get.status_code == 403
