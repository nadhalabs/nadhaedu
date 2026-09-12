import base64
import binascii
import hashlib
import json
import math
from datetime import UTC, datetime, timedelta

from sqlalchemy import func, select, or_, and_
from sqlalchemy.ext.asyncio import AsyncSession

from .errors import APIError
from .models import (
    Assessment,
    AssessmentAttempt,
    AssessmentOption,
    AssessmentQuestion,
    AssessmentResponse,
    AttemptStatus,
    AuditEvent,
    AuthSession,
    Category,
    Certificate,
    CertificateStatus,
    Course,
    CourseCategory,
    CourseModule,
    CourseTag,
    Enrollment,
    Entitlement,
    EntitlementSource,
    EntitlementStatus,
    Lesson,
    LessonContentItem,
    LessonProgress,
    Lifecycle,
    PolicyKind,
    Purchase,
    PurchaseStatus,
    QuestionType,
    ResourceType,
    Subscription,
    SubscriptionStatus,
    Tag,
    User,
    UserRole,
)


def now() -> datetime:
    return datetime.now(UTC)


def iso(value: datetime | None):
    if value is None:
        return None
    normalized = value.replace(tzinfo=UTC) if value.tzinfo is None else value.astimezone(UTC)
    return normalized.isoformat().replace("+00:00", "Z")


def fingerprint(value: object) -> str:
    return hashlib.sha256(
        json.dumps(value, sort_keys=True, separators=(",", ":"), default=str).encode()
    ).hexdigest()


def cursor_encode(ts: datetime, id_: str) -> str:
    return base64.urlsafe_b64encode(f"{ts.isoformat()}|{id_}".encode()).decode().rstrip("=")


def cursor_decode(value: str) -> tuple[datetime, str]:
    try:
        raw = base64.urlsafe_b64decode(value + "=" * (-len(value) % 4)).decode()
        ts, id_ = raw.rsplit("|", 1)
        parsed = datetime.fromisoformat(ts)
        if parsed.tzinfo is None or not id_ or len(id_) > 120:
            raise ValueError("Cursor fields are invalid.")
        return parsed.astimezone(UTC), id_
    except (binascii.Error, UnicodeDecodeError, ValueError):
        raise APIError(400, "INVALID_CURSOR", "The cursor is invalid.")


def scalar_cursor_encode(value: float, id_: str) -> str:
    return base64.urlsafe_b64encode(f"{value}|{id_}".encode()).decode().rstrip("=")


def scalar_cursor_decode(value: str) -> tuple[float, str]:
    try:
        raw = base64.urlsafe_b64decode(value + "=" * (-len(value) % 4)).decode()
        scalar, id_ = raw.rsplit("|", 1)
        parsed = float(scalar)
        if not id_ or len(id_) > 120 or not math.isfinite(parsed):
            raise ValueError("Cursor fields are invalid.")
        return parsed, id_
    except (binascii.Error, UnicodeDecodeError, ValueError):
        raise APIError(400, "INVALID_CURSOR", "The cursor is invalid.")


SOURCE_REASON = {
    EntitlementSource.subscription: ("subscribed", "ACTIVE_SUBSCRIPTION"),
    EntitlementSource.purchase: ("purchased", "PURCHASED"),
    EntitlementSource.bundle: ("included", "BUNDLE_ACCESS"),
    EntitlementSource.promotion: ("included", "PROMOTIONAL_ACCESS"),
    EntitlementSource.trial: ("included", "TRIAL_ACCESS"),
    EntitlementSource.scholarship: ("included", "SCHOLARSHIP_ACCESS"),
    EntitlementSource.admin_grant: ("included", "ADMINISTRATIVE_GRANT"),
    EntitlementSource.free: ("free", "FREE_CONTENT"),
}
PRECEDENCE = {
    EntitlementSource.admin_grant: 8,
    EntitlementSource.scholarship: 7,
    EntitlementSource.purchase: 6,
    EntitlementSource.bundle: 5,
    EntitlementSource.subscription: 4,
    EntitlementSource.promotion: 3,
    EntitlementSource.trial: 2,
    EntitlementSource.free: 1,
}


