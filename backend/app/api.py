import hashlib
import re
import secrets
from datetime import timedelta
from typing import Annotated

from fastapi import APIRouter, Header, Query, Request, Response
from sqlalchemy import and_, func, or_, select, update
from sqlalchemy.exc import IntegrityError

from .commerce_providers import *
from .commerce_services import *
from .config import get_settings
from .delivery import PasswordResetDeliveryError
from .dependencies import (
    DB,
    AdminPrincipal,
    CmsPrincipal,
    ContentManagerPrincipal,
    Principal,
    SupportPrincipal,
)
from .errors import APIError
from .media import (
    issue_download_token,
    issue_media_token,
    signed_download_url,
    signed_media_url,
)
from .models import *
from .schemas import *
from .security import access_token, hash_password, random_token, token_hash, verify_password
from .services import *
from .dependencies import OptionalPrincipal
from .academic import scope_courses, profile_for, classification_json, validate_selection, lesson_items, guard_course_history, required_quizzes_passed, ensure_asset_published

router = APIRouter()


async def platform_flag(db, key: str, default: bool) -> bool:
    value = await db.scalar(select(PlatformSetting.value).where(PlatformSetting.key == key))
    return default if value is None else bool(value)


def identity(u):
    role_val = u.role.value if hasattr(u.role, "value") else str(u.role)
    return {
        "id": u.id,
        "email": u.email,
        "displayName": u.display_name,
        "hasCompletedOnboarding": u.onboarding_complete,
        "role": role_val,
    }


async def create_session(db, u):
    raw = random_token()
    session = AuthSession(
        user_id=u.id,
        refresh_token_hash=token_hash(raw),
        expires_at=now() + timedelta(days=get_settings().refresh_token_days),
    )
    db.add(session)
    await db.flush()
    access, expires = access_token(u.id, session.id, u.role.value)
    await db.commit()
    return {
        "identity": identity(u),
        "accessToken": access,
        "refreshToken": raw,
        "expiresAt": iso(expires),
        "sessionId": session.id,
    }


def policy_json(c):
    return {
        "type": c.policy_kind.value,
        "requiredTier": c.required_tier,
        "requiredBundleId": c.required_bundle_id,
    }


def course_summary(c, lesson_count=0):
    return {
        **classification_json(c),
        "id": c.id,
        "title": c.title,
        "subtitle": c.subtitle,
        "coverReference": c.cover_reference,
        "instructors": [],
        "categoryIds": [],
        "level": c.level,
        "policy": policy_json(c),
        "languageCode": c.language_code,
        "rating": float(c.rating),
        "ratingCount": c.rating_count,
        "durationSeconds": c.duration_seconds,
        "lessonCount": lesson_count,
        "publishedAt": iso(c.published_at or c.created_at),
        "tags": [],
        "progress": None,
        "protectionPolicy": (
            c.protection_policy.value
            if hasattr(c, "protection_policy") and c.protection_policy
            else "blockCaptureWhereSupported"
        ),
    }


async def course_summaries(db, courses):
    course_ids = [course.id for course in courses]
    counts = {}
    if course_ids:
        counts = dict(
            (
                await db.execute(
                    select(CourseModule.course_id, func.count(Lesson.id))
                    .join(Lesson, Lesson.module_id == CourseModule.id)
                    .where(CourseModule.course_id.in_(course_ids))
                    .group_by(CourseModule.course_id)
                )
            ).all()
        )
    return [course_summary(course, counts.get(course.id, 0)) for course in courses]


@router.get("/courses")
async def courses(
    db: DB,
    user: OptionalPrincipal,
    search: str = "",
    category_id: str | None = Query(None, alias="categoryId"),
    subject_id: str | None = Query(None, alias="subjectId"),
    level: str | None = None,
    sort: str = "relevance",
    cursor: str | None = None,
    page_size: int = Query(12, alias="pageSize", ge=1, le=50),
):
    q = await scope_courses(db, select(Course).where(Course.status == Lifecycle.published), user)
    if subject_id:
        q = q.where(Course.subject_id == subject_id)
    if search:
        q = q.where(
            or_(
                Course.title.ilike(f"%{search.strip()}%"),
                Course.subtitle.ilike(f"%{search.strip()}%"),
            )
        )
    if level:
        q = q.where(Course.level == level)
    if category_id:
        if await profile_for(db, user):
            q = q.where(Course.subject_id == category_id)
        else:
            q = q.join(CourseCategory).where(CourseCategory.category_id == category_id)
    if sort not in {"relevance", "newest", "rating"}:
        raise APIError(400, "INVALID_SORT", "The requested course sort is invalid.")
    if cursor:
        if sort == "rating":
            rating, id_ = scalar_cursor_decode(cursor)
            q = q.where(or_(Course.rating < rating, and_(Course.rating == rating, Course.id < id_)))
        else:
            ts, id_ = cursor_decode(cursor)
            q = q.where(
                or_(Course.published_at < ts, and_(Course.published_at == ts, Course.id < id_))
            )
    order = (
        (Course.rating.desc(), Course.id.desc())
        if sort == "rating"
        else (Course.published_at.desc(), Course.id.desc())
    )
    rows = (await db.scalars(q.order_by(*order).limit(page_size + 1))).all()
    more = len(rows) > page_size
    rows = rows[:page_size]
    next_cursor = None
    if more:
        next_cursor = (
            scalar_cursor_encode(float(rows[-1].rating), rows[-1].id)
            if sort == "rating"
            else cursor_encode(rows[-1].published_at, rows[-1].id)
        )
    return {
        "items": await course_summaries(db, rows),
        "nextCursor": next_cursor,
        "isFromCache": False,
    }


@router.get("/categories")
async def categories(db: DB, user: OptionalPrincipal):
    if await profile_for(db, user):
        query = await scope_courses(db, select(Course.subject_id).where(Course.status == Lifecycle.published), user)
        rows = (await db.scalars(select(Subject).where(Subject.id.in_(query), Subject.is_active.is_(True)).order_by(Subject.sort_order, Subject.name))).all()
        return {"items": [{"id": x.id, "name": x.name, "iconName": "school", "isSubject": True} for x in rows]}
    rows = (await db.scalars(select(Category).order_by(Category.name).limit(200))).all()
    return {"items": [{"id": x.id, "name": x.name, "iconName": x.icon_name} for x in rows]}


@router.get("/courses/{course_id}")
async def course_detail(course_id: str, db: DB):
    c = await db.get(Course, course_id)
    if not c or c.status != Lifecycle.published:
        raise APIError(404, "NOT_FOUND", "Course not found.")
    mods = (
        await db.scalars(
            select(CourseModule)
            .where(CourseModule.course_id == c.id)
            .order_by(CourseModule.position)
        )
    ).all()
    lessons = (
        (
            await db.scalars(
                select(Lesson)
                .where(Lesson.module_id.in_([module.id for module in mods]))
                .order_by(Lesson.module_id, Lesson.position)
            )
        ).all()
        if mods
        else []
    )
    lessons_by_module: dict[str, list[Lesson]] = {}
    content_items = await lesson_items(db, [lesson.id for lesson in lessons])
    item_lesson_ids = set(await db.scalars(select(LessonContentItem.lesson_id).where(LessonContentItem.lesson_id.in_([lesson.id for lesson in lessons]))))
    for lesson in lessons:
        lessons_by_module.setdefault(lesson.module_id, []).append(lesson)
    out = []
    for m in mods:
        module_lessons = lessons_by_module.get(m.id, [])
        out.append(
            {
                "id": m.id,
                "title": m.title,
                "position": m.position,
                "policy": {"type": m.policy_kind.value},
                "lessons": [
                    {
                        "id": l.id,
                        "title": l.title,
                        "position": l.position,
                        "estimatedDurationSeconds": l.duration_seconds,
                        "isPreview": l.is_preview,
                        "policy": {"type": l.policy_kind.value},
                        "protectionPolicy": (
                            l.protection_policy.value
                            if hasattr(l, "protection_policy") and l.protection_policy
                            else "blockCaptureWhereSupported"
                        ),
                        "content": {"type": l.content_type, "referenceId": l.content_ref},
                        "contentItems": [{**item, "body": None} for item in content_items.get(l.id, [])],
                        "hasContentItems": l.id in item_lesson_ids or l.content_ref.startswith("lesson-shell:"),
                    }
                    for l in module_lessons
                ],
            }
        )
    return {
        "summary": course_summary(c, len(lessons)),
        "description": c.description,
        "learningOutcomes": c.learning_outcomes,
        "prerequisites": c.prerequisites,
        "modules": out,
        "updatedAt": iso(c.updated_at),
    }


@router.post("/courses/by-ids")
async def courses_by_ids(body: CourseIds, db: DB, user: OptionalPrincipal):
    rows = (
        await db.scalars(
            await scope_courses(db, select(Course).where(Course.id.in_(body.ids), Course.status == Lifecycle.published), user)
        )
    ).all()
    by_id = {x.id: x for x in rows}
    ordered = [by_id[x] for x in body.ids if x in by_id]
    return {"items": await course_summaries(db, ordered)}


@router.get("/home")
async def home(db: DB, user: OptionalPrincipal):
    courses = (
        await db.scalars(
            (await scope_courses(db, select(Course), user))
            .where(Course.status == Lifecycle.published)
            .order_by(Course.published_at.desc(), Course.id.desc())
            .limit(20)
        )
    ).all()
    categories = (await db.scalars(select(Category).order_by(Category.name).limit(12))).all()
    profile = await profile_for(db, user)
    if profile:
        query = await scope_courses(db, select(Course.subject_id).where(Course.status == Lifecycle.published), user)
        categories = (await db.scalars(select(Subject).where(Subject.id.in_(query), Subject.is_active.is_(True)).order_by(Subject.sort_order, Subject.name))).all()
    summaries = await course_summaries(db, courses)
    return {
        "sections": [
            {
                "id": "new-releases",
                "kind": "newReleases",
                "title": "New releases",
                "items": summaries[:10],
            },
            {
                "id": "recommended",
                "kind": "recommended",
                "title": "Recommended",
                "items": summaries[10:20],
            },
            {
                "id": "popular-categories",
                "kind": "popularCategories",
                "title": "Subjects" if profile else "Popular categories",
                "items": [
                    {"id": x.id, "name": x.name, "iconName": getattr(x, "icon_name", "school"), "isSubject": bool(profile)} for x in categories
                ],
            },
        ],
        "updatedAt": iso(now()),
    }


@router.get("/bookmarks")
async def bookmark_ids(user: Principal, db: DB):
    return {
        "items": list(
            (
                await db.scalars(
                    select(Bookmark.course_id)
                    .where(Bookmark.learner_id == user.id)
                    .order_by(Bookmark.created_at.desc())
                    .limit(200)
                )
            ).all()
        )
    }


@router.post("/bookmarks")
async def set_bookmark(body: BookmarkIn, user: Principal, db: DB):
    if not await db.get(Course, body.course_id):
        raise APIError(404, "NOT_FOUND", "Course not found.")
    existing = await db.scalar(
        select(Bookmark).where(Bookmark.learner_id == user.id, Bookmark.course_id == body.course_id)
    )
    if body.bookmarked and not existing:
        db.add(Bookmark(learner_id=user.id, course_id=body.course_id))
    elif not body.bookmarked and existing:
        await db.delete(existing)
    await db.commit()
    return {"bookmarked": body.bookmarked}


@router.get("/recently-viewed")
async def recently_viewed(user: Principal, db: DB, limit: int = Query(20, ge=1, le=20)):
    return {
        "items": list(
            (
                await db.scalars(
                    select(RecentlyViewed.course_id)
                    .where(RecentlyViewed.learner_id == user.id)
                    .order_by(RecentlyViewed.viewed_at.desc())
                    .limit(limit)
                )
            ).all()
        )
    }


@router.post("/recently-viewed")
async def record_view(body: RecentlyViewedIn, user: Principal, db: DB):
    if not await db.get(Course, body.course_id):
        raise APIError(404, "NOT_FOUND", "Course not found.")
    value = await db.scalar(
        select(RecentlyViewed).where(
            RecentlyViewed.learner_id == user.id, RecentlyViewed.course_id == body.course_id
        )
    )
    if value:
        value.viewed_at = now()
    else:
        db.add(RecentlyViewed(learner_id=user.id, course_id=body.course_id, viewed_at=now()))
    await db.commit()
    return {"recorded": True}


@router.get("/courses/{course_id}/progress")
async def get_progress(course_id: str, user: Principal, db: DB):
    return await _progress_json(db, user.id, course_id)


async def _progress_json(db, learner_id, course_id):
    rows = (
        await db.scalars(
            select(LessonProgress)
            .join(Lesson, LessonProgress.lesson_id == Lesson.id)
            .join(CourseModule, Lesson.module_id == CourseModule.id)
            .where(LessonProgress.learner_id == learner_id, CourseModule.course_id == course_id)
        )
    ).all()
    revision = max([x.revision for x in rows] or [0])
    return {
        "courseId": course_id,
        "lessons": {
            x.lesson_id: {
                "lessonId": x.lesson_id,
                "positionSeconds": x.position_seconds,
                "durationSeconds": x.duration_seconds,
                "completed": x.completed,
                "updatedAt": iso(x.updated_at),
            }
            for x in rows
        },
        "serverRevision": revision,
        "updatedAt": iso(max([x.updated_at for x in rows] or [now()])),
    }


