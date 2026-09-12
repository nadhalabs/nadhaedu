"""Academic context is a catalog selection, never a learner-history namespace."""

from typing import Literal

from fastapi import APIRouter, Query
from pydantic import Field
from sqlalchemy import select, or_
from sqlalchemy.exc import IntegrityError

from .dependencies import DB, Principal, ContentManagerPrincipal, CmsPrincipal
from .errors import APIError
from .models import (
    Curriculum,
    Standard,
    Stream,
    Subject,
    StudentAcademicProfile,
    Course,
    CourseModule,
    Lesson,
    LessonContentItem,
    MediaAsset,
    Assessment,
    Lifecycle,
    User,
    LessonProgress,
    AssessmentAttempt,
    Enrollment,
    Bookmark,
    RecentlyViewed,
    Certificate,
    Entitlement,
    ResourceType,
    AttemptStatus,
)
from .schemas import CamelModel

router = APIRouter()
TAXONOMY = {"curricula": Curriculum, "standards": Standard, "streams": Stream, "subjects": Subject}


def taxonomy_json(row):
    result = {
        "id": row.id,
        "name": row.name,
        "code": row.code,
        "sortOrder": row.sort_order,
        "isActive": row.is_active,
    }
    for field, key in [
        ("curriculum_id", "curriculumId"),
        ("standard_id", "standardId"),
        ("country", "country"),
        ("region", "region"),
    ]:
        if hasattr(row, field):
            result[key] = getattr(row, field)
    return result


async def validate_selection(
    db, curriculum_id, standard_id, stream_id, *, subject_id=None, allow_empty=False
):
    if allow_empty and not any([curriculum_id, standard_id, stream_id, subject_id]):
        return
    curriculum = await db.get(Curriculum, curriculum_id) if curriculum_id else None
    standard = await db.get(Standard, standard_id) if standard_id else None
    if (
        not curriculum
        or not curriculum.is_active
        or not standard
        or not standard.is_active
        or standard.curriculum_id != curriculum_id
    ):
        raise APIError(
            422,
            "INVALID_ACADEMIC_SELECTION",
            "Select an active standard belonging to the curriculum.",
        )
    if stream_id:
        stream = await db.get(Stream, stream_id)
        if not stream or not stream.is_active or stream.standard_id != standard_id:
            raise APIError(
                422, "INVALID_ACADEMIC_STREAM", "Stream must belong to the selected standard."
            )
    elif await db.scalar(
        select(Stream.id)
        .where(Stream.standard_id == standard_id, Stream.is_active.is_(True))
        .limit(1)
    ):
        raise APIError(422, "ACADEMIC_STREAM_REQUIRED", "Select a stream for this standard.")
    if subject_id:
        subject = await db.get(Subject, subject_id)
        if not subject or not subject.is_active:
            raise APIError(422, "INVALID_ACADEMIC_SUBJECT", "Select an active subject.")
    elif allow_empty:
        raise APIError(422, "ACADEMIC_SUBJECT_REQUIRED", "A classified course requires a subject.")


async def profile_for(db, user):
    if user is None:
        return None
    return await db.scalar(
        select(StudentAcademicProfile).where(StudentAcademicProfile.user_id == user.id)
    )


async def scope_courses(db, query, user):
    profile = await profile_for(db, user)
    if profile is None:
        return query  # Legacy clients retain their existing unconfigured catalog.
    return query.where(
        Course.curriculum_id == profile.active_curriculum_id,
        Course.standard_id == profile.active_standard_id,
        Course.stream_id == profile.active_stream_id,
        Course.curriculum_id.in_(select(Curriculum.id).where(Curriculum.is_active.is_(True))),
        Course.standard_id.in_(select(Standard.id).where(Standard.is_active.is_(True))),
        or_(
            Course.stream_id.is_(None),
            Course.stream_id.in_(select(Stream.id).where(Stream.is_active.is_(True))),
        ),
        Course.subject_id.in_(select(Subject.id).where(Subject.is_active.is_(True))),
    )


def classification_json(course):
    return {
        "curriculumId": course.curriculum_id,
        "standardId": course.standard_id,
        "streamId": course.stream_id,
        "subjectId": course.subject_id,
    }