async def resolve_access(
    db: AsyncSession, learner_id: str, resource_type: ResourceType, resource_id: str
) -> dict:
    policy, course_id = PolicyKind.unavailable, None
    if resource_type == ResourceType.course:
        obj = await db.get(Course, resource_id)
        if not obj or obj.status != Lifecycle.published:
            raise APIError(404, "NOT_FOUND", "Resource not found.")
        policy, course_id = obj.policy_kind, obj.id
    elif resource_type == ResourceType.module:
        obj = await db.get(CourseModule, resource_id)
        if not obj:
            raise APIError(404, "NOT_FOUND", "Resource not found.")
        course = await db.get(Course, obj.course_id)
        course_id = course.id
        policy = obj.policy_kind if obj.policy_kind != PolicyKind.inherit else course.policy_kind
    elif resource_type in (ResourceType.lesson, ResourceType.resource):
        lesson = await db.get(Lesson, resource_id)
        if not lesson:
            raise APIError(404, "NOT_FOUND", "Resource not found.")
        module = await db.get(CourseModule, lesson.module_id)
        course = await db.get(Course, module.course_id)
        course_id = course.id
        policy = (
            lesson.policy_kind
            if lesson.policy_kind != PolicyKind.inherit
            else (
                module.policy_kind
                if module.policy_kind != PolicyKind.inherit
                else course.policy_kind
            )
        )
        if lesson.is_preview:
            policy = PolicyKind.preview
    elif resource_type == ResourceType.assessment:
        obj = await db.get(Assessment, resource_id)
        if not obj or obj.status != Lifecycle.published:
            raise APIError(404, "NOT_FOUND", "Resource not found.")
        course = await db.get(Course, obj.course_id)
        course_id = course.id
        policy = course.policy_kind
    else:
        policy = PolicyKind.premium
    evaluated = now()
    if policy == PolicyKind.unavailable:
        return {
            "allowed": False,
            "accessLevel": "unavailable",
            "reason": "CONTENT_UNAVAILABLE",
            "evaluatedAt": iso(evaluated),
        }
    if policy in (PolicyKind.free, PolicyKind.preview):
        return {
            "allowed": True,
            "accessLevel": "preview" if policy == PolicyKind.preview else "free",
            "reason": "FREE_PREVIEW" if policy == PolicyKind.preview else "FREE_CONTENT",
            "evaluatedAt": iso(evaluated),
        }
    grants = (
        await db.scalars(
            select(Entitlement).where(
                Entitlement.learner_id == learner_id,
                Entitlement.status.in_([EntitlementStatus.active, EntitlementStatus.grace_period]),
                Entitlement.starts_at <= evaluated,
                (Entitlement.expires_at.is_(None) | (Entitlement.expires_at > evaluated)),
            )
        )
    ).all()
    covers = [
        g
        for g in grants
        if (g.resource_id is None or g.resource_id in (resource_id, course_id))
        and (g.resource_type is None or g.resource_type in (resource_type, ResourceType.course))
    ]
    if covers:
        grant = max(covers, key=lambda x: PRECEDENCE[x.source])
        level, reason = SOURCE_REASON[grant.source]
        return {
            "allowed": True,
            "accessLevel": level,
            "reason": reason,
            "entitlementSource": grant.source.value,
            "expiresAt": iso(grant.expires_at),
            "evaluatedAt": iso(evaluated),
        }
    expired_grant_id = await db.scalar(
        select(Entitlement.id)
        .where(
            Entitlement.learner_id == learner_id,
            Entitlement.expires_at.is_not(None),
            Entitlement.expires_at <= evaluated,
            (
                Entitlement.resource_id.is_(None)
                | Entitlement.resource_id.in_([resource_id, course_id])
            ),
        )
        .limit(1)
    )
    expired = expired_grant_id is not None
    return {
        "allowed": False,
        "accessLevel": "expired" if expired else "locked",
        "reason": "SUBSCRIPTION_EXPIRED" if expired else "REQUIRES_PREMIUM",
        "evaluatedAt": iso(evaluated),
        "availableUpgrade": "premium",
    }


async def assessment_payload(db: AsyncSession, assessment: Assessment) -> dict:
    questions = (
        await db.scalars(
            select(AssessmentQuestion)
            .where(AssessmentQuestion.assessment_id == assessment.id)
            .order_by(AssessmentQuestion.position)
        )
    ).all()
    options = (
        (
            await db.scalars(
                select(AssessmentOption)
                .where(AssessmentOption.question_id.in_([question.id for question in questions]))
                .order_by(AssessmentOption.question_id, AssessmentOption.position)
            )
        ).all()
        if questions
        else []
    )
    options_by_question: dict[str, list[AssessmentOption]] = {}
    for option in options:
        options_by_question.setdefault(option.question_id, []).append(option)
    result = []
    for q in questions:
        question_options = options_by_question.get(q.id, [])
        item = {"id": q.id, "type": q.type.value, "prompt": q.prompt, "points": q.points}
        if question_options:
            item["options"] = [
                {"id": o.id, "text": o.text, "hint": o.hint} for o in question_options
            ]
        item.update(
            {
                k: v
                for k, v in q.settings.items()
                if k in {"minSelections", "maxSelections", "placeholder", "minWords", "maxWords"}
            }
        )
        result.append(item)
    return {
        "summary": {
            "id": assessment.id,
            "courseId": assessment.course_id,
            "title": assessment.title,
            "description": assessment.description,
            "questionCount": len(questions),
            "passingScorePercentage": assessment.passing_percentage,
            "timeLimitSeconds": assessment.time_limit_seconds,
            "maxAttempts": assessment.max_attempts,
            "protectionPolicy": (
                assessment.protection_policy.value
                if hasattr(assessment, "protection_policy") and assessment.protection_policy
                else "blockCaptureWhereSupported"
            ),
        },
        "questions": result,
        "instructions": assessment.instructions,
        "updatedAt": iso(assessment.updated_at),
    }