@router.post("/courses/{course_id}/progress/sync")
async def sync_progress(course_id: str, body: ProgressSync, user: Principal, db: DB):
    enrollment = await db.scalar(
        select(Enrollment.id).where(
            Enrollment.learner_id == user.id,
            Enrollment.course_id == course_id,
            Enrollment.status == "active",
        )
    )
    if not enrollment:
        raise APIError(403, "ACCESS_DENIED", "An active enrollment is required.")
    if db.bind and db.bind.dialect.name == "postgresql":
        await db.execute(
            select(
                func.pg_advisory_xact_lock(
                    func.hashtextextended(f"progress:{user.id}:{course_id}", 0)
                )
            )
        )
    lesson_types = dict(
        (
            await db.execute(
                select(Lesson.id, Lesson.content_type)
                .join(CourseModule)
                .where(CourseModule.course_id == course_id)
            )
        ).all()
    )
    lesson_ids = set(lesson_types)
    acked = []
    mutation_ids = [mutation.id for mutation in body.mutations]
    seen_mutations = {
        mutation.mutation_id: mutation
        for mutation in (
            await db.scalars(
                select(ProgressMutation).where(
                    ProgressMutation.learner_id == user.id,
                    ProgressMutation.mutation_id.in_(mutation_ids),
                )
            )
        ).all()
    }
    for mutation in body.mutations:
        if mutation.lesson_id not in lesson_ids:
            raise APIError(422, "INVALID_RESOURCE", "Lesson does not belong to the course.")
        if lesson_types[mutation.lesson_id] == "quiz" and mutation.kind == "completion" and not await db.scalar(select(LessonContentItem.id).where(LessonContentItem.lesson_id == mutation.lesson_id).limit(1)):
            raise APIError(
                403, "SERVER_COMPLETION_REQUIRED", "Complete the assessment to finish this lesson."
            )
        if mutation.kind == "completion" and mutation.completed and not await required_quizzes_passed(db, user.id, mutation.lesson_id):
            raise APIError(403, "SERVER_COMPLETION_REQUIRED", "Watch required videos and pass every quiz before completing this lesson.")
        digest = fingerprint(mutation.model_dump(mode="json"))
        seen = seen_mutations.get(mutation.id)
        if seen:
            if seen.request_hash != digest:
                raise APIError(
                    409, "IDEMPOTENCY_CONFLICT", "Mutation ID was reused with different data."
                )
            acked.append(mutation.id)
            continue
        row = await db.scalar(
            select(LessonProgress)
            .where(
                LessonProgress.learner_id == user.id, LessonProgress.lesson_id == mutation.lesson_id
            )
            .with_for_update()
        )
        if not row:
            row = LessonProgress(learner_id=user.id, lesson_id=mutation.lesson_id, duration_seconds=0, position_seconds=0, completed=False, revision=0)
            db.add(row)
        row.duration_seconds = max(row.duration_seconds, mutation.duration_seconds)
        row.position_seconds = min(
            row.duration_seconds, max(row.position_seconds, mutation.position_seconds)
        )
        row.completed = row.completed or (mutation.kind == "completion" and mutation.completed)
        row.revision += 1
        recorded = ProgressMutation(
            learner_id=user.id, mutation_id=mutation.id, request_hash=digest
        )
        db.add(recorded)
        seen_mutations[mutation.id] = recorded
        acked.append(mutation.id)
    await db.commit()
    return {
        "progress": await _progress_json(db, user.id, course_id),
        "acknowledgedMutationIds": acked,
    }


@router.get("/playback/{asset_id}")
async def playback(asset_id: str, user: Principal, db: DB):
    asset = await db.scalar(
        select(MediaAsset).where(
            MediaAsset.asset_id == asset_id, MediaAsset.kind == "hls", MediaAsset.status == "active"
        )
    )
    if not asset:
        raise APIError(404, "NOT_FOUND", "Playback resource not found.")
    await ensure_asset_published(db, asset)
    lesson = await db.get(Lesson, asset.lesson_id)
    linked_item = await db.get(LessonContentItem, asset.content_item_id) if asset.content_item_id else None
    if not lesson or (lesson.content_ref != asset.asset_id and not (linked_item and linked_item.lesson_id == lesson.id and linked_item.status == Lifecycle.published)):
        raise APIError(404, "NOT_FOUND", "Playback resource not found.")
    decision = await resolve_access(db, user.id, ResourceType.lesson, lesson.id)
    if not decision["allowed"]:
        raise APIError(
            403, "ENTITLEMENT_REQUIRED", "The current entitlement does not permit playback."
        )
    if asset.provider and asset.provider != "cloudinary":
        raise APIError(503, "PROVIDER_UNAVAILABLE", "Media provider is unavailable.")
    if asset.provider == "cloudinary":
        from .media_provider import delivery_url
        return {"streamUrl": delivery_url(asset), "kind": "mp4", "subtitles": [],
                "posterUrl": delivery_url(asset, poster=True), "watchProgress": True,
                "renewAfterSeconds": max(30, get_settings().media_token_minutes * 60 - 90)}
    module = await db.get(CourseModule, lesson.module_id)
    token, expires = issue_media_token(
        settings=get_settings(),
        learner_id=user.id,
        asset_id=asset.asset_id,
        lesson_id=lesson.id,
        course_id=module.course_id,
    )
    return {
        "watchProgress": True,
        "streamUrl": signed_media_url(get_settings(), asset.asset_id, token),
        "kind": "hls",
        "subtitles": [],
        "expiresAt": iso(expires),
        "renewAfterSeconds": max(30, get_settings().media_token_minutes * 60 - 90),
    }


@router.get("/media/{asset_id}/authorization")
async def media_authorization(asset_id: str, user: Principal, db: DB):
    asset = await db.scalar(
        select(MediaAsset).where(MediaAsset.asset_id == asset_id, MediaAsset.status == "active")
    )
    if not asset:
        raise APIError(404, "NOT_FOUND", "Media resource not found.")
    await ensure_asset_published(db, asset)
    lesson = await db.get(Lesson, asset.lesson_id)
    module = await db.get(CourseModule, lesson.module_id)
    decision = await resolve_access(db, user.id, ResourceType.lesson, lesson.id)
    if not decision["allowed"]:
        raise APIError(
            403, "ENTITLEMENT_REQUIRED", "The current entitlement does not permit this media."
        )
    token, expires = issue_media_token(
        settings=get_settings(),
        learner_id=user.id,
        asset_id=asset.asset_id,
        lesson_id=lesson.id,
        course_id=module.course_id,
    )
    return {
        "assetId": asset.asset_id,
        "kind": asset.kind,
        "url": signed_media_url(get_settings(), asset.asset_id, token),
        "expiresAt": iso(expires),
        "renewAfterSeconds": max(30, get_settings().media_token_minutes * 60 - 90),
    }


# --- Phase 8 Download & Offline Learning Endpoints ---


@router.post("/downloads/authorize")
async def download_authorization(body: DownloadAuthorizeIn, user: Principal, db: DB):
    return await _download_auth(db, user.id, body.resource_type, body.resource_id, body.quality)


@router.get("/downloads/{resource_type}/{resource_id}/authorization")
async def download_authorization_get(
    resource_type: str, resource_id: str, user: Principal, db: DB, quality: str = "standard"
):
    return await _download_auth(db, user.id, resource_type, resource_id, quality)


async def _download_auth(
    db: AsyncSession, learner_id: str, resource_type_str: str, resource_id: str, quality: str
):
    requested_id = resource_id
    requested_type = resource_type_str
    selected_asset = None
    if resource_type_str in {"video", "document", "resource"}:
        selected_asset = await db.scalar(select(MediaAsset).where(MediaAsset.asset_id == resource_id, MediaAsset.status == "active"))
        if not selected_asset:
            raise APIError(404, "NOT_FOUND", "Registered download resource not found.")
        await ensure_asset_published(db, selected_asset)
        if resource_type_str == "video" and selected_asset.kind == "hls":
            selected_asset = await db.scalar(select(MediaAsset).where(MediaAsset.content_item_id == selected_asset.content_item_id, MediaAsset.kind == "download", MediaAsset.status == "active")) if selected_asset.content_item_id else None
        if not selected_asset or selected_asset.kind != "download":
            raise APIError(503, "DOWNLOAD_ASSET_UNVERIFIED", "A verified downloadable file is required; streaming playlists cannot be downloaded as a video file.")
        await ensure_asset_published(db, selected_asset)
        resource_id = selected_asset.lesson_id
        resource_type_str = "lesson"
    try:
        res_type = ResourceType(resource_type_str)
    except ValueError as error:
        raise APIError(
            400, "UNSUPPORTED_RESOURCE_TYPE", "Unknown download resource type."
        ) from error
    if quality not in {"dataSaver", "standard", "high"}:
        raise APIError(400, "UNSUPPORTED_DOWNLOAD_QUALITY", "Unknown download quality.")

    if res_type == ResourceType.lesson:
        lesson = await db.get(Lesson, resource_id)
        if not lesson:
            raise APIError(404, "NOT_FOUND", "Lesson resource not found.")
        if not lesson.is_downloadable:
            raise APIError(
                403, "DOWNLOAD_NOT_PERMITTED", "This lesson is not configured for offline download."
            )
        module = await db.get(CourseModule, lesson.module_id)
        course = await db.get(Course, module.course_id)
        course_id = course.id
        lesson_id = lesson.id
        title = lesson.title
        course_title = course.title
        protection_policy = (
            lesson.protection_policy.value
            if hasattr(lesson, "protection_policy") and lesson.protection_policy
            else (
                course.protection_policy.value
                if hasattr(course, "protection_policy") and course.protection_policy
                else "blockCaptureWhereSupported"
            )
        )

        decision = await resolve_access(db, learner_id, ResourceType.lesson, lesson.id)
        if not decision["allowed"]:
            raise APIError(
                403,
                "ENTITLEMENT_REQUIRED",
                "The current entitlement does not permit this download.",
            )

        asset = selected_asset or await db.scalar(
            select(MediaAsset)
            .where(
                MediaAsset.lesson_id == lesson.id,
                MediaAsset.status == "active",
            )
            .order_by(
                (MediaAsset.kind == "download").desc(),
                MediaAsset.created_at.desc(),
            )
        )
        if (
            asset is None
            or asset.download_size_bytes is None
            or asset.download_size_bytes <= 0
            or asset.checksum_sha256 is None
            or re.fullmatch(r"[0-9a-fA-F]{64}", asset.checksum_sha256) is None
        ):
            raise APIError(
                503,
                "DOWNLOAD_ASSET_UNVERIFIED",
                "The offline asset lacks authoritative size or checksum metadata.",
            )
        await ensure_asset_published(db, asset)
        asset_id = asset.asset_id
        size_bytes = asset.download_size_bytes
        checksum = asset.checksum_sha256.lower()
        asset_version = f"v{int(lesson.updated_at.timestamp()) if lesson.updated_at else 1}"

        # Subtitles if any
        sub_assets = (
            await db.scalars(
                select(MediaAsset).where(
                    MediaAsset.lesson_id == lesson.id,
                    MediaAsset.kind == "subtitle",
                    MediaAsset.status == "active",
                )
            )
        ).all()
        subtitles = [
            {
                "id": s.asset_id,
                "label": "English" if "en" in s.asset_id else "Subtitles",
                "languageCode": "en",
                "url": signed_media_url(
                    get_settings(),
                    s.asset_id,
                    issue_media_token(
                        settings=get_settings(),
                        learner_id=learner_id,
                        asset_id=s.asset_id,
                        lesson_id=lesson.id,
                        course_id=course_id,
                    )[0],
                ),
            }
            for s in sub_assets
        ]

    elif res_type == ResourceType.course:
        course = await db.get(Course, resource_id)
        if not course or course.status != Lifecycle.published:
            raise APIError(404, "NOT_FOUND", "Course not found.")
        decision = await resolve_access(db, learner_id, ResourceType.course, course.id)
        if not decision["allowed"]:
            raise APIError(
                403,
                "ENTITLEMENT_REQUIRED",
                "The current entitlement does not permit this download.",
            )
        course_id = course.id
        lesson_id = None
        title = course.title
        course_title = course.title
        protection_policy = (
            course.protection_policy.value
            if hasattr(course, "protection_policy") and course.protection_policy
            else "blockCaptureWhereSupported"
        )
        raise APIError(
            503,
            "COURSE_DOWNLOAD_PACKAGE_UNCONFIGURED",
            "No authoritative packaged course asset is configured.",
        )
    else:
        raise APIError(
            400,
            "UNSUPPORTED_RESOURCE_TYPE",
            f"Resource type {resource_type_str} is not downloadable.",
        )

    # The lease is capped at the exact entitlement expiry; it must never round
    # a short remaining period up and extend paid access.
    entitlement_expires_at = None
    if decision.get("expiresAt"):
        try:
            entitlement_expires_at = datetime.fromisoformat(
                decision["expiresAt"].replace("Z", "+00:00")
            )
        except (AttributeError, TypeError, ValueError) as error:
            raise APIError(
                503,
                "INVALID_ENTITLEMENT_EXPIRY",
                "The authoritative entitlement expiry is invalid.",
            ) from error

    token, dl_expires, lease_expires = issue_download_token(
        settings=get_settings(),
        learner_id=learner_id,
        asset_id=asset_id,
        lesson_id=lesson_id or "",
        course_id=course_id,
        offline_expires_at=entitlement_expires_at,
    )

    return {
        "resourceType": requested_type,
        "resourceId": requested_id,
        "courseId": course_id,
        "lessonId": lesson_id,
        "title": title,
        "courseTitle": course_title,
        "remoteAssetId": asset_id,
        "downloadUrl": signed_download_url(get_settings(), asset_id, token),
        "downloadToken": token,
        "expiresAt": iso(dl_expires),
        "entitlementExpiresAt": iso(lease_expires),
        "sizeBytes": size_bytes,
        "checksumSha256": checksum,
        "assetVersion": asset_version,
        "quality": quality,
        "contentType": "application/octet-stream" if requested_type in {"document", "resource"} else "video/mp4",
        "protectionPolicy": protection_policy,
        "subtitles": subtitles,
        "isDownloadable": True,
    }


@router.post("/downloads/revalidate")
async def download_revalidate(body: DownloadRevalidateIn, user: Principal, db: DB):
    results = []
    lessons = {
        lesson.id: lesson
        for lesson in (
            await db.scalars(select(Lesson).where(Lesson.id.in_(body.resource_ids)))
        ).all()
    }
    # Device records use stable asset IDs. Resolve them without academic filtering.
    media_rows = list(await db.scalars(select(MediaAsset).where(MediaAsset.asset_id.in_(body.resource_ids), MediaAsset.status == "active")))
    media_lessons = {lesson.id: lesson for lesson in await db.scalars(select(Lesson).where(Lesson.id.in_([asset.lesson_id for asset in media_rows])))}
    for asset in media_rows:
        if asset.lesson_id in media_lessons:
            lessons[asset.asset_id] = media_lessons[asset.lesson_id]
    missing_ids = [resource_id for resource_id in body.resource_ids if resource_id not in lessons]
    courses = {
        course.id: course
        for course in (await db.scalars(select(Course).where(Course.id.in_(missing_ids)))).all()
    }
    for res_id in body.resource_ids:
        lesson = lessons.get(res_id)
        if not lesson:
            course = courses.get(res_id)
            if not course:
                results.append(
                    {
                        "resourceId": res_id,
                        "status": "notFound",
                        "entitlementExpiresAt": None,
                        "assetVersion": None,
                        "message": "Resource no longer exists.",
                    }
                )
                continue
            decision = await resolve_access(db, user.id, ResourceType.course, course.id)
            ver = f"v{int(course.updated_at.timestamp()) if course.updated_at else 1}"
        else:
            decision = await resolve_access(db, user.id, ResourceType.lesson, lesson.id)
            ver = f"v{int(lesson.updated_at.timestamp()) if lesson.updated_at else 1}"

        if not decision["allowed"]:
            results.append(
                {
                    "resourceId": res_id,
                    "status": "expired" if decision.get("accessLevel") == "expired" else "revoked",
                    "entitlementExpiresAt": None,
                    "assetVersion": ver,
                    "message": decision.get("reason", "Entitlement is no longer active."),
                }
            )
        else:
            current = now()
            new_lease = current + timedelta(hours=168)
            if decision.get("expiresAt"):
                try:
                    exp_dt = datetime.fromisoformat(decision["expiresAt"].replace("Z", "+00:00"))
                    new_lease = min(new_lease, exp_dt)
                except (AttributeError, TypeError, ValueError):
                    results.append(
                        {
                            "resourceId": res_id,
                            "status": "revoked",
                            "entitlementExpiresAt": None,
                            "assetVersion": ver,
                            "message": "Authoritative entitlement expiry is invalid.",
                        }
                    )
                    continue
            results.append(
                {
                    "resourceId": res_id,
                    "status": "valid",
                    "entitlementExpiresAt": iso(new_lease),
                    "assetVersion": ver,
                    "message": "Entitlement is valid.",
                }
            )

    return {"results": results}