def profile_json(profile):
    if profile is None:
        return None
    return {
        "id": profile.id,
        "activeCurriculumId": profile.active_curriculum_id,
        "activeStandardId": profile.active_standard_id,
        "activeStreamId": profile.active_stream_id,
        "profileVersion": profile.profile_version,
        "updatedAt": profile.updated_at.isoformat(),
    }


class AcademicProfileIn(CamelModel):
    active_curriculum_id: str
    active_standard_id: str
    active_stream_id: str | None = None


@router.get("/academic-profile")
async def get_profile(user: Principal, db: DB):
    return {"profile": profile_json(await profile_for(db, user))}


@router.put("/academic-profile")
async def put_profile(body: AcademicProfileIn, user: Principal, db: DB):
    await validate_selection(
        db, body.active_curriculum_id, body.active_standard_id, body.active_stream_id
    )
    # Lock the user so concurrent first-time saves cannot create duplicate profile rows.
    await db.execute(select(User.id).where(User.id == user.id).with_for_update())
    profile = await profile_for(db, user)
    values = body.model_dump()
    if profile is None:
        profile = StudentAcademicProfile(user_id=user.id, profile_version=1, **values)
        db.add(profile)
    elif any(getattr(profile, key) != value for key, value in values.items()):
        for key, value in values.items():
            setattr(profile, key, value)
        profile.profile_version += 1
    await db.commit()
    await db.refresh(profile)
    return {"profile": profile_json(profile)}


@router.get("/academic/curricula")
async def curricula(db: DB):
    return {
        "items": [
            taxonomy_json(x)
            for x in (
                await db.scalars(
                    select(Curriculum)
                    .where(Curriculum.is_active.is_(True))
                    .order_by(Curriculum.sort_order, Curriculum.name)
                )
            ).all()
        ]
    }


@router.get("/academic/curricula/{curriculum_id}/standards")
async def standards(curriculum_id: str, db: DB):
    return {
        "items": [
            taxonomy_json(x)
            for x in (
                await db.scalars(
                    select(Standard)
                    .where(Standard.curriculum_id == curriculum_id, Standard.is_active.is_(True))
                    .order_by(Standard.sort_order, Standard.name)
                )
            ).all()
        ]
    }


@router.get("/academic/standards/{standard_id}/streams")
async def streams(standard_id: str, db: DB):
    return {
        "items": [
            taxonomy_json(x)
            for x in (
                await db.scalars(
                    select(Stream)
                    .where(Stream.standard_id == standard_id, Stream.is_active.is_(True))
                    .order_by(Stream.sort_order, Stream.name)
                )
            ).all()
        ]
    }


@router.get("/academic/subjects")
async def subjects(user: Principal, db: DB):
    course_query = await scope_courses(
        db, select(Course.subject_id).where(Course.status == Lifecycle.published), user
    )
    rows = await db.scalars(
        select(Subject)
        .where(Subject.is_active.is_(True), Subject.id.in_(course_query))
        .order_by(Subject.sort_order, Subject.name)
    )
    return {"items": [taxonomy_json(x) for x in rows]}


class TaxonomyIn(CamelModel):
    name: str = Field(min_length=1, max_length=120)
    code: str = Field(min_length=1, max_length=60)
    sort_order: int = 0
    is_active: bool = True
    curriculum_id: str | None = None
    standard_id: str | None = None
    country: str = Field(default="India", max_length=80)
    region: str | None = Field(default=None, max_length=100)


@router.get("/admin/academic/{kind}")
async def admin_taxonomy(
    kind: Literal["curricula", "standards", "streams", "subjects"], user: CmsPrincipal, db: DB
):
    model = TAXONOMY[kind]
    return {
        "items": [
            taxonomy_json(x)
            for x in (await db.scalars(select(model).order_by(model.sort_order, model.name))).all()
        ]
    }