async def start_attempt(
    db: AsyncSession, learner_id: str, assessment: Assessment
) -> AssessmentAttempt:
    decision = await resolve_access(db, learner_id, ResourceType.assessment, assessment.id)
    if not decision["allowed"]:
        raise APIError(403, "ACCESS_DENIED", "Assessment access is not permitted.")
    # PostgreSQL serializes this namespace via a transaction advisory lock; the unique constraint is the final guard.
    if db.bind and db.bind.dialect.name == "postgresql":
        await db.execute(
            select(
                func.pg_advisory_xact_lock(
                    func.hashtextextended(f"{learner_id}:{assessment.id}", 0)
                )
            )
        )
    total = (
        await db.scalar(
            select(func.count())
            .select_from(AssessmentAttempt)
            .where(
                AssessmentAttempt.learner_id == learner_id,
                AssessmentAttempt.assessment_id == assessment.id,
            )
        )
        or 0
    )
    if total >= assessment.max_attempts:
        raise APIError(409, "ATTEMPT_LIMIT_REACHED", "No assessment attempts remain.")
    started = now()
    attempt = AssessmentAttempt(
        assessment_id=assessment.id,
        learner_id=learner_id,
        attempt_number=total + 1,
        status=AttemptStatus.in_progress,
        started_at=started,
        expires_at=started + timedelta(seconds=assessment.time_limit_seconds)
        if assessment.time_limit_seconds
        else None,
    )
    db.add(attempt)
    await db.commit()
    await db.refresh(attempt)
    return attempt


async def grade_submission(
    db: AsyncSession,
    learner_id: str,
    assessment: Assessment,
    attempt: AssessmentAttempt,
    answers: list[dict],
) -> dict:
    current = now()
    if attempt.learner_id != learner_id or attempt.assessment_id != assessment.id:
        raise APIError(404, "NOT_FOUND", "Attempt not found.")
    if attempt.status != AttemptStatus.in_progress:
        raise APIError(409, "ATTEMPT_FINALIZED", "Attempt is already finalized.")
    if attempt.expires_at and current > attempt.expires_at:
        attempt.status = AttemptStatus.expired
        await db.commit()
        raise APIError(410, "ATTEMPT_EXPIRED", "Attempt deadline has passed.")
    questions = (
        await db.scalars(
            select(AssessmentQuestion)
            .where(AssessmentQuestion.assessment_id == assessment.id)
            .order_by(AssessmentQuestion.position, AssessmentQuestion.id)
        )
    ).all()
    by_id = {q.id: q for q in questions}
    answer_by = {a["questionId"]: a for a in answers}
    if len(answer_by) != len(answers) or any(i not in by_id for i in answer_by):
        raise APIError(422, "INVALID_ANSWER", "Answers contain duplicate or foreign question IDs.")
    earned = 0
    maximum = sum(q.points for q in questions)
    results = []
    for q in questions:
        a = answer_by.get(q.id, {"questionId": q.id, "type": q.type.value})
        correct = False
        if a.get("type") != q.type.value:
            raise APIError(422, "INVALID_ANSWER", "Answer type does not match the question.")
        key = q.grading_data
        if q.type == QuestionType.single_choice:
            correct = a.get("selectedOptionId") == key.get("correctOptionId")
        elif q.type == QuestionType.multiple_choice:
            correct = set(a.get("selectedOptionIds") or []) == set(
                key.get("correctOptionIds") or []
            )
        elif q.type == QuestionType.true_false:
            correct = a.get("selectedValue") == key.get("correctValue")
        else:
            correct = False
        points = q.points if correct else 0
        earned += points
        db.add(
            AssessmentResponse(
                attempt_id=attempt.id,
                question_id=q.id,
                answer_json=a,
                earned_points=points,
                correct=correct,
            )
        )
        results.append(
            {
                "questionId": q.id,
                "isCorrect": correct,
                "earnedPoints": points,
                "maxPoints": q.points,
                "explanation": q.explanation,
                "feedback": None,
            }
        )
    pct = 0 if maximum == 0 else earned * 100 / maximum
    passed = pct >= assessment.passing_percentage
    payload = {
        "assessmentId": assessment.id,
        "attemptId": attempt.id,
        "earnedScore": earned,
        "maxScore": maximum,
        "percentage": pct,
        "isPassed": passed,
        "passingPercentage": assessment.passing_percentage,
        "durationSeconds": max(0, int((current - attempt.started_at).total_seconds())),
        "submittedAt": iso(current),
        "questionResults": results,
        "feedbackSummary": "Assessment passed." if passed else "Review the material and try again.",
    }
    attempt.status = AttemptStatus.submitted
    attempt.submitted_at = current
    attempt.score = earned
    attempt.max_score = maximum
    attempt.percentage = pct
    attempt.passed = passed
    attempt.result_json = payload
    if passed:
        # Quiz lessons can only be completed by server grading. Share the same
        # course lock as progress synchronization before upserting the invariant.
        if db.bind and db.bind.dialect.name == "postgresql":
            await db.execute(
                select(
                    func.pg_advisory_xact_lock(
                        func.hashtextextended(f"progress:{learner_id}:{assessment.course_id}", 0)
                    )
                )
            )
        linked_lessons = (
            await db.scalars(
                select(Lesson)
                .join(CourseModule)
                .where(
                    CourseModule.course_id == assessment.course_id,
                    or_(and_(Lesson.content_type == "quiz", Lesson.content_ref == assessment.id),
                        Lesson.id.in_(select(LessonContentItem.lesson_id).where(LessonContentItem.assessment_id == assessment.id, LessonContentItem.status == Lifecycle.published))),
                )
            )
        ).all()
        for lesson in linked_lessons:
            from .academic import required_quizzes_passed
            await db.flush()
            if not await required_quizzes_passed(db, learner_id, lesson.id):
                continue
            # Mixed lessons require an explicit completion after studying other items.
            if await db.scalar(select(LessonContentItem.id).where(LessonContentItem.lesson_id == lesson.id, LessonContentItem.status == Lifecycle.published, LessonContentItem.content_type != "quiz").limit(1)):
                continue
            progress = await db.scalar(
                select(LessonProgress)
                .where(
                    LessonProgress.learner_id == learner_id,
                    LessonProgress.lesson_id == lesson.id,
                )
                .with_for_update()
            )
            if progress is None:
                progress = LessonProgress(learner_id=learner_id, lesson_id=lesson.id, duration_seconds=0, position_seconds=0, completed=False, revision=0)
                db.add(progress)
            progress.completed = True
            progress.duration_seconds = lesson.duration_seconds
            progress.position_seconds = lesson.duration_seconds
            progress.revision += 1
    return payload