@router.get("/courses/{course_id}/offline-manifest")
async def course_offline_manifest(course_id: str, user: Principal, db: DB):
    course = await db.get(Course, course_id)
    if not course or course.status != Lifecycle.published:
        raise APIError(404, "NOT_FOUND", "Course not found.")
    decision = await resolve_access(db, user.id, ResourceType.course, course.id)
    if not decision["allowed"]:
        raise APIError(403, "ENTITLEMENT_REQUIRED", "Access to this course is locked.")

    modules = (
        await db.scalars(
            select(CourseModule)
            .where(CourseModule.course_id == course.id)
            .order_by(CourseModule.position)
        )
    ).all()

    module_ids = [m.id for m in modules]
    lessons_by_module: dict[str, list[Lesson]] = {m.id: [] for m in modules}
    downloadable_lesson_ids: list[str] = []

    if module_ids:
        all_lessons = (
            await db.scalars(
                select(Lesson).where(Lesson.module_id.in_(module_ids)).order_by(Lesson.position)
            )
        ).all()
        for l in all_lessons:
            lessons_by_module.setdefault(l.module_id, []).append(l)
            if l.is_downloadable:
                downloadable_lesson_ids.append(l.id)

    best_asset_by_lesson: dict[str, MediaAsset] = {}
    if downloadable_lesson_ids:
        all_assets = (
            await db.scalars(
                select(MediaAsset)
                .where(
                    MediaAsset.lesson_id.in_(downloadable_lesson_ids),
                    MediaAsset.status == "active",
                )
                .order_by(
                    (MediaAsset.kind == "download").desc(),
                    MediaAsset.created_at.desc(),
                )
            )
        ).all()
        for asset in all_assets:
            if asset.lesson_id not in best_asset_by_lesson:
                best_asset_by_lesson[asset.lesson_id] = asset

    manifest_modules = []
    total_size = 0
    total_downloadable_lessons = 0

    for m in modules:
        manifest_lessons = []
        for l in lessons_by_module.get(m.id, []):
            if l.is_downloadable:
                asset = best_asset_by_lesson.get(l.id)
                size = (
                    asset.download_size_bytes
                    if asset and asset.download_size_bytes
                    else max(1024 * 1024 * 5, l.duration_seconds * 150000)
                )
                total_size += size
                total_downloadable_lessons += 1
                manifest_lessons.append(
                    {
                        "id": l.id,
                        "title": l.title,
                        "position": l.position,
                        "contentType": l.content_type,
                        "estimatedSizeBytes": size,
                        "durationSeconds": l.duration_seconds,
                        "isDownloadable": True,
                        "protectionPolicy": (
                            l.protection_policy.value
                            if hasattr(l, "protection_policy") and l.protection_policy
                            else "blockCaptureWhereSupported"
                        ),
                    }
                )
            else:
                manifest_lessons.append(
                    {
                        "id": l.id,
                        "title": l.title,
                        "position": l.position,
                        "contentType": l.content_type,
                        "estimatedSizeBytes": 0,
                        "durationSeconds": l.duration_seconds,
                        "isDownloadable": False,
                        "protectionPolicy": "none",
                    }
                )
        manifest_modules.append(
            {
                "id": m.id,
                "title": m.title,
                "position": m.position,
                "lessons": manifest_lessons,
            }
        )

    return {
        "courseId": course.id,
        "title": course.title,
        "totalEstimatedSizeBytes": total_size,
        "totalDownloadableLessons": total_downloadable_lessons,
        "modules": manifest_modules,
    }


@router.post("/auth/register", status_code=201)
async def register(body: Register, db: DB):
    if not await platform_flag(db, "registrations_enabled", True):
        raise APIError(503, "REGISTRATIONS_DISABLED", "New registrations are temporarily disabled.")
    if await db.scalar(select(User.id).where(func.lower(User.email) == body.email.lower())):
        raise APIError(409, "CONFLICT", "An account already exists.", "email")
    u = User(
        email=body.email.lower(),
        password_hash=hash_password(body.password),
        display_name=body.display_name,
    )
    db.add(u)
    await db.flush()
    return await create_session(db, u)


@router.post("/auth/login")
async def login(body: Login, db: DB):
    u = await db.scalar(select(User).where(func.lower(User.email) == body.email.lower()))
    if not u or not verify_password(u.password_hash, body.password):
        raise APIError(401, "INVALID_CREDENTIALS", "Email or password is incorrect.")
    if not u.is_active:
        raise APIError(401, "ACCOUNT_UNAVAILABLE", "Account is unavailable.")
    return await create_session(db, u)


@router.post("/auth/refresh")
async def refresh(body: Refresh, db: DB):
    s = await db.scalar(
        select(AuthSession)
        .where(AuthSession.refresh_token_hash == token_hash(body.refresh_token))
        .with_for_update()
    )
    if not s or s.revoked_at or ensure_utc(s.expires_at) <= now():
        raise APIError(401, "SESSION_EXPIRED", "Refresh session is invalid or expired.")
    u = await db.get(User, s.user_id)
    if not u or not u.is_active:
        s.revoked_at = now()
        await db.commit()
        raise APIError(401, "ACCOUNT_UNAVAILABLE", "Account is unavailable.")
    s.revoked_at = now()
    return await create_session(db, u)


@router.get("/auth/me")
async def me(user: Principal):
    return identity(user)


@router.post("/auth/logout", status_code=204)
async def logout(body: Logout, user: Principal, db: DB):
    q = select(AuthSession).where(AuthSession.user_id == user.id)
    if not body.all_devices:
        q = q.where(AuthSession.refresh_token_hash == token_hash(body.refresh_token))
    for s in (await db.scalars(q)).all():
        s.revoked_at = now()
    await db.commit()
    return Response(status_code=204)


@router.post("/auth/onboarding")
async def onboarding(body: Onboarding, user: Principal, db: DB):
    user.display_name = body.display_name
    user.onboarding_complete = True
    await db.flush()
    return await create_session(db, user)


@router.post("/auth/delete-account", status_code=204)
async def delete_account(user: Principal, db: DB):
    raise APIError(
        410,
        "PASSWORD_CONFIRMATION_REQUIRED",
        "Use the confirmed account deletion endpoint with the current password.",
    )


@router.post("/auth/password-reset/request", status_code=202)
async def password_reset_request(body: ResetRequest, request: Request, db: DB):
    user = await db.scalar(select(User).where(func.lower(User.email) == body.email.lower()))
    if user:
        await db.execute(select(User.id).where(User.id == user.id).with_for_update())
        raw = random_token(32)
        db.add(
            PasswordResetCode(
                user_id=user.id, code_hash=token_hash(raw), expires_at=now() + timedelta(minutes=15)
            )
        )
        db.add(
            AuditEvent(
                actor_id=user.id,
                event_type="password_reset.requested",
                subject_type="user",
                subject_id=user.id,
                data={},
            )
        )
        await db.commit()
        from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit

        target = urlsplit(get_settings().password_reset_url)
        query = dict(parse_qsl(target.query))
        query.update(token=raw, email=user.email)
        reset_url = urlunsplit(target._replace(query=urlencode(query)))
        try:
            await request.app.state.password_reset_delivery.send(
                recipient=user.email, reset_url=reset_url, expires_minutes=15
            )
            request.app.state.metrics.increment("password_reset_delivery_success")
        except PasswordResetDeliveryError:
            request.app.state.metrics.increment("password_reset_delivery_failure")
    return {"accepted": True}


@router.post("/auth/password-reset/confirm")
async def password_reset_confirm(body: ResetConfirm, db: DB):
    user = await db.scalar(
        select(User).where(func.lower(User.email) == body.email.lower()).with_for_update()
    )
    code = (
        await db.scalar(
            select(PasswordResetCode)
            .where(
                PasswordResetCode.user_id == user.id,
                PasswordResetCode.code_hash == token_hash(body.verification_code),
                PasswordResetCode.consumed_at.is_(None),
            )
            .order_by(PasswordResetCode.created_at.desc())
            .limit(1)
        )
        if user
        else None
    )
    if not code or ensure_utc(code.expires_at) <= now() or not user.is_active:
        raise APIError(410, "EXPIRED_RESOURCE", "The reset code is invalid or expired.")
    for pending in (
        await db.scalars(
            select(PasswordResetCode).where(
                PasswordResetCode.user_id == user.id, PasswordResetCode.consumed_at.is_(None)
            )
        )
    ).all():
        pending.consumed_at = now()
    user.password_hash = hash_password(body.new_password)
    for session in (
        await db.scalars(select(AuthSession).where(AuthSession.user_id == user.id))
    ).all():
        session.revoked_at = now()
    db.add(
        AuditEvent(
            actor_id=user.id,
            event_type="password_reset.completed",
            subject_type="user",
            subject_id=user.id,
            data={"sessionsRevoked": True},
        )
    )
    return await create_session(db, user)


@router.get("/entitlements")
async def entitlements(user: Principal, db: DB):
    rows = (
        await db.scalars(
            select(Entitlement)
            .where(Entitlement.learner_id == user.id)
            .order_by(Entitlement.created_at.desc())
            .limit(200)
        )
    ).all()
    return {
        "items": [
            {
                "id": x.id,
                "learnerId": x.learner_id,
                "source": x.source.value,
                "status": x.status.value,
                "targetType": x.resource_type.value if x.resource_type else None,
                "targetId": x.resource_id,
                "validFrom": iso(x.starts_at),
                "validUntil": iso(x.expires_at),
                "metadata": x.metadata_json,
            }
            for x in rows
        ]
    }


@router.get("/access-decisions/{resource_type}/{resource_id}")
async def access_decision(resource_type: ResourceType, resource_id: str, user: Principal, db: DB):
    return await resolve_access(db, user.id, resource_type, resource_id)


@router.get("/assessments/{assessment_id}")
async def get_assessment(assessment_id: str, user: Principal, db: DB):
    a = await db.get(Assessment, assessment_id)
    if not a or a.status != Lifecycle.published:
        raise APIError(404, "NOT_FOUND", "Assessment not found.")
    if not (await resolve_access(db, user.id, ResourceType.assessment, a.id))["allowed"]:
        raise APIError(403, "ACCESS_DENIED", "Assessment access is not permitted.")
    return await assessment_payload(db, a)


@router.get("/assessments/{assessment_id}/attempts/summary")
async def attempt_summary(assessment_id: str, user: Principal, db: DB):
    a = await db.get(Assessment, assessment_id)
    if not a:
        raise APIError(404, "NOT_FOUND", "Assessment not found.")
    attempts = (
        await db.scalars(
            select(AssessmentAttempt)
            .where(
                AssessmentAttempt.assessment_id == a.id,
                AssessmentAttempt.learner_id == user.id,
                AssessmentAttempt.status == AttemptStatus.submitted,
            )
            .order_by(AssessmentAttempt.attempt_number)
        )
    ).all()
    vals = [
        {
            "attemptId": x.id,
            "assessmentId": a.id,
            "learnerId": user.id,
            "attemptNumber": x.attempt_number,
            "score": x.score,
            "maxScore": x.max_score,
            "percentage": float(x.percentage),
            "isPassed": x.passed,
            "startedAt": iso(x.started_at),
            "submittedAt": iso(x.submitted_at),
            "durationSeconds": int((x.submitted_at - x.started_at).total_seconds()),
        }
        for x in attempts
    ]
    return {
        "assessmentId": a.id,
        "totalAttempts": len(attempts),
        "maxAttempts": a.max_attempts,
        "remainingAttempts": max(0, a.max_attempts - len(attempts)),
        "hasPassed": any(x.passed for x in attempts),
        "highestScore": max([x.score for x in attempts] or [0]),
        "highestPercentage": max([float(x.percentage) for x in attempts] or [0.0]),
        "attempts": vals,
    }


@router.post("/assessments/{assessment_id}/attempts", status_code=201)
async def new_attempt(assessment_id: str, user: Principal, db: DB):
    a = await db.get(Assessment, assessment_id)
    if not a or a.status != Lifecycle.published:
        raise APIError(404, "NOT_FOUND", "Assessment not found.")
    x = await start_attempt(db, user.id, a)
    return {
        "attemptId": x.id,
        "assessmentId": a.id,
        "startedAt": iso(x.started_at),
        "serverNow": iso(now()),
        "expiresAt": iso(x.expires_at),
        "attemptNumber": x.attempt_number,
    }


@router.get("/assessments/{assessment_id}/attempts/{attempt_id}")
async def resume_attempt(assessment_id: str, attempt_id: str, user: Principal, db: DB):
    x = await db.get(AssessmentAttempt, attempt_id)
    if not x or x.learner_id != user.id or x.assessment_id != assessment_id:
        raise APIError(404, "NOT_FOUND", "Attempt not found.")
    if x.expires_at and x.expires_at <= now() and x.status == AttemptStatus.in_progress:
        x.status = AttemptStatus.expired
        await db.commit()
    a = await db.get(Assessment, assessment_id)
    return {
        "attemptId": x.id,
        "assessmentId": a.id,
        "startedAt": iso(x.started_at),
        "serverNow": iso(now()),
        "expiresAt": iso(x.expires_at),
        "attemptNumber": x.attempt_number,
        "status": x.status.value,
        "assessment": await assessment_payload(db, a),
    }


@router.post("/assessments/{assessment_id}/attempts/{attempt_id}/submission")
async def submit(
    assessment_id: str,
    attempt_id: str,
    body: Submission,
    user: Principal,
    db: DB,
    idempotency_key: Annotated[str | None, Header(alias="Idempotency-Key")] = None,
):
    if not idempotency_key or len(idempotency_key) > 120:
        raise APIError(400, "IDEMPOTENCY_KEY_REQUIRED", "A valid Idempotency-Key is required.")
    if body.attempt_id != attempt_id:
        raise APIError(422, "INVALID_ATTEMPT", "Body and path attempt IDs differ.")
    request = body.model_dump(by_alias=True)
    digest = fingerprint(request)
    operation = f"assessment_submission:{attempt_id}"
    record = await db.scalar(
        select(IdempotencyRecord).where(
            IdempotencyRecord.principal_id == user.id,
            IdempotencyRecord.operation == operation,
            IdempotencyRecord.key == idempotency_key,
        )
    )
    if record:
        if record.request_hash != digest:
            raise APIError(
                409, "IDEMPOTENCY_CONFLICT", "The key was used with a different request."
            )
        if record.response_json:
            return record.response_json
    else:
        record = IdempotencyRecord(
            principal_id=user.id,
            operation=operation,
            key=idempotency_key,
            request_hash=digest,
            expires_at=now() + timedelta(days=7),
        )
        db.add(record)
        try:
            await db.flush()
        except IntegrityError:
            await db.rollback()
            raise APIError(
                409, "IDEMPOTENCY_IN_PROGRESS", "An identical operation is being processed."
            )
    x = await db.scalar(
        select(AssessmentAttempt).where(AssessmentAttempt.id == attempt_id).with_for_update()
    )
    a = await db.get(Assessment, assessment_id)
    if not x or not a:
        raise APIError(404, "NOT_FOUND", "Attempt not found.")
    result = await grade_submission(
        db, user.id, a, x, [v.model_dump(by_alias=True, exclude_none=True) for v in body.answers]
    )
    record.response_json = result
    record.status_code = 200
    await db.commit()
    return result


