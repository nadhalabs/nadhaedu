from datetime import UTC, datetime

from fastapi import APIRouter, Query, Request
from pydantic import Field
from sqlalchemy import func, or_, select, update

from .config import get_settings
from .dependencies import DB, AdminPrincipal, SuperAdminPrincipal, SupportPrincipal
from .errors import APIError
from .models import (
    AssessmentAttempt,
    AuthSession,
    Certificate,
    Course,
    CourseModule,
    Enrollment,
    Entitlement,
    EntitlementSource,
    EntitlementStatus,
    Lesson,
    LessonProgress,
    Notification,
    NotificationPriority,
    NotificationType,
    PaymentProvider,
    PaymentTransaction,
    PlatformSetting,
    Purchase,
    ResourceType,
    Subscription,
    SubscriptionPlan,
    User,
    UserRole,
)
from .readiness import schema_status
from .schemas import CamelModel
from .services import iso, log_audit_event, now

router = APIRouter(prefix="/admin")

SETTING_DEFINITIONS = {
    "registrations_enabled": (True, "Allow new learner registrations."),
    "purchases_enabled": (True, "Allow new purchase attempts."),
    "course_publishing_enabled": (True, "Allow course publishing."),
    "notification_sending_enabled": (True, "Allow notification dispatch."),
    "maintenance_mode": (False, "Put protected student operations into maintenance mode."),
    "emergency_commerce_kill_switch": (False, "Immediately block new commerce operations."),
    "content_visibility_enabled": (True, "Expose published content to learners."),
}


class ReasonBody(CamelModel):
    reason: str = Field(min_length=8, max_length=500)


class EntitlementGrantBody(ReasonBody):
    resource_type: ResourceType = ResourceType.course
    resource_id: str = Field(min_length=1, max_length=64)
    expires_at: datetime | None = None


class EntitlementChangeBody(ReasonBody):
    expected_version: int = Field(ge=1)
    expires_at: datetime | None = None


class NotificationCreateBody(CamelModel):
    user_id: str
    title: str = Field(min_length=1, max_length=200)
    body: str = Field(min_length=1, max_length=4000)
    notification_type: NotificationType = NotificationType.system_announcement
    priority: NotificationPriority = NotificationPriority.normal


class RoleChangeBody(ReasonBody):
    role: UserRole


class SettingChangeBody(ReasonBody):
    value: bool
    expected_version: int = Field(ge=0)


def _enum(value):
    return value.value if hasattr(value, "value") else value


def _entitlement_json(item: Entitlement):
    metadata = item.metadata_json or {}
    return {
        "id": item.id,
        "learnerId": item.learner_id,
        "source": _enum(item.source),
        "status": _enum(item.status),
        "resourceType": _enum(item.resource_type),
        "resourceId": item.resource_id,
        "startsAt": iso(item.starts_at),
        "expiresAt": iso(item.expires_at),
        "revokedAt": iso(item.revoked_at),
        "version": item.version,
        "authority": "internalOverride"
        if item.source == EntitlementSource.admin_grant
        else "internalState",
        "reason": metadata.get("reason"),
        "updatedBy": metadata.get("updatedBy"),
    }


@router.get("/learners")
async def learners(
    user: SupportPrincipal,
    db: DB,
    search: str = "",
    active: bool | None = None,
    course_id: str | None = Query(None, alias="courseId"),
    cursor: str | None = None,
    limit: int = Query(25, ge=1, le=100),
):
    q = select(User).where(User.role == UserRole.learner)
    if search:
        term = f"%{search.strip()}%"
        q = q.where(
            or_(User.id == search.strip(), User.email.ilike(term), User.display_name.ilike(term))
        )
    if active is not None:
        q = q.where(User.is_active == active)
    if course_id:
        q = q.join(Enrollment, Enrollment.learner_id == User.id).where(
            Enrollment.course_id == course_id
        )
    if cursor:
        q = q.where(User.id > cursor)
    rows = (await db.scalars(q.order_by(User.id).limit(limit + 1))).all()
    page = rows[:limit]
    ids = [item.id for item in page]
    counts = {}
    if ids:
        counts = dict(
            (
                await db.execute(
                    select(Enrollment.learner_id, func.count(Enrollment.id))
                    .where(Enrollment.learner_id.in_(ids))
                    .group_by(Enrollment.learner_id)
                )
            ).all()
        )
    return {
        "items": [
            {
                "id": item.id,
                "email": item.email,
                "displayName": item.display_name,
                "isActive": item.is_active,
                "status": "active" if item.is_active else "suspended",
                "enrollmentCount": counts.get(item.id, 0),
                "createdAt": iso(item.created_at),
                "updatedAt": iso(item.updated_at),
            }
            for item in page
        ],
        "nextCursor": page[-1].id if len(rows) > limit else None,
    }