async def certificate_eligibility(db: AsyncSession, learner_id: str, course: Course) -> dict:
    existing = await db.scalar(
        select(Certificate.id).where(
            Certificate.learner_id == learner_id, Certificate.course_id == course.id
        )
    )
    enrollment = await db.scalar(
        select(Enrollment).where(
            Enrollment.learner_id == learner_id,
            Enrollment.course_id == course.id,
            Enrollment.status == "active",
        )
    )
    missing = []
    if not enrollment:
        missing.append("ACTIVE_ENROLLMENT")
    lesson_ids = (
        await db.scalars(
            select(Lesson.id)
            .join(CourseModule, Lesson.module_id == CourseModule.id)
            .where(CourseModule.course_id == course.id)
        )
    ).all()
    completed = (
        await db.scalar(
            select(func.count())
            .select_from(LessonProgress)
            .where(
                LessonProgress.learner_id == learner_id,
                LessonProgress.lesson_id.in_(lesson_ids),
                LessonProgress.completed.is_(True),
            )
        )
        if lesson_ids
        else 0
    )
    fraction = 1.0 if not lesson_ids else completed / len(lesson_ids)
    if fraction < 1:
        missing.append("COURSE_COMPLETION")
    required = (
        await db.scalars(
            select(Assessment).where(
                Assessment.course_id == course.id, Assessment.required_for_certificate.is_(True)
            )
        )
    ).all()
    required_ids = [assessment.id for assessment in required]
    passed = (
        await db.scalar(
            select(func.count(func.distinct(AssessmentAttempt.assessment_id))).where(
                AssessmentAttempt.assessment_id.in_(required_ids),
                AssessmentAttempt.learner_id == learner_id,
                AssessmentAttempt.passed.is_(True),
            )
        )
        if required_ids
        else 0
    ) or 0
    if passed < len(required):
        missing.append("REQUIRED_ASSESSMENTS")
    access = await resolve_access(db, learner_id, ResourceType.course, course.id)
    if not access["allowed"]:
        missing.append("CERTIFICATE_ENTITLEMENT")
    status = (
        "alreadyIssued"
        if existing
        else (
            "eligible"
            if not missing
            else (
                "ineligibleCourseIncomplete"
                if "COURSE_COMPLETION" in missing or "ACTIVE_ENROLLMENT" in missing
                else (
                    "ineligibleAssessmentFailed"
                    if "REQUIRED_ASSESSMENTS" in missing
                    else "ineligibleEntitlementRequired"
                )
            )
        )
    )
    return {
        "courseId": course.id,
        "status": status,
        "requiredPolicy": {"type": course.policy_kind.value, "requiredTier": course.required_tier},
        "courseCompletionFraction": fraction,
        "assessmentsPassed": passed,
        "assessmentsRequired": len(required),
        "missingRequirements": missing,
    }


def certificate_json(
    cert: Certificate, base_url: str, public: bool = False, revocation_reason: str | None = None
) -> dict:
    return {
        "id": cert.id,
        "credentialId": cert.credential_id,
        "courseId": cert.course_id,
        "courseTitle": cert.course_title,
        "learnerId": "" if public else cert.learner_id,
        "learnerName": cert.learner_name,
        "issueDate": iso(cert.issued_at),
        "expiryDate": iso(cert.expires_at),
        "status": cert.status.value,
        "verificationUrl": f"{base_url}/verify/{cert.credential_id}",
        "issuerName": "Nadha Edu",
        "grade": cert.grade,
        "revocationReason": revocation_reason,
        "metadata": {} if public else cert.metadata_json,
    }