@router.get("/certificate-eligibility/{course_id}")
async def eligibility(course_id: str, user: Principal, db: DB):
    course = await db.get(Course, course_id)
    if not course:
        raise APIError(404, "NOT_FOUND", "Course not found.")
    return await certificate_eligibility(db, user.id, course)


@router.post("/certificate-issuances", status_code=201)
async def issue(body: CertificateClaim, user: Principal, db: DB):
    if db.bind and db.bind.dialect.name == "postgresql":
        await db.execute(
            select(
                func.pg_advisory_xact_lock(
                    func.hashtextextended(f"certificate:{user.id}:{body.course_id}", 0)
                )
            )
        )
    existing = await db.scalar(
        select(Certificate).where(
            Certificate.learner_id == user.id, Certificate.course_id == body.course_id
        )
    )
    if existing:
        return certificate_json(existing, get_settings().public_base_url)
    course = await db.get(Course, body.course_id)
    if not course:
        raise APIError(404, "NOT_FOUND", "Course not found.")
    e = await certificate_eligibility(db, user.id, course)
    if e["status"] != "eligible":
        raise APIError(409, "CERTIFICATE_INELIGIBLE", "Certificate requirements are not satisfied.")
    cert = Certificate(
        learner_id=user.id,
        course_id=course.id,
        credential_id=secrets.token_urlsafe(24),
        learner_name=user.display_name,
        course_title=course.title,
        issued_at=now(),
        status=CertificateStatus.issued,
    )
    db.add(cert)
    await db.flush()
    db.add(
        AuditEvent(
            actor_id=user.id,
            event_type="certificate.issued",
            subject_type="certificate",
            subject_id=cert.id,
            data={"courseId": course.id},
        )
    )
    await db.commit()
    await db.refresh(cert)
    return certificate_json(cert, get_settings().public_base_url)


@router.get("/certificates")
async def certificates(
    user: Principal, db: DB, cursor: str | None = None, limit: int = Query(20, ge=1, le=50)
):
    q = select(Certificate).where(Certificate.learner_id == user.id)
    if cursor:
        ts, id_ = cursor_decode(cursor)
        q = q.where(
            or_(Certificate.issued_at < ts, and_(Certificate.issued_at == ts, Certificate.id < id_))
        )
    rows = (
        await db.scalars(
            q.order_by(Certificate.issued_at.desc(), Certificate.id.desc()).limit(limit + 1)
        )
    ).all()
    more = len(rows) > limit
    rows = rows[:limit]
    return {
        "items": [certificate_json(x, get_settings().public_base_url) for x in rows],
        "nextCursor": cursor_encode(rows[-1].issued_at, rows[-1].id) if more else None,
    }


@router.get("/certificates/by-course/{course_id}")
async def cert_by_course(course_id: str, user: Principal, db: DB):
    c = await db.scalar(
        select(Certificate).where(
            Certificate.learner_id == user.id, Certificate.course_id == course_id
        )
    )
    return {"certificate": certificate_json(c, get_settings().public_base_url) if c else None}


@router.get("/certificates/{certificate_id}")
async def cert_detail(certificate_id: str, user: Principal, db: DB):
    c = await db.get(Certificate, certificate_id)
    if not c or c.learner_id != user.id:
        raise APIError(404, "NOT_FOUND", "Certificate not found.")
    return certificate_json(c, get_settings().public_base_url)


@router.get("/public/credentials/{credential_id}")
async def verify(credential_id: str, db: DB):
    checked = now()
    c = await db.scalar(select(Certificate).where(Certificate.credential_id == credential_id))
    if not c:
        return {
            "credentialId": credential_id,
            "isValid": False,
            "verificationTimestamp": iso(checked),
            "certificate": None,
            "message": "Credential not found.",
        }
    rev = await db.scalar(
        select(CertificateRevocation).where(CertificateRevocation.certificate_id == c.id)
    )
    valid = (
        c.status == CertificateStatus.issued
        and not rev
        and (not c.expires_at or c.expires_at > checked)
    )
    return {
        "credentialId": credential_id,
        "isValid": valid,
        "verificationTimestamp": iso(checked),
        "certificate": certificate_json(
            c, get_settings().public_base_url, True, rev.reason if rev else None
        ),
        "message": None if valid else "Credential is not valid.",
    }


@router.post("/admin/certificates/{certificate_id}/revocation")
async def revoke(certificate_id: str, body: RevocationIn, user: AdminPrincipal, db: DB):
    c = await db.scalar(
        select(Certificate).where(Certificate.id == certificate_id).with_for_update()
    )
    if not c:
        raise APIError(404, "NOT_FOUND", "Certificate not found.")
    if c.status == CertificateStatus.revoked:
        raise APIError(409, "CONFLICT", "Certificate is already revoked.")
    c.status = CertificateStatus.revoked
    rev = CertificateRevocation(
        certificate_id=c.id, actor_id=user.id, reason=body.reason, revoked_at=now()
    )
    db.add(rev)
    db.add(
        AuditEvent(
            actor_id=user.id,
            event_type="certificate.revoked",
            subject_type="certificate",
            subject_id=c.id,
            data={"reason": body.reason},
        )
    )
    await db.commit()
    return certificate_json(c, get_settings().public_base_url, False, body.reason)


# --- Phase 7B Commerce and Subscription Routes ---


@router.get("/commerce/plans")
async def get_subscription_plans(db: DB):
    plans = (
        await db.scalars(
            select(SubscriptionPlan)
            .where(SubscriptionPlan.is_active == True)
            .order_by(SubscriptionPlan.price_cents.asc())
        )
    ).all()
    plan_ids = [p.id for p in plans]
    mapping_dict = {}
    if plan_ids:
        mappings = (
            await db.scalars(
                select(ProviderProductMapping).where(
                    ProviderProductMapping.internal_product_id.in_(plan_ids)
                )
            )
        ).all()
        mapping_dict = {m.internal_product_id: m.provider_product_id for m in mappings}

    return {"items": [plan_json(p, mapping_dict.get(p.id)) for p in plans]}


@router.get("/commerce/products/courses")
async def get_course_products(db: DB):
    courses = (
        await db.scalars(
            select(CommerceProduct)
            .where(
                CommerceProduct.is_active == True,
                CommerceProduct.product_type == CommerceProductType.course,
            )
            .order_by(CommerceProduct.created_at.asc())
        )
    ).all()
    course_ids = [c.id for c in courses]
    mapping_dict = {}
    if course_ids:
        mappings = (
            await db.scalars(
                select(ProviderProductMapping).where(
                    ProviderProductMapping.internal_product_id.in_(course_ids)
                )
            )
        ).all()
        mapping_dict = {m.internal_product_id: m.provider_product_id for m in mappings}

    return {"items": [course_product_json(c, mapping_dict.get(c.id)) for c in courses]}


@router.get("/commerce/products/bundles")
async def get_bundle_products(db: DB):
    bundles = (
        await db.scalars(
            select(CommerceProduct)
            .where(
                CommerceProduct.is_active == True,
                CommerceProduct.product_type == CommerceProductType.bundle,
            )
            .order_by(CommerceProduct.created_at.asc())
        )
    ).all()
    bundle_ids = [b.id for b in bundles]
    mapping_dict = {}
    if bundle_ids:
        mappings = (
            await db.scalars(
                select(ProviderProductMapping).where(
                    ProviderProductMapping.internal_product_id.in_(bundle_ids)
                )
            )
        ).all()
        mapping_dict = {m.internal_product_id: m.provider_product_id for m in mappings}

    return {"items": [bundle_product_json(b, mapping_dict.get(b.id)) for b in bundles]}


@router.post("/commerce/coupons/validate")
async def validate_coupon(body: CouponValidateIn, db: DB):
    coupon = await validate_coupon_logic(db, body.code, body.product_id)
    if not coupon:
        return {"valid": False}
    return coupon_json(coupon)


@router.post("/commerce/transactions/verify")
async def verify_transaction_route(
    body: TransactionVerifyIn,
    user: Principal,
    db: DB,
    idempotency_key: Annotated[str | None, Header(alias="Idempotency-Key")] = None,
):
    if not await platform_flag(db, "purchases_enabled", True) or await platform_flag(
        db, "emergency_commerce_kill_switch", False
    ):
        raise APIError(503, "PURCHASES_DISABLED", "New purchases are temporarily disabled.")
    effective_key = idempotency_key or body.idempotency_key
    digest = fingerprint(body.model_dump(by_alias=True))
    operation = f"commerce_tx_verify:{user.id}"
    record = None

    if effective_key:
        record = await db.scalar(
            select(IdempotencyRecord).where(
                IdempotencyRecord.principal_id == user.id,
                IdempotencyRecord.operation == operation,
                IdempotencyRecord.key == effective_key,
            )
        )
        if record:
            if record.request_hash != digest:
                raise APIError(
                    409,
                    "IDEMPOTENCY_CONFLICT",
                    "The idempotency key was used with a different request payload.",
                )
            if record.response_json:
                return record.response_json
            raise APIError(
                409,
                "IDEMPOTENCY_IN_PROGRESS",
                "An identical transaction verification is being processed.",
            )
        else:
            record = IdempotencyRecord(
                principal_id=user.id,
                operation=operation,
                key=effective_key,
                request_hash=digest,
                expires_at=now() + timedelta(days=7),
            )
            db.add(record)
            try:
                await db.flush()
            except IntegrityError:
                await db.rollback()
                raise APIError(
                    409,
                    "IDEMPOTENCY_IN_PROGRESS",
                    "An identical transaction verification is being processed.",
                )

    result = await verify_and_process_transaction(db, user.id, body, get_settings())
    if record:
        record.response_json = result
        record.status_code = 200
    await db.commit()
    return result


@router.post("/commerce/restore")
async def restore_purchases_route(body: RestorePurchasesIn, user: Principal, db: DB):
    if body.learner_id != user.id:
        raise APIError(403, "FORBIDDEN", "Learner ID does not match authenticated user.")
    result = await restore_learner_purchases(db, user.id, body.transactions, get_settings())
    await db.commit()
    return result


@router.get("/commerce/subscriptions/active")
async def get_active_subscription(user: Principal, db: DB):
    sub = await db.scalar(
        select(Subscription)
        .where(
            Subscription.learner_id == user.id,
            Subscription.status.in_(
                [
                    SubscriptionStatus.active,
                    SubscriptionStatus.trialing,
                    SubscriptionStatus.in_grace_period,
                    SubscriptionStatus.billing_retry,
                ]
            ),
        )
        .order_by(Subscription.created_at.desc())
    )
    return {"subscription": subscription_json(sub) if sub else None}


@router.get("/commerce/purchases")
async def get_learner_purchases(
    user: Principal,
    db: DB,
    limit: int = Query(default=50, ge=1, le=100),
    cursor: str | None = Query(default=None),
):
    query = select(Purchase).where(Purchase.learner_id == user.id)
    if cursor:
        purchased_at, purchase_id = cursor_decode(cursor)
        query = query.where(
            or_(
                Purchase.purchased_at < purchased_at,
                and_(Purchase.purchased_at == purchased_at, Purchase.id < purchase_id),
            )
        )
    items = (
        await db.scalars(
            query.order_by(Purchase.purchased_at.desc(), Purchase.id.desc()).limit(limit + 1)
        )
    ).all()
    has_more = len(items) > limit
    results = items[:limit]
    next_cursor = cursor_encode(results[-1].purchased_at, results[-1].id) if has_more else None
    return {
        "items": [purchase_json(p) for p in results],
        "nextCursor": next_cursor,
    }


@router.post("/commerce/subscriptions/{subscription_id}/cancel")
async def cancel_subscription_route(
    subscription_id: str, body: CancelSubscriptionIn, user: Principal, db: DB
):
    if body.learner_id != user.id:
        raise APIError(403, "FORBIDDEN", "Learner ID does not match authenticated user.")
    sub = await cancel_subscription_service(
        db, user.id, subscription_id, body.reason, get_settings()
    )
    return {"subscription": subscription_json(sub)}


@router.post("/commerce/subscriptions/{subscription_id}/change-plan")
async def change_subscription_plan_route(
    subscription_id: str, body: ChangeSubscriptionPlanIn, user: Principal, db: DB
):
    if body.learner_id != user.id:
        raise APIError(403, "FORBIDDEN", "Learner ID does not match authenticated user.")
    sub = await change_subscription_plan_service(
        db,
        user.id,
        subscription_id,
        body.new_plan_id,
        body.proration_mode,
        get_settings(),
    )
    return {"subscription": subscription_json(sub)}


@router.post("/commerce/webhooks/{provider}")
async def handle_commerce_webhook(provider: str, request: Request, db: DB):
    headers = dict(request.headers)
    body = await request.body()
    return await process_provider_webhook(db, provider, headers, body, get_settings())


@router.post("/admin/commerce/reconcile")
async def admin_reconcile_commerce(user: AdminPrincipal, db: DB):
    current = now()
    expired_subs = (
        await db.scalars(
            select(Subscription)
            .where(
                Subscription.status.in_(
                    [
                        SubscriptionStatus.active,
                        SubscriptionStatus.trialing,
                        SubscriptionStatus.in_grace_period,
                        SubscriptionStatus.billing_retry,
                    ]
                ),
                Subscription.current_period_end <= current,
            )
            .with_for_update()
        )
    ).all()
    count = 0
    expired_subscription_ids = [subscription.id for subscription in expired_subs]
    for s in expired_subs:
        s.status = SubscriptionStatus.expired
        count += 1
    if expired_subscription_ids:
        await db.execute(
            update(Entitlement)
            .where(Entitlement.subscription_id.in_(expired_subscription_ids))
            .values(status=EntitlementStatus.expired)
        )
    await db.commit()
    return {
        "reconciledCount": count,
        "timestamp": iso(current),
        "providerReconciliation": "blocked",
    }


# --- Phase 9 Platform Experience: Notifications, Profile, Sessions, Settings ---


def notification_json(n: Notification):
    return {
        "id": n.id,
        "type": n.type.value if hasattr(n.type, "value") else str(n.type),
        "title": n.title,
        "body": n.body,
        "destinationType": n.destination_type,
        "destinationPayload": n.destination_payload or {},
        "priority": n.priority.value if hasattr(n.priority, "value") else str(n.priority),
        "imageUrl": n.image_url,
        "metadata": n.metadata_json or {},
        "readAt": iso(n.read_at) if n.read_at else None,
        "expiresAt": iso(n.expires_at) if n.expires_at else None,
        "createdAt": iso(n.created_at),
    }