@router.get("/learners/{learner_id}")
async def learner_detail(learner_id: str, user: SupportPrincipal, db: DB):
    learner = await db.get(User, learner_id)
    if not learner or learner.role != UserRole.learner:
        raise APIError(404, "NOT_FOUND", "Learner not found.")
    enrollments = (
        await db.execute(
            select(Enrollment, Course)
            .join(Course, Course.id == Enrollment.course_id)
            .where(Enrollment.learner_id == learner_id)
            .order_by(Enrollment.created_at.desc())
        )
    ).all()
    progress = (
        await db.execute(
            select(LessonProgress, Lesson, CourseModule, Course)
            .join(Lesson, Lesson.id == LessonProgress.lesson_id)
            .join(CourseModule, CourseModule.id == Lesson.module_id)
            .join(Course, Course.id == CourseModule.course_id)
            .where(LessonProgress.learner_id == learner_id)
            .order_by(LessonProgress.updated_at.desc())
        )
    ).all()
    entitlements = (
        await db.scalars(
            select(Entitlement)
            .where(Entitlement.learner_id == learner_id)
            .order_by(Entitlement.created_at.desc())
        )
    ).all()
    purchases = (
        await db.scalars(
            select(Purchase)
            .where(Purchase.learner_id == learner_id)
            .order_by(Purchase.purchased_at.desc())
        )
    ).all()
    subscriptions = (
        await db.scalars(
            select(Subscription)
            .where(Subscription.learner_id == learner_id)
            .order_by(Subscription.created_at.desc())
        )
    ).all()
    certificates = (
        await db.scalars(
            select(Certificate)
            .where(Certificate.learner_id == learner_id)
            .order_by(Certificate.issued_at.desc())
        )
    ).all()
    attempts = (
        await db.scalars(
            select(AssessmentAttempt)
            .where(AssessmentAttempt.learner_id == learner_id)
            .order_by(AssessmentAttempt.created_at.desc())
        )
    ).all()
    return {
        "identity": {
            "id": learner.id,
            "email": learner.email,
            "displayName": learner.display_name,
            "isActive": learner.is_active,
            "status": "active" if learner.is_active else "suspended",
            "suspendedAt": iso(learner.suspended_at),
            "suspensionReason": learner.suspension_reason,
            "createdAt": iso(learner.created_at),
        },
        "enrollments": [
            {
                "id": e.id,
                "courseId": c.id,
                "courseTitle": c.title,
                "status": e.status,
                "createdAt": iso(e.created_at),
            }
            for e, c in enrollments
        ],
        "progress": [
            {
                "lessonId": lp.lesson_id,
                "lessonTitle": lesson.title,
                "courseId": course.id,
                "courseTitle": course.title,
                "completed": lp.completed,
                "positionSeconds": lp.position_seconds,
                "durationSeconds": lp.duration_seconds,
                "updatedAt": iso(lp.updated_at),
            }
            for lp, lesson, module, course in progress
        ],
        "assessmentResults": [
            {
                "id": a.id,
                "assessmentId": a.assessment_id,
                "status": _enum(a.status),
                "score": a.score,
                "passed": a.passed,
                "createdAt": iso(a.created_at),
            }
            for a in attempts
        ],
        "entitlements": [_entitlement_json(e) for e in entitlements],
        "purchases": [
            {
                "id": p.id,
                "productId": p.product_id,
                "productType": _enum(p.product_type),
                "orderId": p.order_id,
                "transactionId": p.transaction_id,
                "status": _enum(p.status),
                "amountCents": p.amount_cents,
                "currencyCode": p.currency_code,
                "purchasedAt": iso(p.purchased_at),
                "authority": "internalState",
            }
            for p in purchases
        ],
        "subscriptions": [
            {
                "id": s.id,
                "provider": _enum(s.provider),
                "planId": s.plan_id,
                "status": _enum(s.status),
                "currentPeriodEnd": iso(s.current_period_end),
                "cancelAtPeriodEnd": s.cancel_at_period_end,
                "renewsAt": iso(s.renews_at),
                "providerStateUpdatedAt": iso(s.provider_state_updated_at),
                "authority": "providerVerified"
                if s.provider_state_updated_at
                else "pendingUnverified",
            }
            for s in subscriptions
        ],
        "certificates": [
            {
                "id": c.id,
                "courseId": c.course_id,
                "courseTitle": c.course_title,
                "credentialId": c.credential_id,
                "status": _enum(c.status),
                "issuedAt": iso(c.issued_at),
            }
            for c in certificates
        ],
    }