def sanitize_audit_metadata(data: dict | None) -> dict:
    if not data:
        return {}
    clean = {}
    for k, v in data.items():
        if any(
            s in k.lower()
            for s in ["password", "token", "secret", "auth", "receipt", "credential", "payload"]
        ):
            continue
        if isinstance(v, dict):
            clean[k] = sanitize_audit_metadata(v)
        elif isinstance(v, (str, int, float, bool, list)) or v is None:
            clean[k] = v
        else:
            clean[k] = str(v)
    return clean


def log_audit_event(
    db: AsyncSession,
    *,
    actor_id: str | None,
    action: str,
    target_entity: str,
    target_id: str,
    result: str = "success",
    metadata: dict | None = None,
    reason: str | None = None,
    correlation_id: str | None = None,
) -> AuditEvent:
    clean_meta = sanitize_audit_metadata(metadata)
    event_data = {
        "result": result,
        "metadata": clean_meta,
    }
    if reason:
        event_data["reason"] = reason
    event = AuditEvent(
        actor_id=actor_id,
        event_type=action,
        subject_type=target_entity,
        subject_id=target_id,
        occurred_at=now(),
        correlation_id=correlation_id,
        data=event_data,
    )
    db.add(event)
    return event


async def get_cms_dashboard_data(db: AsyncSession) -> dict:
    total_users = (await db.scalar(select(func.count(User.id)))) or 0
    total_learners = (
        await db.scalar(select(func.count(User.id)).where(User.role == UserRole.learner))
    ) or 0

    thirty_days_ago = now() - timedelta(days=30)
    active_learners = (
        await db.scalar(
            select(func.count(func.distinct(AuthSession.user_id))).where(
                AuthSession.last_active_at >= thirty_days_ago,
                AuthSession.revoked_at.is_(None),
            )
        )
    ) or 0

    total_courses = (await db.scalar(select(func.count(Course.id)))) or 0
    published_courses = (
        await db.scalar(select(func.count(Course.id)).where(Course.status == Lifecycle.published))
    ) or 0
    draft_courses = (
        await db.scalar(select(func.count(Course.id)).where(Course.status == Lifecycle.draft))
    ) or 0
    archived_courses = (
        await db.scalar(select(func.count(Course.id)).where(Course.status == Lifecycle.archived))
    ) or 0

    total_enrollments = (await db.scalar(select(func.count(Enrollment.id)))) or 0

    total_purchases = (
        await db.scalar(
            select(func.count(Purchase.id)).where(Purchase.status == PurchaseStatus.completed)
        )
    ) or 0
    active_subscriptions = (
        await db.scalar(
            select(func.count(Subscription.id)).where(
                Subscription.status.in_([SubscriptionStatus.active, SubscriptionStatus.trialing])
            )
        )
    ) or 0

    total_certificates = (
        await db.scalar(
            select(func.count(Certificate.id)).where(Certificate.status == CertificateStatus.issued)
        )
    ) or 0
    recent_completions = (
        await db.scalar(
            select(func.count(LessonProgress.id)).where(
                LessonProgress.completed.is_(True), LessonProgress.updated_at >= thirty_days_ago
            )
        )
    ) or 0

    recent_purchases_q = (
        select(Purchase, User.email)
        .outerjoin(User, Purchase.learner_id == User.id)
        .order_by(Purchase.purchased_at.desc())
        .limit(10)
    )
    purchases_rows = (await db.execute(recent_purchases_q)).all()
    recent_purchases = [
        {
            "id": p.id,
            "orderId": p.order_id,
            "learnerId": p.learner_id,
            "learnerEmail": u_email,
            "productId": p.product_id,
            "productType": p.product_type.value,
            "amountCents": p.amount_cents,
            "currencyCode": p.currency_code or "USD",
            "status": p.status.value,
            "purchasedAt": iso(p.purchased_at),
        }
        for p, u_email in purchases_rows
    ]

    recent_events_q = (
        select(AuditEvent, User.email, User.display_name)
        .outerjoin(User, AuditEvent.actor_id == User.id)
        .order_by(AuditEvent.occurred_at.desc())
        .limit(15)
    )
    events_rows = (await db.execute(recent_events_q)).all()
    recent_activity = [
        {
            "id": e.id,
            "actorId": e.actor_id,
            "actorEmail": u_email,
            "actorName": u_name or ("System" if not e.actor_id else None),
            "action": e.event_type,
            "targetEntity": e.subject_type,
            "targetId": e.subject_id,
            "timestamp": iso(e.occurred_at),
            "result": (e.data or {}).get("result", "success"),
            "reason": (e.data or {}).get("reason"),
            "metadata": (e.data or {}).get("metadata", {}),
        }
        for e, u_email, u_name in events_rows
    ]

    system_readiness = {
        "database": "connected",
        "cache": "connected",
        "migrationRevision": "0006_r3_query_indexes",
        "isReady": True,
        "warnings": [
            {
                "code": "PROVIDER_MOCK_MODE",
                "message": "Apple, Google and Stripe live billing are running in fail-closed / mock verification mode.",
            }
        ],
    }

    return {
        "metrics": {
            "totalUsers": total_users,
            "totalLearners": total_learners,
            "activeLearners": active_learners,
            "totalCourses": total_courses,
            "publishedCourses": published_courses,
            "draftCourses": draft_courses,
            "archivedCourses": archived_courses,
            "totalEnrollments": total_enrollments,
            "totalPurchases": total_purchases,
            "activeSubscriptions": active_subscriptions,
            "totalCertificatesIssued": total_certificates,
            "recentCompletions": recent_completions,
        },
        "recentPurchases": recent_purchases,
        "recentActivity": recent_activity,
        "systemReadiness": system_readiness,
    }