def notification_preferences_json(p: NotificationPreferences):
    return {
        "emailCourseUpdates": p.email_course_updates,
        "emailLearningReminders": p.email_learning_reminders,
        "emailMarketing": p.email_marketing,
        "emailSecurityAlerts": p.email_security_alerts,
        "pushCourseUpdates": p.push_course_updates,
        "pushLearningReminders": p.push_learning_reminders,
        "pushLiveClasses": p.push_live_classes,
        "pushAssessmentUpdates": p.push_assessment_updates,
        "pushCertificateUpdates": p.push_certificate_updates,
        "pushPaymentEvents": p.push_payment_events,
        "pushSecurityAlerts": p.push_security_alerts,
        "inAppCourseUpdates": p.in_app_course_updates,
        "inAppReminders": p.in_app_reminders,
        "inAppCertificates": p.in_app_certificates,
    }


def learner_profile_json(u: User):
    return {
        "id": u.id,
        "email": u.email,
        "displayName": u.display_name,
        "avatarUrl": u.avatar_url,
        "phone": u.phone,
        "learningInterests": u.learning_interests or [],
        "languagePreference": u.language_preference or "en",
        "memberSince": iso(u.created_at),
    }


def session_json(s: AuthSession, current_session_id: str | None = None):
    return {
        "id": s.id,
        "deviceName": s.device_name or "Unknown device",
        "platform": s.platform or "web",
        "lastActiveAt": iso(s.last_active_at or s.updated_at),
        "createdAt": iso(s.created_at),
        "isCurrent": s.id == current_session_id,
    }


def synced_settings_json(st: SyncedUserSettings):
    return {
        "themeMode": st.theme_mode,
        "language": st.language,
        "autoplayNextLesson": st.autoplay_next_lesson,
        "preferredPlaybackSpeed": float(st.preferred_playback_speed)
        if st.preferred_playback_speed
        else 1.0,
        "captionsDefaultEnabled": st.captions_default_enabled,
        "reducedMotion": st.reduced_motion,
        "highContrast": st.high_contrast,
        "downloadQuality": st.download_quality,
        "downloadWifiOnly": st.download_wifi_only,
    }


@router.get("/notifications")
async def list_notifications(
    user: Principal,
    db: DB,
    cursor: str | None = Query(default=None),
    limit: int = Query(default=20, ge=1, le=100),
    unread_only: bool = Query(default=False),
):
    query = select(Notification).where(Notification.user_id == user.id)
    if unread_only:
        query = query.where(Notification.read_at.is_(None))

    query = query.where(or_(Notification.expires_at.is_(None), Notification.expires_at > now()))

    if cursor:
        created_at, notification_id = cursor_decode(cursor)
        query = query.where(
            or_(
                Notification.created_at < created_at,
                and_(Notification.created_at == created_at, Notification.id < notification_id),
            )
        )

    query = query.order_by(Notification.created_at.desc(), Notification.id.desc())

    unread_count = (
        await db.scalar(
            select(func.count())
            .select_from(Notification)
            .where(
                Notification.user_id == user.id,
                Notification.read_at.is_(None),
                or_(Notification.expires_at.is_(None), Notification.expires_at > now()),
            )
        )
        or 0
    )

    items = (await db.scalars(query.limit(limit + 1))).all()

    has_more = len(items) > limit
    results = items[:limit]
    next_cursor = cursor_encode(results[-1].created_at, results[-1].id) if has_more else None

    return {
        "items": [notification_json(n) for n in results],
        "unreadCount": unread_count,
        "nextCursor": next_cursor,
    }


@router.post("/notifications/{notification_id}/read")
async def mark_notification_read(notification_id: str, user: Principal, db: DB):
    notification = await db.scalar(
        select(Notification).where(
            Notification.id == notification_id,
            Notification.user_id == user.id,
        )
    )
    if not notification:
        raise APIError(404, "NOT_FOUND", "Notification not found.")

    if notification.read_at is None:
        notification.read_at = now()
        await db.commit()

    return {"notification": notification_json(notification)}


@router.post("/notifications/read-all")
async def mark_all_notifications_read(user: Principal, db: DB):
    current = now()
    res = await db.execute(
        update(Notification)
        .where(
            Notification.user_id == user.id,
            Notification.read_at.is_(None),
        )
        .values(read_at=current)
    )
    await db.commit()
    return {"markedCount": res.rowcount or 0}


@router.get("/notifications/preferences")
async def get_notification_preferences(user: Principal, db: DB):
    await db.execute(select(User.id).where(User.id == user.id).with_for_update())
    prefs = await db.scalar(
        select(NotificationPreferences).where(NotificationPreferences.user_id == user.id)
    )
    if not prefs:
        prefs = NotificationPreferences(user_id=user.id)
        db.add(prefs)
        await db.commit()
        await db.refresh(prefs)
    return {"preferences": notification_preferences_json(prefs)}


@router.put("/notifications/preferences")
async def update_notification_preferences(body: NotificationPreferencesIn, user: Principal, db: DB):
    await db.execute(select(User.id).where(User.id == user.id).with_for_update())
    prefs = await db.scalar(
        select(NotificationPreferences).where(NotificationPreferences.user_id == user.id)
    )
    if not prefs:
        prefs = NotificationPreferences(user_id=user.id)
        db.add(prefs)

    prefs.email_course_updates = body.email_course_updates
    prefs.email_learning_reminders = body.email_learning_reminders
    prefs.email_marketing = body.email_marketing
    prefs.push_course_updates = body.push_course_updates
    prefs.push_learning_reminders = body.push_learning_reminders
    prefs.push_live_classes = body.push_live_classes
    prefs.push_assessment_updates = body.push_assessment_updates
    prefs.push_certificate_updates = body.push_certificate_updates
    prefs.push_payment_events = body.push_payment_events
    prefs.in_app_course_updates = body.in_app_course_updates
    prefs.in_app_reminders = body.in_app_reminders
    prefs.in_app_certificates = body.in_app_certificates

    await db.commit()
    await db.refresh(prefs)
    return {"preferences": notification_preferences_json(prefs)}


@router.post("/notifications/push-tokens")
async def register_push_token(body: PushTokenRegisterIn, user: Principal, db: DB):
    bind = db.get_bind()
    if bind.dialect.name == "postgresql":
        lock_key = int.from_bytes(
            hashlib.sha256(body.token.encode()).digest()[:8], "big", signed=True
        )
        await db.execute(select(func.pg_advisory_xact_lock(lock_key)))
    existing = await db.scalar(
        select(PushDeviceToken).where(PushDeviceToken.token == body.token).with_for_update()
    )
    if existing:
        if existing.user_id != user.id:
            raise APIError(
                409,
                "PUSH_TOKEN_OWNERSHIP_CONFLICT",
                "This push token is already registered to another account.",
            )
        existing.platform = body.platform
        existing.device_name = body.device_name
        existing.is_active = True
        existing.updated_at = now()
    else:
        db.add(
            PushDeviceToken(
                user_id=user.id,
                token=body.token,
                platform=body.platform,
                device_name=body.device_name,
                is_active=True,
            )
        )
    await db.commit()
    return {"success": True, "token": body.token}


@router.delete("/notifications/push-tokens/{token}")
async def revoke_push_token(token: str, user: Principal, db: DB):
    device_token = await db.scalar(
        select(PushDeviceToken).where(
            PushDeviceToken.token == token,
            PushDeviceToken.user_id == user.id,
        )
    )
    if device_token:
        device_token.is_active = False
        await db.commit()
    return Response(status_code=204)


@router.get("/profile")
async def get_learner_profile(user: Principal, db: DB):
    u = await db.get(User, user.id)
    if not u:
        raise APIError(404, "USER_NOT_FOUND", "User profile not found.")
    return {"profile": learner_profile_json(u)}


@router.put("/profile")
async def update_learner_profile(body: LearnerProfileUpdateIn, user: Principal, db: DB):
    u = await db.get(User, user.id)
    if not u:
        raise APIError(404, "USER_NOT_FOUND", "User profile not found.")

    if body.display_name is not None:
        u.display_name = body.display_name.strip()
    if body.phone is not None:
        u.phone = body.phone.strip()
    if body.learning_interests is not None:
        u.learning_interests = body.learning_interests
    if body.language_preference is not None:
        u.language_preference = body.language_preference
    if body.avatar_url is not None and get_settings().environment in {"staging", "production"}:
        raise APIError(
            503,
            "AVATAR_STORAGE_UNCONFIGURED",
            "Authoritative avatar storage is not configured.",
        )
    if body.avatar_url is not None:
        u.avatar_url = body.avatar_url

    u.updated_at = now()
    await db.commit()
    await db.refresh(u)
    return {"profile": learner_profile_json(u)}


@router.post("/profile/avatar/upload-url")
async def get_avatar_upload_intent(user: Principal):
    if get_settings().environment in {"staging", "production"}:
        raise APIError(
            503,
            "AVATAR_STORAGE_UNCONFIGURED",
            "Authoritative avatar storage is not configured.",
        )
    upload_id = secrets.token_urlsafe(16)
    return {
        "uploadUrl": f"https://storage.learningplatform.internal/avatars/upload/{user.id}/{upload_id}",
        "publicUrl": f"https://storage.learningplatform.internal/avatars/{user.id}/{upload_id}.png",
        "expiresInSeconds": 300,
        "maxBytes": 5 * 1024 * 1024,
        "allowedContentTypes": ["image/jpeg", "image/png", "image/webp"],
    }


@router.post("/profile/avatar")
async def update_avatar_url(body: AvatarUpdateIn, user: Principal, db: DB):
    if get_settings().environment in {"staging", "production"}:
        raise APIError(
            503,
            "AVATAR_STORAGE_UNCONFIGURED",
            "Authoritative avatar storage is not configured.",
        )
    u = await db.get(User, user.id)
    if not u:
        raise APIError(404, "USER_NOT_FOUND", "User not found.")
    u.avatar_url = body.avatar_url
    u.updated_at = now()
    await db.commit()
    return {"avatarUrl": u.avatar_url}


@router.post("/account/password-change")
async def change_account_password(body: PasswordChangeIn, user: Principal, db: DB):
    u = await db.get(User, user.id)
    if not u or not verify_password(u.password_hash, body.current_password):
        raise APIError(
            400, "INVALID_CURRENT_PASSWORD", "The current password provided is incorrect."
        )

    u.password_hash = hash_password(body.new_password)
    u.updated_at = now()

    current_sid = getattr(user, "current_session_id", None)
    other_sessions = (
        await db.scalars(
            select(AuthSession).where(
                AuthSession.user_id == user.id,
                AuthSession.revoked_at.is_(None),
                AuthSession.id != current_sid,
            )
        )
    ).all()
    current_time = now()
    for s in other_sessions:
        s.revoked_at = current_time

    await db.commit()
    return {"success": True, "message": "Password changed successfully. Other sessions revoked."}


@router.get("/account/sessions")
async def list_active_sessions(user: Principal, db: DB):
    current_sid = getattr(user, "current_session_id", None)
    sessions = (
        await db.scalars(
            select(AuthSession)
            .where(
                AuthSession.user_id == user.id,
                AuthSession.revoked_at.is_(None),
                AuthSession.expires_at > now(),
            )
            .order_by(AuthSession.created_at.desc())
        )
    ).all()
    return {"sessions": [session_json(s, current_sid) for s in sessions]}


@router.post("/account/sessions/{session_id}/revoke")
async def revoke_session_route(session_id: str, user: Principal, db: DB):
    session = await db.scalar(
        select(AuthSession).where(
            AuthSession.id == session_id,
            AuthSession.user_id == user.id,
        )
    )
    if not session:
        raise APIError(404, "SESSION_NOT_FOUND", "Session not found.")

    session.revoked_at = now()
    await db.commit()
    return {"success": True, "sessionId": session_id}


@router.post("/account/sessions/revoke-others")
async def revoke_other_sessions_route(user: Principal, db: DB):
    current_sid = getattr(user, "current_session_id", None)
    sessions = (
        await db.scalars(
            select(AuthSession).where(
                AuthSession.user_id == user.id,
                AuthSession.revoked_at.is_(None),
                AuthSession.id != current_sid,
            )
        )
    ).all()

    current_time = now()
    count = 0
    for s in sessions:
        s.revoked_at = current_time
        count += 1

    await db.commit()
    return {"revokedCount": count}


@router.post("/account/delete")
async def delete_account_route(body: AccountDeleteIn, user: Principal, db: DB):
    if body.confirmation_text.strip() != "DELETE":
        raise APIError(
            400, "INVALID_CONFIRMATION", "Please enter DELETE to confirm account deletion."
        )

    u = await db.get(User, user.id)
    if not u or not verify_password(u.password_hash, body.password):
        raise APIError(400, "INVALID_PASSWORD", "Invalid password provided.")

    sessions = (await db.scalars(select(AuthSession).where(AuthSession.user_id == user.id))).all()
    for s in sessions:
        s.revoked_at = now()

    deletion_time = now()
    u.is_active = False
    u.email = f"deleted-{u.id}@invalid.local"
    u.password_hash = hash_password(secrets.token_urlsafe(32))
    u.display_name = "Deleted user"
    u.phone = None
    u.avatar_url = None
    u.learning_interests = []
    u.updated_at = deletion_time
    await db.commit()
    return {"success": True, "message": "Account successfully deactivated and anonymized."}


@router.get("/settings")
async def get_user_settings(user: Principal, db: DB):
    await db.execute(select(User.id).where(User.id == user.id).with_for_update())
    st = await db.scalar(select(SyncedUserSettings).where(SyncedUserSettings.user_id == user.id))
    if not st:
        st = SyncedUserSettings(user_id=user.id)
        db.add(st)
        await db.commit()
        await db.refresh(st)
    return {"settings": synced_settings_json(st)}


@router.put("/settings")
async def update_user_settings(body: SyncedUserSettingsIn, user: Principal, db: DB):
    await db.execute(select(User.id).where(User.id == user.id).with_for_update())
    st = await db.scalar(select(SyncedUserSettings).where(SyncedUserSettings.user_id == user.id))
    if not st:
        st = SyncedUserSettings(user_id=user.id)
        db.add(st)

    if body.theme_mode is not None:
        st.theme_mode = body.theme_mode
    if body.language is not None:
        st.language = body.language
    if body.autoplay_next_lesson is not None:
        st.autoplay_next_lesson = body.autoplay_next_lesson
    if body.preferred_playback_speed is not None:
        st.preferred_playback_speed = body.preferred_playback_speed
    if body.captions_default_enabled is not None:
        st.captions_default_enabled = body.captions_default_enabled
    if body.reduced_motion is not None:
        st.reduced_motion = body.reduced_motion
    if body.high_contrast is not None:
        st.high_contrast = body.high_contrast
    if body.download_quality is not None:
        st.download_quality = body.download_quality
    if body.download_wifi_only is not None:
        st.download_wifi_only = body.download_wifi_only

    st.updated_at = now()
    await db.commit()
    await db.refresh(st)
    return {"settings": synced_settings_json(st)}