@router.get("/commerce")
async def commerce(
    user: AdminPrincipal,
    db: DB,
    provider: PaymentProvider | None = None,
    learner_id: str | None = Query(None, alias="learnerId"),
    limit: int = Query(50, le=100),
):
    pq = select(Purchase, PaymentTransaction).outerjoin(
        PaymentTransaction, PaymentTransaction.id == Purchase.transaction_id
    )
    sq = select(Subscription)
    if learner_id:
        pq, sq = (
            pq.where(Purchase.learner_id == learner_id),
            sq.where(Subscription.learner_id == learner_id),
        )
    if provider:
        pq, sq = (
            pq.where(PaymentTransaction.provider == provider),
            sq.where(Subscription.provider == provider),
        )
    purchases = (await db.execute(pq.order_by(Purchase.purchased_at.desc()).limit(limit))).all()
    subscriptions = (
        await db.scalars(sq.order_by(Subscription.created_at.desc()).limit(limit))
    ).all()
    plans = (await db.scalars(select(SubscriptionPlan).order_by(SubscriptionPlan.id))).all()
    return {
        "providerOperationsAvailable": False,
        "providerOperationsMessage": "Refunds, cancellations, upgrades, and billing corrections remain provider-owned and fail closed.",
        "purchases": [
            {
                "id": p.id,
                "learnerId": p.learner_id,
                "provider": _enum(t.provider) if t else None,
                "providerTransactionId": t.provider_transaction_id if t else None,
                "orderId": p.order_id,
                "status": _enum(p.status),
                "amountCents": p.amount_cents,
                "currencyCode": p.currency_code,
                "authority": "providerVerified"
                if t and t.status == "verified"
                else "internalState",
                "purchasedAt": iso(p.purchased_at),
            }
            for p, t in purchases
        ],
        "subscriptions": [
            {
                "id": s.id,
                "learnerId": s.learner_id,
                "provider": _enum(s.provider),
                "planId": s.plan_id,
                "status": _enum(s.status),
                "currentPeriodEnd": iso(s.current_period_end),
                "authority": "providerVerified"
                if s.provider_state_updated_at
                else "pendingUnverified",
            }
            for s in subscriptions
        ],
        "plans": [
            {
                "id": p.id,
                "name": p.name,
                "tier": _enum(p.tier),
                "billingInterval": _enum(p.billing_interval),
                "priceCents": p.price_cents,
                "currencyCode": p.currency_code,
                "isActive": p.is_active,
            }
            for p in plans
        ],
    }


@router.get("/entitlements")
async def entitlements(
    user: SupportPrincipal,
    db: DB,
    learner_id: str | None = Query(None, alias="learnerId"),
    status: EntitlementStatus | None = None,
    limit: int = Query(50, le=100),
):
    q = select(Entitlement)
    if learner_id:
        q = q.where(Entitlement.learner_id == learner_id)
    if status:
        q = q.where(Entitlement.status == status)
    rows = (
        await db.scalars(q.order_by(Entitlement.created_at.desc(), Entitlement.id).limit(limit))
    ).all()
    return {"items": [_entitlement_json(item) for item in rows]}


@router.post("/learners/{learner_id}/entitlements", status_code=201)
async def grant_entitlement(
    learner_id: str, body: EntitlementGrantBody, user: AdminPrincipal, db: DB
):
    learner = await db.get(User, learner_id)
    if not learner or learner.role != UserRole.learner:
        raise APIError(404, "NOT_FOUND", "Learner not found.")
    if body.expires_at and body.expires_at <= datetime.now(UTC):
        raise APIError(422, "INVALID_EXPIRY", "Expiry must be in the future.")
    item = Entitlement(
        learner_id=learner_id,
        source=EntitlementSource.admin_grant,
        status=EntitlementStatus.active,
        resource_type=body.resource_type,
        resource_id=body.resource_id,
        starts_at=now(),
        expires_at=body.expires_at,
        metadata_json={"reason": body.reason, "updatedBy": user.id, "manualOverride": True},
    )
    db.add(item)
    await db.flush()
    log_audit_event(
        db,
        actor_id=user.id,
        action="entitlement.manual_granted",
        target_entity="entitlement",
        target_id=item.id,
        result="success",
        reason=body.reason,
        metadata={
            "targetUserId": learner_id,
            "previousState": None,
            "newState": _entitlement_json(item),
        },
    )
    await db.commit()
    await db.refresh(item)
    return _entitlement_json(item)


