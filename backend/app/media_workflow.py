"""Small signed-upload and authoritative per-video watch workflow."""

import uuid
from datetime import UTC, datetime, timedelta

import jwt
from fastapi import APIRouter
from pydantic import Field
from sqlalchemy import select

from . import media_provider
from .config import get_settings
from .dependencies import DB, ContentManagerPrincipal, Principal
from .errors import APIError
from .models import (
    Course,
    CourseModule,
    Lesson,
    LessonContentItem,
    LessonProgress,
    Lifecycle,
    MediaAsset,
    ResourceType,
    VideoWatchProgress,
)
from .schemas import CamelModel

router = APIRouter()


class UploadIn(CamelModel):
    lesson_id: str | None = None
    course_id: str | None = None
    replace_asset_id: str | None = None


@router.post("/admin/media/uploads")
async def authorize_upload(body: UploadIn, user: ContentManagerPrincipal, db: DB):
    if bool(body.lesson_id) == bool(body.course_id):
        raise APIError(422, "INVALID_TARGET", "Select a lesson or a course.")
    target = await db.get(Lesson if body.lesson_id else Course, body.lesson_id or body.course_id)
    if not target:
        raise APIError(404, "NOT_FOUND", "Upload target not found.")
    if body.replace_asset_id:
        from .academic import guard_course_history

        module = await db.get(CourseModule, target.module_id) if body.lesson_id else None
        if module:
            await guard_course_history(db, module.course_id)
        asset = await db.scalar(
            select(MediaAsset).where(MediaAsset.asset_id == body.replace_asset_id)
        )
        if not asset or asset.lesson_id != body.lesson_id:
            raise APIError(422, "INVALID_TARGET", "Replacement must belong to this lesson.")
        if await db.scalar(
            select(VideoWatchProgress.id)
            .where(VideoWatchProgress.media_asset_id == asset.id)
            .limit(1)
        ):
            raise APIError(
                409,
                "MEDIA_HAS_HISTORY",
                "This video has watch history. Add a new content item instead.",
            )
    public_id = "nadha/" + str(uuid.uuid4())
    kind = "video" if body.lesson_id else "image"
    result = media_provider.upload_authorization(public_id, kind)
    expires = datetime.now(UTC) + timedelta(hours=1)
    result["uploadToken"] = jwt.encode(
        {
            "sub": user.id,
            "aud": "media-upload",
            "exp": expires,
            "public_id": public_id,
            "kind": kind,
            **body.model_dump(),
        },
        get_settings().media_signing_secret,
        algorithm="HS256",
    )
    result["expiresAt"] = expires.isoformat()
    return result


class FinalizeIn(CamelModel):
    upload_token: str


@router.post("/admin/media/uploads/complete")
async def complete_upload(body: FinalizeIn, user: ContentManagerPrincipal, db: DB):
    try:
        intent = jwt.decode(
            body.upload_token,
            get_settings().media_signing_secret,
            algorithms=["HS256"],
            audience="media-upload",
        )
        if intent["sub"] != user.id:
            raise jwt.InvalidTokenError()
    except jwt.InvalidTokenError:
        raise APIError(403, "INVALID_UPLOAD", "Upload authorization is invalid or expired.")
    target = await db.scalar(
        select(Lesson if intent["lesson_id"] else Course)
        .where(
            (Lesson.id if intent["lesson_id"] else Course.id)
            == (intent["lesson_id"] or intent["course_id"])
        )
        .with_for_update()
    )
    if not target:
        raise APIError(404, "NOT_FOUND", "Upload target no longer exists.")
    data = await media_provider.inspect_upload(intent["public_id"], intent["kind"])
    if intent["kind"] == "image":
        target.cover_reference = media_provider.cover_url(intent["public_id"], data["format"])
        await db.commit()
        return {"coverReference": target.cover_reference, "status": "ready"}
    asset = await db.scalar(select(MediaAsset).where(MediaAsset.origin_key == intent["public_id"]))
    if not asset and intent.get("replace_asset_id"):
        from .academic import guard_course_history

        module = await db.get(CourseModule, target.module_id)
        await guard_course_history(db, module.course_id)
        asset = await db.scalar(
            select(MediaAsset)
            .where(
                MediaAsset.asset_id == intent["replace_asset_id"], MediaAsset.lesson_id == target.id
            )
            .with_for_update()
        )
        if not asset or await db.scalar(
            select(VideoWatchProgress.id)
            .where(VideoWatchProgress.media_asset_id == asset.id)
            .limit(1)
        ):
            raise APIError(409, "MEDIA_HAS_HISTORY", "Video replacement is no longer available.")
    if not asset:
        asset = MediaAsset(
            lesson_id=target.id, asset_id=str(uuid.uuid4()), kind="hls", public=False
        )
        db.add(asset)
    asset.provider = "cloudinary"
    asset.provider_asset_id = data["asset_id"]
    asset.origin_key = intent["public_id"]
    asset.status = "active"
    asset.metadata_json = {"duration": data["duration"], "format": data["format"]}
    await db.commit()
    return {
        "assetId": asset.asset_id,
        "status": "ready",
        "posterUrl": media_provider.delivery_url(asset, poster=True),
    }