# --- CMS Phase 1 Admin Endpoints ---


@router.get("/admin/dashboard", response_model=CmsDashboardOut)
async def admin_dashboard(user: CmsPrincipal, db: DB):
    return await get_cms_dashboard_data(db)


@router.get("/admin/courses", response_model=CmsCourseListOut)
async def admin_courses(
    user: CmsPrincipal,
    db: DB,
    curriculum_id: str | None = Query(None, alias="curriculumId"),
    standard_id: str | None = Query(None, alias="standardId"),
    stream_id: str | None = Query(None, alias="streamId"),
    subject_id: str | None = Query(None, alias="subjectId"),
    status: str | None = None,
    search: str = "",
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100, alias="pageSize"),
):
    q = select(Course)
    for column, value in [(Course.curriculum_id, curriculum_id), (Course.standard_id, standard_id), (Course.stream_id, stream_id), (Course.subject_id, subject_id)]:
        if value:
            q = q.where(column == value)
    if status:
        try:
            status_enum = Lifecycle(status)
            q = q.where(Course.status == status_enum)
        except ValueError:
            pass
    if search:
        q = q.where(
            or_(
                Course.title.ilike(f"%{search.strip()}%"),
                Course.subtitle.ilike(f"%{search.strip()}%"),
            )
        )

    total = (await db.scalar(select(func.count()).select_from(q.subquery()))) or 0
    courses_rows = (
        await db.scalars(
            q.order_by(Course.created_at.desc()).offset((page - 1) * page_size).limit(page_size)
        )
    ).all()

    course_ids = [c.id for c in courses_rows]
    module_counts = {}
    lesson_counts = {}
    enrollment_counts = {}
    if course_ids:
        module_counts = dict(
            (
                await db.execute(
                    select(CourseModule.course_id, func.count(CourseModule.id))
                    .where(CourseModule.course_id.in_(course_ids))
                    .group_by(CourseModule.course_id)
                )
            ).all()
        )
        lesson_counts = dict(
            (
                await db.execute(
                    select(CourseModule.course_id, func.count(Lesson.id))
                    .join(Lesson, Lesson.module_id == CourseModule.id)
                    .where(CourseModule.course_id.in_(course_ids))
                    .group_by(CourseModule.course_id)
                )
            ).all()
        )
        enrollment_counts = dict(
            (
                await db.execute(
                    select(Enrollment.course_id, func.count(Enrollment.id))
                    .where(Enrollment.course_id.in_(course_ids))
                    .group_by(Enrollment.course_id)
                )
            ).all()
        )

    items = [
        {
            **classification_json(c),
            "id": c.id,
            "title": c.title,
            "subtitle": c.subtitle,
        "coverReference": c.cover_reference,
            "level": c.level,
            "policyKind": c.policy_kind.value,
            "status": c.status.value,
            "moduleCount": module_counts.get(c.id, 0),
            "lessonCount": lesson_counts.get(c.id, 0),
            "enrollmentCount": enrollment_counts.get(c.id, 0),
            "durationSeconds": c.duration_seconds,
            "createdAt": iso(c.created_at),
            "publishedAt": iso(c.published_at),
        }
        for c in courses_rows
    ]
    return {"items": items, "total": total}


@router.post("/admin/courses/{course_id}/status", response_model=CmsCourseSummaryOut)
async def admin_update_course_status(
    course_id: str,
    body: CmsCourseStatusUpdateIn,
    user: ContentManagerPrincipal,
    db: DB,
):
    c = await db.scalar(select(Course).where(Course.id == course_id).with_for_update())
    if not c:
        raise APIError(404, "NOT_FOUND", "Course not found.")

    old_status = c.status.value
    target_status = Lifecycle(body.status)
    c.status = target_status
    if target_status == Lifecycle.published and not c.published_at:
        c.published_at = now()
    c.updated_at = now()

    log_audit_event(
        db,
        actor_id=user.id,
        action="course.status_updated",
        target_entity="course",
        target_id=c.id,
        result="success",
        metadata={
            "previousStatus": old_status,
            "newStatus": target_status.value,
            "courseTitle": c.title,
        },
        reason=body.reason,
    )
    await db.commit()
    await db.refresh(c)

    mod_count = (
        await db.scalar(select(func.count(CourseModule.id)).where(CourseModule.course_id == c.id))
    ) or 0
    lesson_count = (
        await db.scalar(
            select(func.count(Lesson.id))
            .join(CourseModule, Lesson.module_id == CourseModule.id)
            .where(CourseModule.course_id == c.id)
        )
    ) or 0
    enroll_count = (
        await db.scalar(select(func.count(Enrollment.id)).where(Enrollment.course_id == c.id))
    ) or 0

    return {
        "id": c.id,
        "title": c.title,
        "subtitle": c.subtitle,
        "coverReference": c.cover_reference,
        "level": c.level,
        "policyKind": c.policy_kind.value,
        "status": c.status.value,
        "moduleCount": mod_count,
        **classification_json(c),
        "lessonCount": lesson_count,
        "enrollmentCount": enroll_count,
        "durationSeconds": c.duration_seconds,
        "createdAt": iso(c.created_at),
        "publishedAt": iso(c.published_at),
    }


@router.get("/admin/users", response_model=CmsUserListOut)
async def admin_users(
    user: SupportPrincipal,
    db: DB,
    role: str | None = None,
    search: str = "",
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100, alias="pageSize"),
):
    q = select(User)
    if role:
        try:
            role_enum = UserRole(role)
            q = q.where(User.role == role_enum)
        except ValueError:
            pass
    if search:
        q = q.where(
            or_(
                User.email.ilike(f"%{search.strip()}%"),
                User.display_name.ilike(f"%{search.strip()}%"),
            )
        )

    total = (await db.scalar(select(func.count()).select_from(q.subquery()))) or 0
    users_rows = (
        await db.scalars(
            q.order_by(User.created_at.desc()).offset((page - 1) * page_size).limit(page_size)
        )
    ).all()

    user_ids = [u.id for u in users_rows]
    enrollment_counts = {}
    if user_ids:
        enrollment_counts = dict(
            (
                await db.execute(
                    select(Enrollment.learner_id, func.count(Enrollment.id))
                    .where(Enrollment.learner_id.in_(user_ids))
                    .group_by(Enrollment.learner_id)
                )
            ).all()
        )

    items = [
        {
            "id": u.id,
            "email": u.email,
            "displayName": u.display_name,
            "role": u.role.value if hasattr(u.role, "value") else str(u.role),
            "isActive": u.is_active,
            "onboardingComplete": u.onboarding_complete,
            "enrollmentCount": enrollment_counts.get(u.id, 0),
            "createdAt": iso(u.created_at),
        }
        for u in users_rows
    ]
    return {"items": items, "total": total}


@router.get("/admin/audit-logs", response_model=CmsAuditLogListOut)
async def admin_audit_logs(
    user: SupportPrincipal,
    db: DB,
    event_type: str | None = Query(None, alias="eventType"),
    subject_type: str | None = Query(None, alias="subjectType"),
    subject_id: str | None = Query(None, alias="subjectId"),
    actor_id: str | None = Query(None, alias="actorId"),
    actor_role: str | None = Query(None, alias="actorRole"),
    result: str | None = None,
    date_from: Annotated[datetime | None, Query(alias="dateFrom")] = None,
    date_to: Annotated[datetime | None, Query(alias="dateTo")] = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100, alias="pageSize"),
):
    q = select(AuditEvent, User.email, User.display_name).outerjoin(
        User, AuditEvent.actor_id == User.id
    )
    if event_type:
        q = q.where(AuditEvent.event_type.ilike(f"%{event_type.strip()}%"))
    if subject_type:
        q = q.where(AuditEvent.subject_type == subject_type.strip())
    if subject_id:
        q = q.where(AuditEvent.subject_id == subject_id.strip())
    if actor_id:
        q = q.where(AuditEvent.actor_id == actor_id.strip())
    if actor_role:
        try:
            q = q.where(User.role == UserRole(actor_role))
        except ValueError:
            raise APIError(422, "INVALID_ROLE", "Actor role filter is invalid.")
    if result:
        q = q.where(AuditEvent.data["result"].as_string() == result)
    if date_from:
        q = q.where(AuditEvent.occurred_at >= date_from)
    if date_to:
        q = q.where(AuditEvent.occurred_at <= date_to)

    total = (await db.scalar(select(func.count()).select_from(q.subquery()))) or 0
    rows = (
        await db.execute(
            q.order_by(AuditEvent.occurred_at.desc())
            .offset((page - 1) * page_size)
            .limit(page_size)
        )
    ).all()

    items = [
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
            "data": (e.data or {}).get("metadata", {}),
        }
        for e, u_email, u_name in rows
    ]
    return {"items": items, "total": total, "page": page, "pageSize": page_size}


# --- CMS Phase 2: Category, Course, Curriculum & Assessment Endpoints ---


@router.get("/admin/categories", response_model=list[CmsCategoryOut])
async def admin_categories(user: CmsPrincipal, db: DB):
    rows = (await db.scalars(select(Category).order_by(Category.name))).all()
    return [{"id": c.id, "name": c.name, "iconName": c.icon_name} for c in rows]


@router.post("/admin/categories", response_model=CmsCategoryOut, status_code=201)
async def admin_create_category(
    body: CmsCategoryCreateIn,
    user: ContentManagerPrincipal,
    db: DB,
):
    existing = await db.scalar(select(Category).where(Category.name.ilike(body.name.strip())))
    if existing:
        raise APIError(409, "CATEGORY_EXISTS", f"Category '{body.name}' already exists.")

    cat = Category(name=body.name.strip(), icon_name=body.icon_name.strip())
    db.add(cat)
    await db.flush()

    log_audit_event(
        db,
        actor_id=user.id,
        action="category.created",
        target_entity="category",
        target_id=cat.id,
        result="success",
        metadata={"categoryName": cat.name},
    )
    await db.commit()
    await db.refresh(cat)
    return {"id": cat.id, "name": cat.name, "iconName": cat.icon_name}


@router.post("/admin/courses", response_model=CmsCourseDetailOut, status_code=201)
async def admin_create_course(
    body: CmsCourseCreateIn,
    user: ContentManagerPrincipal,
    db: DB,
):
    await validate_selection(db, body.curriculum_id, body.standard_id, body.stream_id, subject_id=body.subject_id, allow_empty=True)
    course = Course(
        curriculum_id=body.curriculum_id, standard_id=body.standard_id,
        stream_id=body.stream_id, subject_id=body.subject_id,
        title=body.title.strip(),
        subtitle=body.subtitle.strip(),
        description=body.description.strip(),
        level=body.level,
        language_code=body.language_code,
        policy_kind=PolicyKind(body.policy_kind),
        protection_policy=ContentProtectionPolicy(body.protection_policy),
        required_tier=body.required_tier,
        status=Lifecycle.draft,
        duration_seconds=0,
        learning_outcomes=body.learning_outcomes,
        prerequisites=body.prerequisites,
    )
    db.add(course)
    await db.flush()

    # Assign categories
    for cat_id in body.category_ids:
        cat = await db.get(Category, cat_id)
        if cat:
            db.add(CourseCategory(course_id=course.id, category_id=cat.id))

    # Assign tags
    for tag_name in body.tags:
        cleaned_tag = tag_name.strip()
        if cleaned_tag:
            tag = await db.scalar(select(Tag).where(Tag.name == cleaned_tag))
            if not tag:
                tag = Tag(name=cleaned_tag)
                db.add(tag)
                await db.flush()
            db.add(CourseTag(course_id=course.id, tag_id=tag.id))

    log_audit_event(
        db,
        actor_id=user.id,
        action="course.created",
        target_entity="course",
        target_id=course.id,
        result="success",
        metadata={"title": course.title, "policyKind": course.policy_kind.value},
    )
    await db.commit()
    return await get_cms_course_detail(db, course.id)


@router.get("/admin/courses/{course_id}", response_model=CmsCourseDetailOut)
async def admin_get_course_detail(course_id: str, user: CmsPrincipal, db: DB):
    return await get_cms_course_detail(db, course_id)


@router.put("/admin/courses/{course_id}", response_model=CmsCourseDetailOut)
async def admin_update_course(
    course_id: str,
    body: CmsCourseUpdateIn,
    user: ContentManagerPrincipal,
    db: DB,
):
    course = await db.scalar(select(Course).where(Course.id == course_id).with_for_update())
    if not course:
        raise APIError(404, "NOT_FOUND", "Course not found.")

    academic_fields = {"curriculum_id", "standard_id", "stream_id", "subject_id"}
    if academic_fields & body.model_fields_set:
        values = {key: getattr(body, key) if key in body.model_fields_set else getattr(course, key) for key in academic_fields}
        await validate_selection(db, values["curriculum_id"], values["standard_id"], values["stream_id"], subject_id=values["subject_id"], allow_empty=True)
        for key, value in values.items():
            setattr(course, key, value)

    if body.title is not None:
        course.title = body.title.strip()
    if body.subtitle is not None:
        course.subtitle = body.subtitle.strip()
    if body.description is not None:
        course.description = body.description.strip()
    if body.level is not None:
        course.level = body.level
    if body.language_code is not None:
        course.language_code = body.language_code
    if body.policy_kind is not None:
        course.policy_kind = PolicyKind(body.policy_kind)
    if body.protection_policy is not None:
        course.protection_policy = ContentProtectionPolicy(body.protection_policy)
    if body.required_tier is not None:
        course.required_tier = body.required_tier
    if body.learning_outcomes is not None:
        course.learning_outcomes = body.learning_outcomes
    if body.prerequisites is not None:
        course.prerequisites = body.prerequisites

    if body.category_ids is not None:
        # Replace categories
        current_cats = (
            await db.scalars(select(CourseCategory).where(CourseCategory.course_id == course.id))
        ).all()
        for cc in current_cats:
            await db.delete(cc)
        for cat_id in body.category_ids:
            cat = await db.get(Category, cat_id)
            if cat:
                db.add(CourseCategory(course_id=course.id, category_id=cat.id))

    if body.tags is not None:
        # Replace tags
        current_tags = (
            await db.scalars(select(CourseTag).where(CourseTag.course_id == course.id))
        ).all()
        for ct in current_tags:
            await db.delete(ct)
        for tag_name in body.tags:
            cleaned = tag_name.strip()
            if cleaned:
                tag = await db.scalar(select(Tag).where(Tag.name == cleaned))
                if not tag:
                    tag = Tag(name=cleaned)
                    db.add(tag)
                    await db.flush()
                db.add(CourseTag(course_id=course.id, tag_id=tag.id))

    course.updated_at = now()

    log_audit_event(
        db,
        actor_id=user.id,
        action="course.updated",
        target_entity="course",
        target_id=course.id,
        result="success",
        metadata={"title": course.title},
    )
    await db.commit()
    return await get_cms_course_detail(db, course.id)