@router.post("/entitlements/{entitlement_id}/extend")
async def extend_entitlement(
    entitlement_id: str, body: EntitlementChangeBody, user: AdminPrincipal, db: DB
):
    if not body.expires_at or body.expires_at <= datetime.now(UTC):
        raise APIError(422, "INVALID_EXPIRY", "A future expiry is required.")
    item = await db.scalar(
        select(Entitlement).where(Entitlement.id == entitlement_id).with_for_update()
    )
    if not item:
        raise APIError(404, "NOT_FOUND", "Entitlement not found.")
    if item.source != EntitlementSource.admin_grant:
        raise APIError(
            409, "PROVIDER_OWNED", "Provider-owned entitlements cannot be changed manually."
        )
    if item.version != body.expected_version:
        raise APIError(409, "STALE_VERSION", "Entitlement changed since it was loaded.")
    previous = _entitlement_json(item)
    item.expires_at = body.expires_at
    item.version += 1
    item.metadata_json = {**(item.metadata_json or {}), "reason": body.reason, "updatedBy": user.id}
    log_audit_event(
        db,
        actor_id=user.id,
        action="entitlement.manual_extended",
        target_entity="entitlement",
        target_id=item.id,
        result="success",
        reason=body.reason,
        metadata={
            "targetUserId": item.learner_id,
            "previousState": previous,
            "newState": _entitlement_json(item),
        },
    )
    await db.commit()
    await db.refresh(item)
    return _entitlement_json(item)


@router.post("/entitlements/{entitlement_id}/revoke")
async def revoke_entitlement(
    entitlement_id: str, body: EntitlementChangeBody, user: AdminPrincipal, db: DB
):
    item = await db.scalar(
        select(Entitlement).where(Entitlement.id == entitlement_id).with_for_update()
    )
    if not item:
        raise APIError(404, "NOT_FOUND", "Entitlement not found.")
    if item.source != EntitlementSource.admin_grant:
        raise APIError(
            409, "PROVIDER_OWNED", "Provider-owned entitlements cannot be revoked manually."
        )
    if item.version != body.expected_version:
        raise APIError(409, "STALE_VERSION", "Entitlement changed since it was loaded.")
    previous = _entitlement_json(item)
    item.status = EntitlementStatus.revoked
    item.revoked_at = now()
    item.version += 1
    item.metadata_json = {**(item.metadata_json or {}), "reason": body.reason, "updatedBy": user.id}
    log_audit_event(
        db,
        actor_id=user.id,
        action="entitlement.manual_revoked",
        target_entity="entitlement",
        target_id=item.id,
        result="success",
        reason=body.reason,
        metadata={
            "targetUserId": item.learner_id,
            "previousState": previous,
            "newState": _entitlement_json(item),
        },
    )
    await db.commit()
    await db.refresh(item)
    return _entitlement_json(item)


@router.get("/notifications")
async def notifications(
    user: SupportPrincipal,
    db: DB,
    learner_id: str | None = Query(None, alias="learnerId"),
    limit: int = Query(50, le=100),
):
    q = select(Notification)
    if learner_id:
        q = q.where(Notification.user_id == learner_id)
    rows = (await db.scalars(q.order_by(Notification.created_at.desc()).limit(limit))).all()
    return {
        "deliveryInfrastructure": "notConfigured",
        "items": [
            {
                "id": n.id,
                "userId": n.user_id,
                "title": n.title,
                "body": n.body,
                "type": _enum(n.type),
                "priority": _enum(n.priority),
                "createdAt": iso(n.created_at),
                "deliveryState": "createdInApp",
                "delivered": False,
            }
            for n in rows
        ],
    }


@router.post("/notifications", status_code=201)
async def create_notification(body: NotificationCreateBody, user: AdminPrincipal, db: DB):
    target = await db.get(User, body.user_id)
    if not target:
        raise APIError(404, "NOT_FOUND", "Target user not found.")
    item = Notification(
        user_id=target.id,
        type=body.notification_type,
        title=body.title,
        body=body.body,
        priority=body.priority,
        metadata_json={"createdBy": user.id, "deliveryState": "createdInApp"},
    )
    db.add(item)
    await db.flush()
    log_audit_event(
        db,
        actor_id=user.id,
        action="notification.created",
        target_entity="notification",
        target_id=item.id,
        result="success",
        metadata={"targetUserId": target.id, "deliveryState": "createdInApp"},
    )
    await db.commit()
    await db.refresh(item)
    return {"id": item.id, "deliveryState": "createdInApp", "delivered": False}