# --- CMS Phase 2: Content & Curriculum Management Services ---


async def validate_course_for_publishing(db: AsyncSession, course_id: str) -> dict:
    course = await db.get(Course, course_id)
    if not course:
        raise APIError(404, "NOT_FOUND", "Course not found.")

    errors = []
    warnings = []

    # 1. Course title & description
    if not course.title or len(course.title.strip()) < 3:
        errors.append(
            {
                "code": "COURSE_TITLE_TOO_SHORT",
                "message": "Course title must be at least 3 characters.",
                "severity": "error",
                "field": "title",
            }
        )
    if not course.description or len(course.description.strip()) < 10:
        errors.append(
            {
                "code": "COURSE_DESCRIPTION_TOO_SHORT",
                "message": "Course description must be at least 10 characters.",
                "severity": "error",
                "field": "description",
            }
        )

    # 2. Categories
    category_count = (
        await db.scalar(
            select(func.count(CourseCategory.category_id)).where(
                CourseCategory.course_id == course.id
            )
        )
    ) or 0
    if category_count == 0:
        errors.append(
            {
                "code": "NO_CATEGORIES_ASSIGNED",
                "message": "At least one subject/category must be assigned to the course.",
                "severity": "error",
                "field": "categoryIds",
            }
        )

    # 3. Modules & Lessons
    modules = (
        await db.scalars(
            select(CourseModule)
            .where(CourseModule.course_id == course.id)
            .order_by(CourseModule.position)
        )
    ).all()

    if not modules:
        errors.append(
            {
                "code": "NO_SECTIONS_CREATED",
                "message": "The course must contain at least one curriculum section/module.",
                "severity": "error",
                "field": "modules",
            }
        )
    else:
        module_ids = [m.id for m in modules]
        lessons = (
            await db.scalars(
                select(Lesson)
                .where(Lesson.module_id.in_(module_ids))
                .order_by(Lesson.module_id, Lesson.position)
            )
        ).all()
        lessons_by_module: dict[str, list[Lesson]] = {}
        for l in lessons:
            lessons_by_module.setdefault(l.module_id, []).append(l)

        for m in modules:
            m_lessons = lessons_by_module.get(m.id, [])
            if not m_lessons:
                errors.append(
                    {
                        "code": "EMPTY_SECTION",
                        "message": f"Section '{m.title}' has no lessons. Every section must contain at least one lesson.",
                        "severity": "error",
                        "field": f"modules.{m.id}",
                    }
                )
            else:
                for l in m_lessons:
                    has_items = await db.scalar(select(LessonContentItem.id).where(LessonContentItem.lesson_id == l.id).limit(1))
                    if has_items or l.content_ref.startswith("lesson-shell:"):
                        published_item = await db.scalar(select(LessonContentItem.id).where(LessonContentItem.lesson_id == l.id, LessonContentItem.status == Lifecycle.published).limit(1))
                        if not published_item:
                            errors.append({"code": "LESSON_CONTENT_UNPUBLISHED", "message": f"Lesson '{l.title}' needs published content.", "severity": "error", "field": f"lessons.{l.id}.contentItems"})
                    if not l.title or len(l.title.strip()) < 1:
                        errors.append(
                            {
                                "code": "LESSON_TITLE_MISSING",
                                "message": f"Lesson in '{m.title}' is missing a title.",
                                "severity": "error",
                                "field": f"lessons.{l.id}.title",
                            }
                        )
                    if not l.content_ref or len(l.content_ref.strip()) < 1:
                        errors.append(
                            {
                                "code": "LESSON_CONTENT_REF_MISSING",
                                "message": f"Lesson '{l.title}' is missing a content reference / video key.",
                                "severity": "error",
                                "field": f"lessons.{l.id}.contentRef",
                            }
                        )
                    if l.duration_seconds <= 0:
                        errors.append(
                            {
                                "code": "LESSON_ZERO_DURATION",
                                "message": f"Lesson '{l.title}' must have an estimated duration greater than 0 seconds.",
                                "severity": "error",
                                "field": f"lessons.{l.id}.durationSeconds",
                            }
                        )

    # 4. Assessments check
    assessments = (
        await db.scalars(select(Assessment).where(Assessment.course_id == course.id))
    ).all()
    if assessments:
        assessment_ids = [a.id for a in assessments]
        questions_count = dict(
            (
                await db.execute(
                    select(AssessmentQuestion.assessment_id, func.count(AssessmentQuestion.id))
                    .where(AssessmentQuestion.assessment_id.in_(assessment_ids))
                    .group_by(AssessmentQuestion.assessment_id)
                )
            ).all()
        )
        for a in assessments:
            q_count = questions_count.get(a.id, 0)
            if a.required_for_certificate and q_count == 0:
                errors.append(
                    {
                        "code": "ASSESSMENT_EMPTY_QUESTIONS",
                        "message": f"Required certificate assessment '{a.title}' contains no questions.",
                        "severity": "error",
                        "field": f"assessments.{a.id}",
                    }
                )
            if a.passing_percentage <= 0 or a.passing_percentage > 100:
                errors.append(
                    {
                        "code": "ASSESSMENT_INVALID_PASSING_PERCENTAGE",
                        "message": f"Assessment '{a.title}' must have a passing score percentage between 1 and 100.",
                        "severity": "error",
                        "field": f"assessments.{a.id}.passingPercentage",
                    }
                )

    # 5. Warnings
    if not course.learning_outcomes or len(course.learning_outcomes) == 0:
        warnings.append(
            {
                "code": "NO_LEARNING_OUTCOMES",
                "message": "Adding learning outcomes helps prospective learners understand course objectives.",
                "severity": "warning",
                "field": "learningOutcomes",
            }
        )
    if not course.prerequisites or len(course.prerequisites) == 0:
        warnings.append(
            {
                "code": "NO_PREREQUISITES",
                "message": "Specifying prerequisites helps learners choose appropriately leveled content.",
                "severity": "warning",
                "field": "prerequisites",
            }
        )

    is_valid = len(errors) == 0
    return {
        "isValid": is_valid,
        "canPublish": is_valid,
        "errors": errors,
        "warnings": warnings,
    }