@router.delete("/admin/courses/{course_id}", status_code=204)
async def admin_delete_course(
    course_id: str,
    user: ContentManagerPrincipal,
    db: DB,
    reason: str | None = Query(None),
):
    await guard_course_history(db, course_id)
    course = await db.scalar(select(Course).where(Course.id == course_id).with_for_update())
    if not course:
        raise APIError(404, "NOT_FOUND", "Course not found.")

    # Prevent deleting published course with active enrollments without archiving first
    if course.status == Lifecycle.published:
        enrollment_count = (
            await db.scalar(
                select(func.count(Enrollment.id)).where(
                    Enrollment.course_id == course.id, Enrollment.status == "active"
                )
            )
        ) or 0
        if enrollment_count > 0:
            raise APIError(
                409,
                "COURSE_HAS_ACTIVE_ENROLLMENTS",
                f"Course has {enrollment_count} active enrollments. Unpublish or archive it before deletion.",
            )

    course_title = course.title
    await db.delete(course)

    log_audit_event(
        db,
        actor_id=user.id,
        action="course.deleted",
        target_entity="course",
        target_id=course_id,
        result="success",
        metadata={"title": course_title},
        reason=reason,
    )
    await db.commit()
    return Response(status_code=204)


@router.get("/admin/courses/{course_id}/validate", response_model=CmsCourseValidationOut)
async def admin_validate_course(course_id: str, user: CmsPrincipal, db: DB):
    return await validate_course_for_publishing(db, course_id)


@router.post("/admin/courses/{course_id}/publish", response_model=CmsCourseDetailOut)
async def admin_publish_course_endpoint(
    course_id: str,
    body: CmsPublishCourseIn,
    user: ContentManagerPrincipal,
    db: DB,
):
    if not await platform_flag(db, "course_publishing_enabled", True):
        raise APIError(503, "PUBLISHING_DISABLED", "Course publishing is temporarily disabled.")
    course = await db.scalar(select(Course).where(Course.id == course_id).with_for_update())
    if not course:
        raise APIError(404, "NOT_FOUND", "Course not found.")

    validation = await validate_course_for_publishing(db, course.id)
    if not validation["canPublish"]:
        error_msgs = [e["message"] for e in validation["errors"]]
        raise APIError(
            422,
            "COURSE_VALIDATION_FAILED",
            f"Cannot publish course due to validation failures: {'; '.join(error_msgs)}",
        )

    # Recalculate duration
    lessons = (
        await db.scalars(
            select(Lesson)
            .join(CourseModule, Lesson.module_id == CourseModule.id)
            .where(CourseModule.course_id == course.id)
        )
    ).all()
    course.duration_seconds = sum(l.duration_seconds for l in lessons)

    old_status = course.status.value
    course.status = Lifecycle.published
    if not course.published_at:
        course.published_at = now()
    course.updated_at = now()

    log_audit_event(
        db,
        actor_id=user.id,
        action="course.published",
        target_entity="course",
        target_id=course.id,
        result="success",
        metadata={
            "previousStatus": old_status,
            "title": course.title,
            "durationSeconds": course.duration_seconds,
        },
        reason=body.reason,
    )
    await db.commit()
    return await get_cms_course_detail(db, course.id)


@router.post("/admin/courses/{course_id}/unpublish", response_model=CmsCourseDetailOut)
async def admin_unpublish_course_endpoint(
    course_id: str,
    body: CmsPublishCourseIn,
    user: ContentManagerPrincipal,
    db: DB,
):
    course = await db.scalar(select(Course).where(Course.id == course_id).with_for_update())
    if not course:
        raise APIError(404, "NOT_FOUND", "Course not found.")

    old_status = course.status.value
    course.status = Lifecycle.draft
    course.updated_at = now()

    log_audit_event(
        db,
        actor_id=user.id,
        action="course.unpublished",
        target_entity="course",
        target_id=course.id,
        result="success",
        metadata={"previousStatus": old_status, "title": course.title},
        reason=body.reason,
    )
    await db.commit()
    return await get_cms_course_detail(db, course.id)


# --- Section / Module Management Endpoints ---


@router.post(
    "/admin/courses/{course_id}/modules", response_model=CmsModuleDetailOut, status_code=201
)
async def admin_create_module(
    course_id: str,
    body: CmsModuleCreateIn,
    user: ContentManagerPrincipal,
    db: DB,
):
    course = await db.get(Course, course_id)
    if not course:
        raise APIError(404, "NOT_FOUND", "Course not found.")

    max_pos = (
        await db.scalar(
            select(func.max(CourseModule.position)).where(CourseModule.course_id == course.id)
        )
    ) or 0

    module = CourseModule(
        course_id=course.id,
        title=body.title.strip(),
        position=max_pos + 1,
        policy_kind=PolicyKind(body.policy_kind),
    )
    db.add(module)
    await db.flush()

    log_audit_event(
        db,
        actor_id=user.id,
        action="module.created",
        target_entity="module",
        target_id=module.id,
        result="success",
        metadata={"courseId": course.id, "title": module.title, "position": module.position},
    )
    await db.commit()
    await db.refresh(module)

    return {
        "id": module.id,
        "courseId": module.course_id,
        "title": module.title,
        "position": module.position,
        "policyKind": module.policy_kind.value
        if hasattr(module.policy_kind, "value")
        else str(module.policy_kind),
        "lessons": [],
        "createdAt": iso(module.created_at),
        "updatedAt": iso(module.updated_at),
    }


@router.put("/admin/courses/{course_id}/modules/{module_id}", response_model=CmsModuleDetailOut)
async def admin_update_module(
    course_id: str,
    module_id: str,
    body: CmsModuleUpdateIn,
    user: ContentManagerPrincipal,
    db: DB,
):
    module = await db.scalar(
        select(CourseModule)
        .where(CourseModule.id == module_id, CourseModule.course_id == course_id)
        .with_for_update()
    )
    if not module:
        raise APIError(404, "NOT_FOUND", "Module not found.")

    if body.title is not None:
        module.title = body.title.strip()
    if body.policy_kind is not None:
        module.policy_kind = PolicyKind(body.policy_kind)
    module.updated_at = now()

    log_audit_event(
        db,
        actor_id=user.id,
        action="module.updated",
        target_entity="module",
        target_id=module.id,
        result="success",
        metadata={"courseId": course_id, "title": module.title},
    )
    await db.commit()
    await db.refresh(module)

    lessons = (
        await db.scalars(
            select(Lesson).where(Lesson.module_id == module.id).order_by(Lesson.position)
        )
    ).all()

    return {
        "id": module.id,
        "courseId": module.course_id,
        "title": module.title,
        "position": module.position,
        "policyKind": module.policy_kind.value
        if hasattr(module.policy_kind, "value")
        else str(module.policy_kind),
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
            for l in lessons
        ],
        "createdAt": iso(module.created_at),
        "updatedAt": iso(module.updated_at),
    }


@router.delete("/admin/courses/{course_id}/modules/{module_id}", status_code=204)
async def admin_delete_module(
    course_id: str,
    module_id: str,
    user: ContentManagerPrincipal,
    db: DB,
):
    await guard_course_history(db, course_id)
    module = await db.scalar(
        select(CourseModule)
        .where(CourseModule.id == module_id, CourseModule.course_id == course_id)
        .with_for_update()
    )
    if not module:
        raise APIError(404, "NOT_FOUND", "Module not found.")

    deleted_title = module.title
    await db.delete(module)
    await db.flush()

    # Reindex remaining module positions
    remaining_modules = (
        await db.scalars(
            select(CourseModule)
            .where(CourseModule.course_id == course_id)
            .order_by(CourseModule.position)
        )
    ).all()
    for idx, m in enumerate(remaining_modules):
        m.position = idx + 1

    log_audit_event(
        db,
        actor_id=user.id,
        action="module.deleted",
        target_entity="module",
        target_id=module_id,
        result="success",
        metadata={"courseId": course_id, "title": deleted_title},
    )
    await db.commit()
    return Response(status_code=204)


@router.post("/admin/courses/{course_id}/modules/reorder", response_model=list[CmsModuleDetailOut])
async def admin_reorder_modules(
    course_id: str,
    body: CmsReorderModulesIn,
    user: ContentManagerPrincipal,
    db: DB,
):
    modules = (
        await db.scalars(
            select(CourseModule).where(CourseModule.course_id == course_id).with_for_update()
        )
    ).all()
    by_id = {m.id: m for m in modules}

    # Assign temporary negative positions to avoid unique constraint collision
    for m in modules:
        m.position = -1 * (abs(m.position) + 1000)
    await db.flush()

    for idx, mod_id in enumerate(body.module_ids):
        if mod_id in by_id:
            by_id[mod_id].position = idx + 1
            by_id[mod_id].updated_at = now()

    log_audit_event(
        db,
        actor_id=user.id,
        action="modules.reordered",
        target_entity="course",
        target_id=course_id,
        result="success",
        metadata={"moduleIdsOrder": body.module_ids},
    )
    await db.commit()

    detail = await get_cms_course_detail(db, course_id)
    return detail["modules"]


# --- Lesson Management Endpoints ---


@router.post(
    "/admin/courses/{course_id}/modules/{module_id}/lessons",
    response_model=CmsLessonDetailOut,
    status_code=201,
)
async def admin_create_lesson(
    course_id: str,
    module_id: str,
    body: CmsLessonCreateIn,
    user: ContentManagerPrincipal,
    db: DB,
):
    module = await db.scalar(
        select(CourseModule).where(
            CourseModule.id == module_id, CourseModule.course_id == course_id
        )
    )
    if not module:
        raise APIError(404, "NOT_FOUND", "Module not found in this course.")

    # Check content_ref uniqueness
    existing_ref = await db.scalar(
        select(Lesson.id).where(Lesson.content_ref == body.content_ref.strip())
    )
    if existing_ref:
        raise APIError(
            409,
            "CONTENT_REF_EXISTS",
            f"Content reference '{body.content_ref}' is already used by another lesson.",
        )

    max_pos = (
        await db.scalar(select(func.max(Lesson.position)).where(Lesson.module_id == module.id))
    ) or 0

    lesson = Lesson(
        module_id=module.id,
        title=body.title.strip(),
        position=max_pos + 1,
        duration_seconds=body.duration_seconds,
        content_type=body.content_type.strip(),
        content_ref=body.content_ref.strip(),
        is_preview=body.is_preview,
        is_downloadable=body.is_downloadable,
        policy_kind=PolicyKind(body.policy_kind),
        protection_policy=ContentProtectionPolicy(body.protection_policy),
    )
    db.add(lesson)
    await db.flush()

    # Recalculate course duration
    course = await db.get(Course, course_id)
    if course:
        total_dur = (
            await db.scalar(
                select(func.sum(Lesson.duration_seconds))
                .join(CourseModule, Lesson.module_id == CourseModule.id)
                .where(CourseModule.course_id == course_id)
            )
        ) or 0
        course.duration_seconds = total_dur

    log_audit_event(
        db,
        actor_id=user.id,
        action="lesson.created",
        target_entity="lesson",
        target_id=lesson.id,
        result="success",
        metadata={
            "courseId": course_id,
            "moduleId": module_id,
            "title": lesson.title,
            "durationSeconds": lesson.duration_seconds,
        },
    )
    await db.commit()
    await db.refresh(lesson)

    return {
        "id": lesson.id,
        "moduleId": lesson.module_id,
        "title": lesson.title,
        "position": lesson.position,
        "durationSeconds": lesson.duration_seconds,
        "contentType": lesson.content_type,
        "contentRef": lesson.content_ref,
        "isPreview": lesson.is_preview,
        "isDownloadable": lesson.is_downloadable,
        "policyKind": lesson.policy_kind.value
        if hasattr(lesson.policy_kind, "value")
        else str(lesson.policy_kind),
        "protectionPolicy": (
            lesson.protection_policy.value
            if hasattr(lesson, "protection_policy") and lesson.protection_policy
            else "blockCaptureWhereSupported"
        ),
        "createdAt": iso(lesson.created_at),
        "updatedAt": iso(lesson.updated_at),
    }


@router.put(
    "/admin/courses/{course_id}/modules/{module_id}/lessons/{lesson_id}",
    response_model=CmsLessonDetailOut,
)
async def admin_update_lesson(
    course_id: str,
    module_id: str,
    lesson_id: str,
    body: CmsLessonUpdateIn,
    user: ContentManagerPrincipal,
    db: DB,
):
    lesson = await db.scalar(
        select(Lesson)
        .where(Lesson.id == lesson_id, Lesson.module_id == module_id)
        .with_for_update()
    )
    if not lesson:
        raise APIError(404, "NOT_FOUND", "Lesson not found in this module.")

    if body.content_ref is not None and body.content_ref.strip() != lesson.content_ref:
        existing_ref = await db.scalar(
            select(Lesson.id).where(
                Lesson.content_ref == body.content_ref.strip(), Lesson.id != lesson.id
            )
        )
        if existing_ref:
            raise APIError(
                409,
                "CONTENT_REF_EXISTS",
                f"Content reference '{body.content_ref}' is already used by another lesson.",
            )
        lesson.content_ref = body.content_ref.strip()

    if body.title is not None:
        lesson.title = body.title.strip()
    if body.duration_seconds is not None:
        lesson.duration_seconds = body.duration_seconds
    if body.content_type is not None:
        lesson.content_type = body.content_type.strip()
    if body.is_preview is not None:
        lesson.is_preview = body.is_preview
    if body.is_downloadable is not None:
        lesson.is_downloadable = body.is_downloadable
    if body.policy_kind is not None:
        lesson.policy_kind = PolicyKind(body.policy_kind)
    if body.protection_policy is not None:
        lesson.protection_policy = ContentProtectionPolicy(body.protection_policy)

    lesson.updated_at = now()

    # Recalculate course duration
    course = await db.get(Course, course_id)
    if course:
        total_dur = (
            await db.scalar(
                select(func.sum(Lesson.duration_seconds))
                .join(CourseModule, Lesson.module_id == CourseModule.id)
                .where(CourseModule.course_id == course_id)
            )
        ) or 0
        course.duration_seconds = total_dur

    log_audit_event(
        db,
        actor_id=user.id,
        action="lesson.updated",
        target_entity="lesson",
        target_id=lesson.id,
        result="success",
        metadata={"courseId": course_id, "moduleId": module_id, "title": lesson.title},
    )
    await db.commit()
    await db.refresh(lesson)

    return {
        "id": lesson.id,
        "moduleId": lesson.module_id,
        "title": lesson.title,
        "position": lesson.position,
        "durationSeconds": lesson.duration_seconds,
        "contentType": lesson.content_type,
        "contentRef": lesson.content_ref,
        "isPreview": lesson.is_preview,
        "isDownloadable": lesson.is_downloadable,
        "policyKind": lesson.policy_kind.value
        if hasattr(lesson.policy_kind, "value")
        else str(lesson.policy_kind),
        "protectionPolicy": (
            lesson.protection_policy.value
            if hasattr(lesson, "protection_policy") and lesson.protection_policy
            else "blockCaptureWhereSupported"
        ),
        "createdAt": iso(lesson.created_at),
        "updatedAt": iso(lesson.updated_at),
    }