async def save_taxonomy(kind, body, db, item_id=None):
    model = TAXONOMY[kind]
    row = await db.get(model, item_id) if item_id else model()
    if row is None:
        raise APIError(404, "NOT_FOUND", "Academic record not found.")
    fields = ["name", "code", "sort_order", "is_active"]
    parent = {"standards": ("curriculum_id", Curriculum), "streams": ("standard_id", Standard)}.get(
        kind
    )
    if parent:
        parent_id = getattr(body, parent[0])
        if not parent_id or not await db.get(parent[1], parent_id):
            raise APIError(422, "INVALID_ACADEMIC_PARENT", "Select a valid parent.")
        if item_id and getattr(row, parent[0]) != parent_id:
            raise APIError(
                409,
                "ACADEMIC_PARENT_IMMUTABLE",
                "Create a new record instead of moving an existing academic hierarchy.",
            )
        fields.append(parent[0])
    if kind == "curricula":
        fields += ["country", "region"]
    for key in fields:
        value = getattr(body, key)
        setattr(row, key, value.strip() if isinstance(value, str) else value)
    if not row.name or not row.code:
        raise APIError(422, "INVALID_ACADEMIC_RECORD", "Name and code cannot be blank.")
    db.add(row)
    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        raise APIError(
            409, "ACADEMIC_CODE_EXISTS", "This code already exists under the selected parent."
        )
    await db.refresh(row)
    return taxonomy_json(row)


@router.post("/admin/academic/{kind}", status_code=201)
async def create_taxonomy(
    kind: Literal["curricula", "standards", "streams", "subjects"],
    body: TaxonomyIn,
    user: ContentManagerPrincipal,
    db: DB,
):
    return await save_taxonomy(kind, body, db)


@router.put("/admin/academic/{kind}/{item_id}")
async def update_taxonomy(
    kind: Literal["curricula", "standards", "streams", "subjects"],
    item_id: str,
    body: TaxonomyIn,
    user: ContentManagerPrincipal,
    db: DB,
):
    return await save_taxonomy(kind, body, db, item_id)


async def guard_course_history(db, course_id):
    """Block physical content deletion at the course boundary, including archived courses."""
    lesson_ids = select(Lesson.id).join(CourseModule).where(CourseModule.course_id == course_id)
    assessment_ids = select(Assessment.id).where(Assessment.course_id == course_id)
    checks = [
        select(model.id).where(model.course_id == course_id)
        for model in (Enrollment, Bookmark, RecentlyViewed, Certificate)
    ]
    checks += [
        select(LessonProgress.id).where(LessonProgress.lesson_id.in_(lesson_ids)),
        select(AssessmentAttempt.id).where(AssessmentAttempt.assessment_id.in_(assessment_ids)),
    ]
    checks += [
        select(Entitlement.id).where(
            or_(
                (Entitlement.resource_type == ResourceType.course)
                & (Entitlement.resource_id == course_id),
                (Entitlement.resource_type == ResourceType.lesson)
                & Entitlement.resource_id.in_(lesson_ids),
                (Entitlement.resource_type == ResourceType.module)
                & Entitlement.resource_id.in_(
                    select(CourseModule.id).where(CourseModule.course_id == course_id)
                ),
                (Entitlement.resource_type == ResourceType.assessment)
                & Entitlement.resource_id.in_(assessment_ids),
            )
        )
    ]
    # Registered assets may already be downloaded on devices that are offline.
    checks += [select(MediaAsset.id).where(MediaAsset.lesson_id.in_(lesson_ids))]
    for check in checks:
        if await db.scalar(check.limit(1)):
            raise APIError(
                409,
                "CONTENT_HAS_LEARNER_HISTORY",
                "This content has learner history. Archive or disable it instead of deleting it.",
            )


def content_json(item):
    return {
        "id": item.id,
        "lessonId": item.lesson_id,
        "type": item.content_type,
        "position": item.position,
        "title": item.title,
        "referenceId": item.reference_id,
        "assessmentId": item.assessment_id,
        "body": item.body,
        "status": item.status.value,
        "metadata": item.metadata_json,
    }


async def lesson_items(db, lesson_ids, *, published=True):
    query = (
        select(LessonContentItem)
        .where(LessonContentItem.lesson_id.in_(lesson_ids))
        .order_by(LessonContentItem.position)
    )
    if published:
        query = query.where(LessonContentItem.status == Lifecycle.published)
    result = {}
    for item in await db.scalars(query):
        result.setdefault(item.lesson_id, []).append(content_json(item))
    return result


class ContentItemIn(CamelModel):
    content_type: Literal["video", "note", "quiz", "resource"]
    position: int = Field(ge=1)
    title: str = Field(default="", max_length=200)
    reference_id: str | None = Field(default=None, max_length=255)
    assessment_id: str | None = None
    body: str | None = Field(default=None, max_length=100000)
    status: Literal["draft", "published", "unavailable", "archived"] = "draft"