async def get_cms_course_detail(db: AsyncSession, course_id: str) -> dict:
    from .academic import classification_json
    course = await db.get(Course, course_id)
    if not course:
        raise APIError(404, "NOT_FOUND", "Course not found.")

    # Categories
    categories = (
        await db.scalars(
            select(Category)
            .join(CourseCategory, CourseCategory.category_id == Category.id)
            .where(CourseCategory.course_id == course.id)
            .order_by(Category.name)
        )
    ).all()

    # Tags
    tags = (
        await db.scalars(
            select(Tag.name)
            .join(CourseTag, CourseTag.tag_id == Tag.id)
            .where(CourseTag.course_id == course.id)
            .order_by(Tag.name)
        )
    ).all()

    # Modules and Lessons
    modules = (
        await db.scalars(
            select(CourseModule)
            .where(CourseModule.course_id == course.id)
            .order_by(CourseModule.position)
        )
    ).all()

    module_ids = [m.id for m in modules]
    lessons_by_module: dict[str, list[Lesson]] = {}
    if module_ids:
        lessons = (
            await db.scalars(
                select(Lesson)
                .where(Lesson.module_id.in_(module_ids))
                .order_by(Lesson.module_id, Lesson.position)
            )
        ).all()
        for l in lessons:
            lessons_by_module.setdefault(l.module_id, []).append(l)

    modules_out = [
        {
            "id": m.id,
            "courseId": m.course_id,
            "title": m.title,
            "position": m.position,
            "policyKind": m.policy_kind.value
            if hasattr(m.policy_kind, "value")
            else str(m.policy_kind),
            "lessons": [
                {
                    "id": l.id,
                    "moduleId": l.module_id,
                    "title": l.title,
                    "position": l.position,
                    "durationSeconds": l.duration_seconds,
                    "contentType": l.content_type,
                    "contentRef": l.content_ref,
                    "isPreview": l.is_preview,
                    "isDownloadable": l.is_downloadable,
                    "policyKind": l.policy_kind.value
                    if hasattr(l.policy_kind, "value")
                    else str(l.policy_kind),
                    "protectionPolicy": (
                        l.protection_policy.value
                        if hasattr(l, "protection_policy") and l.protection_policy
                        else "blockCaptureWhereSupported"
                    ),
                    "createdAt": iso(l.created_at),
                    "updatedAt": iso(l.updated_at),
                }
                for l in lessons_by_module.get(m.id, [])
            ],
            "createdAt": iso(m.created_at),
            "updatedAt": iso(m.updated_at),
        }
        for m in modules
    ]

    # Assessments
    assessments = (
        await db.scalars(
            select(Assessment)
            .where(Assessment.course_id == course.id)
            .order_by(Assessment.created_at)
        )
    ).all()

    assessment_ids = [a.id for a in assessments]
    questions_count = {}
    if assessment_ids:
        questions_count = dict(
            (
                await db.execute(
                    select(AssessmentQuestion.assessment_id, func.count(AssessmentQuestion.id))
                    .where(AssessmentQuestion.assessment_id.in_(assessment_ids))
                    .group_by(AssessmentQuestion.assessment_id)
                )
            ).all()
        )

    assessments_out = [
        {
            "id": a.id,
            "courseId": a.course_id,
            "title": a.title,
            "description": a.description,
            "passingPercentage": a.passing_percentage,
            "timeLimitSeconds": a.time_limit_seconds,
            "maxAttempts": a.max_attempts,
            "requiredForCertificate": a.required_for_certificate,
            "protectionPolicy": (
                a.protection_policy.value
                if hasattr(a, "protection_policy") and a.protection_policy
                else "blockCaptureWhereSupported"
            ),
            "status": a.status.value if hasattr(a.status, "value") else str(a.status),
            "questionCount": questions_count.get(a.id, 0),
            "createdAt": iso(a.created_at),
            "updatedAt": iso(a.updated_at),
        }
        for a in assessments
    ]

    validation = await validate_course_for_publishing(db, course.id)

    # Recalculate total course duration
    total_duration = sum(
        l.duration_seconds for module_lessons in lessons_by_module.values() for l in module_lessons
    )

    return {
        "id": course.id,
        **classification_json(course),
        "title": course.title,
        "subtitle": course.subtitle,
        "coverReference": course.cover_reference,
        "description": course.description,
        "level": course.level,
        "languageCode": course.language_code,
        "policyKind": course.policy_kind.value
        if hasattr(course.policy_kind, "value")
        else str(course.policy_kind),
        "protectionPolicy": (
            course.protection_policy.value
            if hasattr(course, "protection_policy") and course.protection_policy
            else "blockCaptureWhereSupported"
        ),
        "requiredTier": course.required_tier,
        "requiredBundleId": course.required_bundle_id,
        "status": course.status.value if hasattr(course.status, "value") else str(course.status),
        "publishedAt": iso(course.published_at),
        "rating": float(course.rating or 0),
        "ratingCount": course.rating_count,
        "durationSeconds": total_duration if total_duration > 0 else course.duration_seconds,
        "learningOutcomes": course.learning_outcomes or [],
        "prerequisites": course.prerequisites or [],
        "categories": [{"id": c.id, "name": c.name, "iconName": c.icon_name} for c in categories],
        "tags": list(tags),
        "modules": modules_out,
        "assessments": assessments_out,
        "validation": validation,
        "createdAt": iso(course.created_at),
        "updatedAt": iso(course.updated_at),
    }