@router.get("/super/admins")
async def admins(user: SuperAdminPrincipal, db: DB):
    rows = (
        await db.scalars(select(User).where(User.role != UserRole.learner).order_by(User.email))
    ).all()
    return {
        "items": [
            {
                "id": u.id,
                "email": u.email,
                "displayName": u.display_name,
                "role": _enum(u.role),
                "isActive": u.is_active,
                "createdAt": iso(u.created_at),
            }
            for u in rows
        ]
    }


@router.post("/super/admins/{admin_id}/role")
async def change_admin_role(admin_id: str, body: RoleChangeBody, user: SuperAdminPrincipal, db: DB):
    target = await db.scalar(select(User).where(User.id == admin_id).with_for_update())
    if not target:
        raise APIError(404, "NOT_FOUND", "User not found.")
    if admin_id == user.id:
        raise APIError(
            409, "SELF_MODIFICATION_FORBIDDEN", "Super administrators cannot change their own role."
        )
    if body.role == UserRole.learner:
        raise APIError(
            422,
            "INVALID_ROLE",
            "Use account deactivation instead of converting an administrator to learner.",
        )
    previous = _enum(target.role)
    target.role = body.role
    log_audit_event(
        db,
        actor_id=user.id,
        action="admin.role_changed",
        target_entity="user",
        target_id=target.id,
        result="success",
        reason=body.reason,
        metadata={"previousState": previous, "newState": _enum(body.role)},
    )
    await db.commit()
    return {"id": target.id, "role": _enum(target.role)}


async def _set_account_active(target_id: str, active: bool, body: ReasonBody, user, db):
    target = await db.scalar(select(User).where(User.id == target_id).with_for_update())
    if not target:
        raise APIError(404, "NOT_FOUND", "User not found.")
    if target.id == user.id and not active:
        raise APIError(409, "SELF_MODIFICATION_FORBIDDEN", "You cannot suspend your own account.")
    if target.role == UserRole.super_admin and not active:
        owners = await db.scalar(
            select(func.count(User.id)).where(
                User.role == UserRole.super_admin, User.is_active.is_(True)
            )
        )
        if (owners or 0) <= 1:
            raise APIError(
                409, "LAST_SUPER_ADMIN", "The last active super administrator cannot be suspended."
            )
    previous = target.is_active
    target.is_active = active
    target.suspended_at = None if active else now()
    target.suspension_reason = None if active else body.reason
    if not active:
        await db.execute(
            update(AuthSession)
            .where(AuthSession.user_id == target.id, AuthSession.revoked_at.is_(None))
            .values(revoked_at=now())
        )
    log_audit_event(
        db,
        actor_id=user.id,
        action="account.reactivated" if active else "account.suspended",
        target_entity="user",
        target_id=target.id,
        result="success",
        reason=body.reason,
        metadata={"previousState": previous, "newState": active},
    )
    await db.commit()
    return {"id": target.id, "isActive": target.is_active}


@router.post("/super/users/{target_id}/suspend")
async def suspend_user(target_id: str, body: ReasonBody, user: SuperAdminPrincipal, db: DB):
    return await _set_account_active(target_id, False, body, user, db)


@router.post("/super/users/{target_id}/reactivate")
async def reactivate_user(target_id: str, body: ReasonBody, user: SuperAdminPrincipal, db: DB):
    return await _set_account_active(target_id, True, body, user, db)


@router.post("/super/users/{target_id}/revoke-sessions")
async def revoke_sessions(target_id: str, body: ReasonBody, user: SuperAdminPrincipal, db: DB):
    if not await db.get(User, target_id):
        raise APIError(404, "NOT_FOUND", "User not found.")
    result = await db.execute(
        update(AuthSession)
        .where(AuthSession.user_id == target_id, AuthSession.revoked_at.is_(None))
        .values(revoked_at=now())
    )
    log_audit_event(
        db,
        actor_id=user.id,
        action="sessions.revoked",
        target_entity="user",
        target_id=target_id,
        result="success",
        reason=body.reason,
        metadata={"revokedCount": result.rowcount},
    )
    await db.commit()
    return {"revokedCount": result.rowcount}