@router.delete(
    "/admin/courses/{course_id}/modules/{module_id}/lessons/{lesson_id}",
    status_code=204,
)
async def admin_delete_lesson(
    course_id: str,
    module_id: str,
    lesson_id: str,
    user: ContentManagerPrincipal,
    db: DB,
):
    await guard_course_history(db, course_id)
    lesson = await db.scalar(
        select(Lesson)
        .where(Lesson.id == lesson_id, Lesson.module_id == module_id)
        .with_for_update()
    )
    if not lesson:
        raise APIError(404, "NOT_FOUND", "Lesson not found.")

    deleted_title = lesson.title
    await db.delete(lesson)
    await db.flush()

    # Reindex remaining lessons in this module
    remaining = (
        await db.scalars(
            select(Lesson).where(Lesson.module_id == module_id).order_by(Lesson.position)
        )
    ).all()
    for idx, l in enumerate(remaining):
        l.position = idx + 1

    # Recalculate course duration
    course = await db.get(Course, course_id)
    if course:
        total_dur = (
            await db.scalar(
                select(func.sum(Lesson.duration_seconds))
                .join(CourseModule, Lesson.module_id == CourseModule.id)
                .where(CourseModule.course_id == course_id)
            )
        ) or 0
        course.duration_seconds = total_dur

    log_audit_event(
        db,
        actor_id=user.id,
        action="lesson.deleted",
        target_entity="lesson",
        target_id=lesson_id,
        result="success",
        metadata={"courseId": course_id, "moduleId": module_id, "title": deleted_title},
    )
    await db.commit()
    return Response(status_code=204)


@router.post(
    "/admin/courses/{course_id}/modules/{module_id}/lessons/reorder",
    response_model=list[CmsLessonDetailOut],
)
async def admin_reorder_lessons(
    course_id: str,
    module_id: str,
    body: CmsReorderLessonsIn,
    user: ContentManagerPrincipal,
    db: DB,
):
    lessons = (
        await db.scalars(select(Lesson).where(Lesson.module_id == module_id).with_for_update())
    ).all()
    by_id = {l.id: l for l in lessons}

    # Temporarily assign negative positions
    for l in lessons:
        l.position = -1 * (abs(l.position) + 1000)
    await db.flush()

    for idx, l_id in enumerate(body.lesson_ids):
        if l_id in by_id:
            by_id[l_id].position = idx + 1
            by_id[l_id].updated_at = now()

    log_audit_event(
        db,
        actor_id=user.id,
        action="lessons.reordered",
        target_entity="module",
        target_id=module_id,
        result="success",
        metadata={"courseId": course_id, "lessonIdsOrder": body.lesson_ids},
    )
    await db.commit()

    updated_lessons = (
        await db.scalars(
            select(Lesson).where(Lesson.module_id == module_id).order_by(Lesson.position)
        )
    ).all()

    return [
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
        for l in updated_lessons
    ]


# --- Assessment & Quiz Management Endpoints ---


@router.get(
    "/admin/courses/{course_id}/assessments",
    response_model=list[CmsAssessmentSummaryOut],
)
async def admin_list_course_assessments(
    course_id: str,
    user: CmsPrincipal,
    db: DB,
):
    assessments = (
        await db.scalars(
            select(Assessment)
            .where(Assessment.course_id == course_id)
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

    return [
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


@router.post(
    "/admin/courses/{course_id}/assessments",
    response_model=CmsAssessmentDetailOut,
    status_code=201,
)
async def admin_create_assessment(
    course_id: str,
    body: CmsAssessmentCreateIn,
    user: ContentManagerPrincipal,
    db: DB,
):
    course = await db.get(Course, course_id)
    if not course:
        raise APIError(404, "NOT_FOUND", "Course not found.")

    assessment = Assessment(
        course_id=course.id,
        title=body.title.strip(),
        description=body.description.strip(),
        instructions=body.instructions,
        passing_percentage=body.passing_percentage,
        time_limit_seconds=body.time_limit_seconds,
        max_attempts=body.max_attempts,
        required_for_certificate=body.required_for_certificate,
        protection_policy=ContentProtectionPolicy(body.protection_policy),
        status=Lifecycle(body.status),
    )
    db.add(assessment)
    await db.flush()

    log_audit_event(
        db,
        actor_id=user.id,
        action="assessment.created",
        target_entity="assessment",
        target_id=assessment.id,
        result="success",
        metadata={
            "courseId": course.id,
            "title": assessment.title,
            "passingPercentage": assessment.passing_percentage,
            "requiredForCertificate": assessment.required_for_certificate,
        },
    )
    await db.commit()
    return await get_cms_assessment_detail(db, assessment.id)


@router.get("/admin/assessments/{assessment_id}", response_model=CmsAssessmentDetailOut)
async def admin_get_assessment_detail(
    assessment_id: str,
    user: CmsPrincipal,
    db: DB,
):
    return await get_cms_assessment_detail(db, assessment_id)


@router.put("/admin/assessments/{assessment_id}", response_model=CmsAssessmentDetailOut)
async def admin_update_assessment(
    assessment_id: str,
    body: CmsAssessmentUpdateIn,
    user: ContentManagerPrincipal,
    db: DB,
):
    a = await db.scalar(select(Assessment).where(Assessment.id == assessment_id).with_for_update())
    if not a:
        raise APIError(404, "NOT_FOUND", "Assessment not found.")

    if body.title is not None:
        a.title = body.title.strip()
    if body.description is not None:
        a.description = body.description.strip()
    if body.instructions is not None:
        a.instructions = body.instructions
    if body.passing_percentage is not None:
        a.passing_percentage = body.passing_percentage
    if body.time_limit_seconds is not None:
        a.time_limit_seconds = body.time_limit_seconds
    if body.max_attempts is not None:
        a.max_attempts = body.max_attempts
    if body.required_for_certificate is not None:
        a.required_for_certificate = body.required_for_certificate
    if body.protection_policy is not None:
        a.protection_policy = ContentProtectionPolicy(body.protection_policy)
    if body.status is not None:
        a.status = Lifecycle(body.status)

    a.updated_at = now()

    log_audit_event(
        db,
        actor_id=user.id,
        action="assessment.updated",
        target_entity="assessment",
        target_id=a.id,
        result="success",
        metadata={
            "title": a.title,
            "passingPercentage": a.passing_percentage,
            "requiredForCertificate": a.required_for_certificate,
            "status": a.status.value,
        },
    )
    await db.commit()
    return await get_cms_assessment_detail(db, a.id)


@router.delete("/admin/assessments/{assessment_id}", status_code=204)
async def admin_delete_assessment(
    assessment_id: str,
    user: ContentManagerPrincipal,
    db: DB,
):
    a = await db.scalar(select(Assessment).where(Assessment.id == assessment_id).with_for_update())
    if not a:
        raise APIError(404, "NOT_FOUND", "Assessment not found.")

    deleted_title = a.title
    course_id = a.course_id
    await guard_course_history(db, course_id)
    if await db.scalar(select(LessonContentItem.id).where(LessonContentItem.assessment_id == a.id).limit(1)):
        raise APIError(409, "ASSESSMENT_IN_USE", "Disable this assessment instead of deleting linked content.")
    await db.delete(a)

    log_audit_event(
        db,
        actor_id=user.id,
        action="assessment.deleted",
        target_entity="assessment",
        target_id=assessment_id,
        result="success",
        metadata={"courseId": course_id, "title": deleted_title},
    )
    await db.commit()
    return Response(status_code=204)


@router.post(
    "/admin/assessments/{assessment_id}/questions",
    response_model=CmsQuestionDetailOut,
    status_code=201,
)
async def admin_create_question(
    assessment_id: str,
    body: CmsQuestionCreateIn,
    user: ContentManagerPrincipal,
    db: DB,
):
    assessment = await db.get(Assessment, assessment_id)
    if not assessment:
        raise APIError(404, "NOT_FOUND", "Assessment not found.")

    max_pos = (
        await db.scalar(
            select(func.max(AssessmentQuestion.position)).where(
                AssessmentQuestion.assessment_id == assessment.id
            )
        )
    ) or 0

    q_type = QuestionType(body.type)
    question = AssessmentQuestion(
        assessment_id=assessment.id,
        type=q_type,
        prompt=body.prompt.strip(),
        points=body.points,
        position=max_pos + 1,
        explanation=body.explanation.strip() if body.explanation else None,
        settings=body.settings or {},
        grading_data=body.grading_data or {},
    )
    db.add(question)
    await db.flush()

    # Add options
    for idx, opt_in in enumerate(body.options):
        opt = AssessmentOption(
            question_id=question.id,
            text=opt_in.text.strip(),
            hint=opt_in.hint.strip() if opt_in.hint else None,
            position=opt_in.position if opt_in.position is not None else idx + 1,
        )
        if opt_in.id:
            opt.id = opt_in.id
        db.add(opt)

    log_audit_event(
        db,
        actor_id=user.id,
        action="question.created",
        target_entity="question",
        target_id=question.id,
        result="success",
        metadata={
            "assessmentId": assessment_id,
            "type": question.type.value,
            "prompt": question.prompt[:50],
            "points": question.points,
        },
    )
    await db.commit()
    await db.refresh(question)

    options = (
        await db.scalars(
            select(AssessmentOption)
            .where(AssessmentOption.question_id == question.id)
            .order_by(AssessmentOption.position)
        )
    ).all()

    return {
        "id": question.id,
        "assessmentId": question.assessment_id,
        "type": question.type.value if hasattr(question.type, "value") else str(question.type),
        "prompt": question.prompt,
        "points": question.points,
        "position": question.position,
        "explanation": question.explanation,
        "settings": question.settings or {},
        "options": [
            {"id": o.id, "text": o.text, "hint": o.hint, "position": o.position} for o in options
        ],
        "gradingData": question.grading_data or {},
        "createdAt": iso(question.created_at),
        "updatedAt": iso(question.updated_at),
    }


@router.put(
    "/admin/assessments/{assessment_id}/questions/{question_id}",
    response_model=CmsQuestionDetailOut,
)
async def admin_update_question(
    assessment_id: str,
    question_id: str,
    body: CmsQuestionUpdateIn,
    user: ContentManagerPrincipal,
    db: DB,
):
    question = await db.scalar(
        select(AssessmentQuestion)
        .where(
            AssessmentQuestion.id == question_id,
            AssessmentQuestion.assessment_id == assessment_id,
        )
        .with_for_update()
    )
    if not question:
        raise APIError(404, "NOT_FOUND", "Question not found.")

    if body.type is not None:
        question.type = QuestionType(body.type)
    if body.prompt is not None:
        question.prompt = body.prompt.strip()
    if body.points is not None:
        question.points = body.points
    if body.explanation is not None:
        question.explanation = body.explanation.strip() if body.explanation else None
    if body.settings is not None:
        question.settings = body.settings
    if body.grading_data is not None:
        question.grading_data = body.grading_data

    question.updated_at = now()

    if body.options is not None:
        # Replace options
        current_opts = (
            await db.scalars(
                select(AssessmentOption).where(AssessmentOption.question_id == question.id)
            )
        ).all()
        for co in current_opts:
            await db.delete(co)
        await db.flush()

        for idx, opt_in in enumerate(body.options):
            opt = AssessmentOption(
                question_id=question.id,
                text=opt_in.text.strip(),
                hint=opt_in.hint.strip() if opt_in.hint else None,
                position=opt_in.position if opt_in.position is not None else idx + 1,
            )
            if opt_in.id:
                opt.id = opt_in.id
            db.add(opt)

    log_audit_event(
        db,
        actor_id=user.id,
        action="question.updated",
        target_entity="question",
        target_id=question.id,
        result="success",
        metadata={
            "assessmentId": assessment_id,
            "type": question.type.value,
            "points": question.points,
        },
    )
    await db.commit()
    await db.refresh(question)

    options = (
        await db.scalars(
            select(AssessmentOption)
            .where(AssessmentOption.question_id == question.id)
            .order_by(AssessmentOption.position)
        )
    ).all()

    return {
        "id": question.id,
        "assessmentId": question.assessment_id,
        "type": question.type.value if hasattr(question.type, "value") else str(question.type),
        "prompt": question.prompt,
        "points": question.points,
        "position": question.position,
        "explanation": question.explanation,
        "settings": question.settings or {},
        "options": [
            {"id": o.id, "text": o.text, "hint": o.hint, "position": o.position} for o in options
        ],
        "gradingData": question.grading_data or {},
        "createdAt": iso(question.created_at),
        "updatedAt": iso(question.updated_at),
    }


@router.delete(
    "/admin/assessments/{assessment_id}/questions/{question_id}",
    status_code=204,
)
async def admin_delete_question(
    assessment_id: str,
    question_id: str,
    user: ContentManagerPrincipal,
    db: DB,
):
    question = await db.scalar(
        select(AssessmentQuestion)
        .where(
            AssessmentQuestion.id == question_id,
            AssessmentQuestion.assessment_id == assessment_id,
        )
        .with_for_update()
    )
    if not question:
        raise APIError(404, "NOT_FOUND", "Question not found.")

    await db.delete(question)
    await db.flush()

    # Reindex remaining questions
    remaining = (
        await db.scalars(
            select(AssessmentQuestion)
            .where(AssessmentQuestion.assessment_id == assessment_id)
            .order_by(AssessmentQuestion.position)
        )
    ).all()
    for idx, q in enumerate(remaining):
        q.position = idx + 1

    log_audit_event(
        db,
        actor_id=user.id,
        action="question.deleted",
        target_entity="question",
        target_id=question_id,
        result="success",
        metadata={"assessmentId": assessment_id},
    )
    await db.commit()
    return Response(status_code=204)


@router.post(
    "/admin/assessments/{assessment_id}/questions/reorder",
    response_model=list[CmsQuestionDetailOut],
)
async def admin_reorder_questions(
    assessment_id: str,
    body: CmsReorderQuestionsIn,
    user: ContentManagerPrincipal,
    db: DB,
):
    questions = (
        await db.scalars(
            select(AssessmentQuestion)
            .where(AssessmentQuestion.assessment_id == assessment_id)
            .with_for_update()
        )
    ).all()
    by_id = {q.id: q for q in questions}

    # Temporarily assign negative positions
    for q in questions:
        q.position = -1 * (abs(q.position) + 1000)
    await db.flush()

    for idx, q_id in enumerate(body.question_ids):
        if q_id in by_id:
            by_id[q_id].position = idx + 1
            by_id[q_id].updated_at = now()

    log_audit_event(
        db,
        actor_id=user.id,
        action="questions.reordered",
        target_entity="assessment",
        target_id=assessment_id,
        result="success",
        metadata={"questionIdsOrder": body.question_ids},
    )
    await db.commit()

    detail = await get_cms_assessment_detail(db, assessment_id)
    return detail["questions"]