async def save_content(db, lesson_id, body, item_id=None):
    lesson = await db.scalar(select(Lesson).where(Lesson.id == lesson_id).with_for_update())
    if not lesson:
        raise APIError(404, "NOT_FOUND", "Lesson not found.")
    module = await db.get(CourseModule, lesson.module_id)
    if body.content_type == "quiz":
        assessment = await db.get(Assessment, body.assessment_id) if body.assessment_id else None
        if (
            not assessment
            or assessment.course_id != module.course_id
            or (body.status == "published" and assessment.status != Lifecycle.published)
        ):
            raise APIError(
                422,
                "INVALID_ASSESSMENT",
                "Select an assessment in this course; published quiz content requires a published assessment.",
            )
    elif body.assessment_id:
        raise APIError(422, "INVALID_ASSESSMENT", "Only quiz content can reference an assessment.")
    asset = None
    if body.content_type in {"video", "resource"}:
        asset = await db.scalar(
            select(MediaAsset).where(
                MediaAsset.lesson_id == lesson_id,
                MediaAsset.asset_id == body.reference_id,
                MediaAsset.kind == ("hls" if body.content_type == "video" else "download"),
                MediaAsset.status == "active",
            )
        )
        if not asset:
            raise APIError(
                422,
                "MEDIA_NOT_REGISTERED",
                "Select an existing active media asset registered to this lesson.",
            )
    if body.content_type == "note" and not (body.body or "").strip():
        raise APIError(422, "NOTE_BODY_REQUIRED", "Enter the note text.")
    item = (
        await db.get(LessonContentItem, item_id)
        if item_id
        else LessonContentItem(lesson_id=lesson_id)
    )
    if item is None or item.lesson_id != lesson_id:
        raise APIError(404, "NOT_FOUND", "Content item not found in lesson.")
    if item_id and (
        item.content_type != body.content_type
        or item.reference_id != body.reference_id
        or item.assessment_id != body.assessment_id
    ):
        await guard_course_history(db, module.course_id)
    for key, value in body.model_dump().items():
        setattr(item, key, Lifecycle(value) if key == "status" else value)
    db.add(item)
    try:
        await db.flush()
        if asset:
            if asset.content_item_id and asset.content_item_id != item.id:
                raise APIError(
                    409,
                    "MEDIA_ALREADY_LINKED",
                    "Media asset already belongs to another content item.",
                )
            asset.content_item_id = item.id
        await db.commit()
    except IntegrityError:
        await db.rollback()
        raise APIError(409, "CONTENT_POSITION_EXISTS", "A content item already uses this position.")
    await db.refresh(item)
    return content_json(item)


async def required_quizzes_passed(db, learner_id, lesson_id):
    required = set(
        await db.scalars(
            select(LessonContentItem.assessment_id).where(
                LessonContentItem.lesson_id == lesson_id,
                LessonContentItem.status == Lifecycle.published,
                LessonContentItem.content_type == "quiz",
            )
        )
    )
    passed = set(
        await db.scalars(
            select(AssessmentAttempt.assessment_id).where(
                AssessmentAttempt.learner_id == learner_id,
                AssessmentAttempt.assessment_id.in_(required),
                AssessmentAttempt.status == AttemptStatus.submitted,
                AssessmentAttempt.passed.is_(True),
            )
        )
    )
    from .models import VideoWatchProgress
    videos = list(await db.scalars(select(MediaAsset).join(LessonContentItem, MediaAsset.content_item_id == LessonContentItem.id).where(
        LessonContentItem.lesson_id == lesson_id, LessonContentItem.status == Lifecycle.published,
        LessonContentItem.content_type == "video", MediaAsset.asset_id == LessonContentItem.reference_id,
        MediaAsset.kind == "hls")))
    required_video_ids = list(await db.scalars(select(LessonContentItem.id).where(
        LessonContentItem.lesson_id == lesson_id, LessonContentItem.status == Lifecycle.published,
        LessonContentItem.content_type == "video")))
    if len(videos) != len(required_video_ids):
        return False
    if not videos and not await db.scalar(select(LessonContentItem.id).where(LessonContentItem.lesson_id == lesson_id).limit(1)):
        lesson = await db.get(Lesson, lesson_id)
        if lesson and lesson.content_type == "video":
            videos = list(await db.scalars(select(MediaAsset).where(MediaAsset.lesson_id == lesson_id, MediaAsset.asset_id == lesson.content_ref, MediaAsset.kind == "hls")))
    for asset in videos:
        if not await db.scalar(select(VideoWatchProgress.completed).where(VideoWatchProgress.media_asset_id == asset.id, VideoWatchProgress.learner_id == learner_id)):
            return False
    return required <= passed