async def get_cms_assessment_detail(db: AsyncSession, assessment_id: str) -> dict:
    a = await db.get(Assessment, assessment_id)
    if not a:
        raise APIError(404, "NOT_FOUND", "Assessment not found.")

    questions = (
        await db.scalars(
            select(AssessmentQuestion)
            .where(AssessmentQuestion.assessment_id == a.id)
            .order_by(AssessmentQuestion.position)
        )
    ).all()

    question_ids = [q.id for q in questions]
    options_by_question: dict[str, list[AssessmentOption]] = {}
    if question_ids:
        options = (
            await db.scalars(
                select(AssessmentOption)
                .where(AssessmentOption.question_id.in_(question_ids))
                .order_by(AssessmentOption.question_id, AssessmentOption.position)
            )
        ).all()
        for opt in options:
            options_by_question.setdefault(opt.question_id, []).append(opt)

    questions_out = [
        {
            "id": q.id,
            "assessmentId": q.assessment_id,
            "type": q.type.value if hasattr(q.type, "value") else str(q.type),
            "prompt": q.prompt,
            "points": q.points,
            "position": q.position,
            "explanation": q.explanation,
            "settings": q.settings or {},
            "options": [
                {
                    "id": o.id,
                    "text": o.text,
                    "hint": o.hint,
                    "position": o.position,
                }
                for o in options_by_question.get(q.id, [])
            ],
            "gradingData": q.grading_data or {},
            "createdAt": iso(q.created_at),
            "updatedAt": iso(q.updated_at),
        }
        for q in questions
    ]

    return {
        "id": a.id,
        "courseId": a.course_id,
        "title": a.title,
        "description": a.description,
        "instructions": a.instructions or [],
        "passingPercentage": a.passing_percentage,
        "timeLimitSeconds": a.time_limit_seconds,
        "maxAttempts": a.max_attempts,
        "requiredForCertificate": a.required_for_certificate,
        "protectionPolicy": (
            a.protection_policy.value
            if hasattr(a, "protection_policy") and a.protection_policy
            else "blockCaptureWhereSupported"
        ),
        "status": a.status.value if hasattr(a.status, "value") else str(a.status),
        "questions": questions_out,
        "createdAt": iso(a.created_at),
        "updatedAt": iso(a.updated_at),
    }