@router.get("/super/settings")
async def platform_settings(user: SuperAdminPrincipal, db: DB):
    stored = {s.key: s for s in (await db.scalars(select(PlatformSetting))).all()}
    return {
        "items": [
            {
                "key": key,
                "value": stored[key].value if key in stored else default,
                "version": stored[key].version if key in stored else 0,
                "description": description,
                "updatedAt": iso(stored[key].updated_at) if key in stored else None,
                "updatedBy": stored[key].updated_by if key in stored else None,
            }
            for key, (default, description) in SETTING_DEFINITIONS.items()
        ]
    }


@router.put("/super/settings/{key}")
async def update_platform_setting(
    key: str, body: SettingChangeBody, user: SuperAdminPrincipal, db: DB
):
    if key not in SETTING_DEFINITIONS:
        raise APIError(422, "UNSUPPORTED_SETTING", "This platform setting is not supported.")
    item = await db.scalar(
        select(PlatformSetting).where(PlatformSetting.key == key).with_for_update()
    )
    previous = SETTING_DEFINITIONS[key][0] if item is None else item.value
    current_version = 0 if item is None else item.version
    if current_version != body.expected_version:
        raise APIError(409, "STALE_VERSION", "Platform setting changed since it was loaded.")
    if item is None:
        item = PlatformSetting(
            key=key,
            value=body.value,
            version=1,
            description=SETTING_DEFINITIONS[key][1],
            updated_by=user.id,
        )
        db.add(item)
    else:
        item.value = body.value
        item.version += 1
        item.updated_by = user.id
    log_audit_event(
        db,
        actor_id=user.id,
        action="platform.setting_changed",
        target_entity="platform_setting",
        target_id=key,
        result="success",
        reason=body.reason,
        metadata={"previousState": previous, "newState": body.value, "version": item.version},
    )
    await db.commit()
    await db.refresh(item)
    return {"key": item.key, "value": item.value, "version": item.version}


@router.get("/super/integrations")
async def integrations(user: SuperAdminPrincipal):
    settings = get_settings()

    def configured(value):
        return "configured" if bool(value) else "notConfigured"

    return {
        "items": [
            {
                "key": "postgresql",
                "status": "configured",
                "detail": "Database URL configured; live health is reported by readiness.",
            },
            {
                "key": "redis",
                "status": "configured",
                "detail": "Redis URL configured; live health is reported by readiness.",
            },
            {
                "key": "apple",
                "status": configured(settings.apple_private_key and settings.apple_key_id),
                "detail": "Provider operations remain fail-closed.",
            },
            {
                "key": "googlePlay",
                "status": configured(settings.google_play_service_account_json),
                "detail": "Provider operations remain fail-closed.",
            },
            {
                "key": "stripe",
                "status": configured(settings.stripe_api_key and settings.stripe_webhook_secret),
                "detail": "Provider operations remain fail-closed.",
            },
            {
                "key": "smtp",
                "status": configured(settings.smtp_host and settings.smtp_from_address),
                "detail": "Configuration status only; no credential values exposed.",
            },
            {
                "key": "fcm",
                "status": "notImplemented",
                "detail": "Push delivery is unavailable and fail-closed.",
            },
            {
                "key": "apns",
                "status": "notImplemented",
                "detail": "Push delivery is unavailable and fail-closed.",
            },
            {
                "key": "mediaCdn",
                "status": configured(settings.media_cdn_base_url),
                "detail": "Signed origin enforcement is configured independently.",
            },
            {
                "key": "analytics",
                "status": "notImplemented",
                "detail": "No production analytics adapter.",
            },
            {
                "key": "crashReporting",
                "status": configured(settings.sentry_dsn),
                "detail": "Configuration status only.",
            },
        ]
    }


@router.get("/super/readiness")
async def system_readiness(request: Request, user: SuperAdminPrincipal, db: DB):
    revision = await db.scalar(select(func.count()).select_from(User))
    schema = await schema_status(db)
    redis_ready = await request.app.state.rate_limiter.redis_ready()
    required = request.app.state.settings.redis_required
    return {
        "applicationVersion": "1.0.0",
        **schema,
        "databaseStatus": "healthy",
        "userRecordCount": revision,
        "redisStatus": "healthy" if redis_ready else "degraded",
        "redisRequired": required,
        "isReady": schema["schemaReady"] and (redis_ready or not required),
        "note": "Public /health/ready is the traffic readiness endpoint.",
    }