async def ensure_asset_published(db, asset):
    if asset.content_item_id:
        item = await db.get(LessonContentItem, asset.content_item_id)
        if not item or item.lesson_id != asset.lesson_id or item.status != Lifecycle.published or (asset.kind == "hls" and (item.content_type != "video" or item.reference_id != asset.asset_id)):
            raise APIError(404, "NOT_FOUND", "Media content is unavailable.")


class ContentOrderIn(CamelModel):
    item_ids: list[str]


@router.post("/admin/lessons/{lesson_id}/content-items/reorder")
async def reorder_content(
    lesson_id: str, body: ContentOrderIn, user: ContentManagerPrincipal, db: DB
):
    await db.execute(select(Lesson.id).where(Lesson.id == lesson_id).with_for_update())
    rows = list(
        await db.scalars(select(LessonContentItem).where(LessonContentItem.lesson_id == lesson_id))
    )
    if len(set(body.item_ids)) != len(body.item_ids) or set(body.item_ids) != {r.id for r in rows}:
        raise APIError(422, "INVALID_ORDER", "Include every content item exactly once.")
    offset = max([r.position for r in rows], default=0) + len(rows) + 1
    for index, row in enumerate(rows):
        row.position = offset + index
    await db.flush()
    positions = {item_id: index + 1 for index, item_id in enumerate(body.item_ids)}
    for row in rows:
        row.position = positions[row.id]
    await db.commit()
    return {"items": (await lesson_items(db, [lesson_id], published=False)).get(lesson_id, [])}


@router.get("/admin/lessons/{lesson_id}/media-assets")
async def lesson_media(lesson_id: str, user: CmsPrincipal, db: DB):
    from .media_provider import delivery_url
    return {
        "items": [
            {
                "id": a.id,
                "assetId": a.asset_id,
                "kind": a.kind,
                "status": a.status,
                "contentItemId": a.content_item_id,
                "posterUrl": delivery_url(a, poster=True) if a.provider == "cloudinary" else None,
                "previewUrl": delivery_url(a) if a.provider == "cloudinary" else None,
            }
            for a in await db.scalars(select(MediaAsset).where(MediaAsset.lesson_id == lesson_id))
        ]
    }


@router.get("/admin/lessons/{lesson_id}/content-items")
async def list_content(lesson_id: str, user: CmsPrincipal, db: DB):
    return {"items": (await lesson_items(db, [lesson_id], published=False)).get(lesson_id, [])}


@router.post("/admin/lessons/{lesson_id}/content-items", status_code=201)
async def create_content(
    lesson_id: str, body: ContentItemIn, user: ContentManagerPrincipal, db: DB
):
    return await save_content(db, lesson_id, body)


@router.put("/admin/lessons/{lesson_id}/content-items/{item_id}")
async def update_content(
    lesson_id: str, item_id: str, body: ContentItemIn, user: ContentManagerPrincipal, db: DB
):
    return await save_content(db, lesson_id, body, item_id)


@router.get("/lesson-content/{item_id}")
async def get_content(item_id: str, user: Principal, db: DB):
    from .services import resolve_access
    from .models import ResourceType

    item = await db.get(LessonContentItem, item_id)
    if not item or item.status != Lifecycle.published:
        raise APIError(404, "NOT_FOUND", "Content is unavailable.")
    decision = await resolve_access(db, user.id, ResourceType.lesson, item.lesson_id)
    if not decision["allowed"]:
        raise APIError(403, "ENTITLEMENT_REQUIRED", "Access to this lesson is required.")
    return content_json(item)


@router.get("/lessons/{lesson_id}/completion-readiness")
async def completion_readiness(lesson_id: str, user: Principal, db: DB):
    from .services import resolve_access

    decision = await resolve_access(db, user.id, ResourceType.lesson, lesson_id)
    if not decision["allowed"]:
        raise APIError(403, "ENTITLEMENT_REQUIRED", "Access to this lesson is required.")
    return {"canComplete": await required_quizzes_passed(db, user.id, lesson_id)}