async def watch_asset(db, user, asset_id):
    from .academic import ensure_asset_published
    from .services import resolve_access

    asset = await db.scalar(
        select(MediaAsset)
        .where(
            MediaAsset.asset_id == asset_id, MediaAsset.status == "active", MediaAsset.kind == "hls"
        )
        .with_for_update()
    )
    if not asset:
        raise APIError(404, "NOT_FOUND", "Video unavailable.")
    await ensure_asset_published(db, asset)
    lesson = await db.get(Lesson, asset.lesson_id)
    if not lesson or (not asset.content_item_id and lesson.content_ref != asset.asset_id):
        raise APIError(404, "NOT_FOUND", "Video unavailable.")
    if not (await resolve_access(db, user.id, ResourceType.lesson, asset.lesson_id))["allowed"]:
        raise APIError(403, "ENTITLEMENT_REQUIRED", "Lesson access required.")
    duration = (asset.metadata_json or {}).get("duration", lesson.duration_seconds)
    if duration <= 0:
        raise APIError(422, "DURATION_UNAVAILABLE", "Video duration is unavailable.")
    row = await db.scalar(
        select(VideoWatchProgress)
        .where(
            VideoWatchProgress.learner_id == user.id, VideoWatchProgress.media_asset_id == asset.id
        )
        .with_for_update()
    )
    if not row:
        row = VideoWatchProgress(
            learner_id=user.id,
            media_asset_id=asset.id,
            position_seconds=0,
            furthest_seconds=0,
            completed=False,
            checkpoint_at=datetime.now(UTC),
        )
        db.add(row)
    return asset, row, float(duration)


def watch_json(row, duration):
    return {
        "positionSeconds": row.position_seconds,
        "furthestSeconds": row.furthest_seconds,
        "completed": row.completed,
        "durationSeconds": duration,
    }


@router.get("/playback/{asset_id}/progress")
async def get_watch(asset_id: str, user: Principal, db: DB):
    _, row, duration = await watch_asset(db, user, asset_id)
    # Begin a fresh bounded playback window; idle time is never banked.
    row.checkpoint_at = datetime.now(UTC)
    await db.commit()
    return watch_json(row, duration)


class WatchIn(CamelModel):
    position_seconds: float = Field(ge=0, allow_inf_nan=False)


def advance_watch(row, position, duration, now):
    previous = (
        row.checkpoint_at.replace(tzinfo=UTC)
        if row.checkpoint_at.tzinfo is None
        else row.checkpoint_at
    )
    allowance = min(30, max(0, (now - previous).total_seconds())) * 2
    # No accumulating tolerance: tiny repeated requests cannot manufacture watched time.
    if position > row.furthest_seconds + allowance + 2:
        raise APIError(422, "FORWARD_SEEK_LIMIT", "Continue from your watched position.")
    row.position_seconds = min(position, duration, row.furthest_seconds + allowance)
    row.furthest_seconds = max(row.furthest_seconds, row.position_seconds)
    row.completed = row.completed or row.furthest_seconds >= duration * 0.95
    row.checkpoint_at = now


@router.post("/playback/{asset_id}/progress")
async def save_watch(asset_id: str, body: WatchIn, user: Principal, db: DB):
    asset, row, duration = await watch_asset(db, user, asset_id)
    advance_watch(row, body.position_seconds, duration, datetime.now(UTC))
    await db.flush()
    from .academic import required_quizzes_passed

    if row.completed and await required_quizzes_passed(db, user.id, asset.lesson_id):
        # Mixed lessons still require the existing explicit note/resource completion action.
        other = await db.scalar(
            select(LessonContentItem.id)
            .where(
                LessonContentItem.lesson_id == asset.lesson_id,
                LessonContentItem.status == Lifecycle.published,
                LessonContentItem.content_type.in_(["note", "resource"]),
            )
            .limit(1)
        )
        if not other:
            progress = await db.scalar(
                select(LessonProgress)
                .where(
                    LessonProgress.learner_id == user.id,
                    LessonProgress.lesson_id == asset.lesson_id,
                )
                .with_for_update()
            )
            if not progress:
                progress = LessonProgress(
                    learner_id=user.id,
                    lesson_id=asset.lesson_id,
                    duration_seconds=int(duration),
                    position_seconds=int(row.position_seconds),
                    revision=0,
                )
                db.add(progress)
            progress.completed = True
            progress.revision += 1
    await db.commit()
    return watch_json(row, duration)
