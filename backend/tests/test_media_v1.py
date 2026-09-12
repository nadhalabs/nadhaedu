# ruff: noqa: F811
from datetime import UTC, datetime, timedelta
from types import SimpleNamespace
from unittest.mock import AsyncMock

import httpx
import pytest
from sqlalchemy import func, select
from test_academic_hierarchy import academic_env  # noqa: F401

from app import media_provider
from app.config import get_settings
from app.errors import APIError
from app.media_workflow import advance_watch
from app.models import LessonContentItem, LessonProgress, Lifecycle, MediaAsset, VideoWatchProgress


@pytest.fixture
def provider(monkeypatch):
    settings = get_settings()
    monkeypatch.setattr(settings, "cloudinary_cloud_name", "test-cloud")
    monkeypatch.setattr(settings, "cloudinary_api_key", "test-key")
    monkeypatch.setattr(settings, "cloudinary_api_secret", "never-return-this-secret")


@pytest.mark.asyncio
async def test_upload_permissions_verification_and_stable_identity(
    academic_env, provider, monkeypatch
):
    client, headers, factory = academic_env
    path = "/api/v1/admin/media/uploads"
    assert (await client.post(path, json={"lessonId": "a-lesson"})).status_code == 401
    assert (
        await client.post(path, headers=headers["learner"], json={"lessonId": "a-lesson"})
    ).status_code == 403
    response = await client.post(path, headers=headers["admin"], json={"lessonId": "a-lesson"})
    assert response.status_code == 200, response.text
    assert "never-return-this-secret" not in response.text
    auth = response.json()
    assert auth["fields"]["type"] == "authenticated"
    assert auth["fields"]["overwrite"] == "false"

    async def inspect(public_id, kind):
        return {"asset_id": "provider-identity", "duration": 100, "format": "mp4"}

    monkeypatch.setattr(media_provider, "inspect_upload", inspect)
    result = await client.post(
        path + "/complete", headers=headers["admin"], json={"uploadToken": auth["uploadToken"]}
    )
    assert result.status_code == 200, result.text
    asset_id = result.json()["assetId"]
    assert "never-return-this-secret" not in result.text
    replay = await client.post(
        path + "/complete", headers=headers["admin"], json={"uploadToken": auth["uploadToken"]}
    )
    assert replay.json()["assetId"] == asset_id
    async with factory() as db:
        asset = await db.scalar(select(MediaAsset).where(MediaAsset.asset_id == asset_id))
        assert asset.provider == "cloudinary"
        assert asset.provider_asset_id == "provider-identity"
        assert await db.scalar(select(func.count()).select_from(MediaAsset)) == 2
    assert (
        await client.get("/api/v1/playback/" + asset_id, headers=headers["learner"])
    ).status_code == 404
    attached = await client.post(
        "/api/v1/admin/lessons/a-lesson/content-items",
        headers=headers["admin"],
        json={
            "contentType": "video",
            "referenceId": asset_id,
            "position": 1,
            "status": "published",
        },
    )
    assert attached.status_code == 201
    playback = await client.get("/api/v1/playback/" + asset_id, headers=headers["learner"])
    assert playback.status_code == 200
    assert playback.json()["kind"] == "mp4"
    assert "expires_at=" in playback.json()["streamUrl"]
    assert "never-return-this-secret" not in playback.text
    async with factory() as db:
        item = await db.get(LessonContentItem, attached.json()["id"])
        item.reference_id = "wrong-asset"
        await db.commit()
    assert (
        await client.get("/api/v1/playback/" + asset_id, headers=headers["learner"])
    ).status_code == 404
    assert (
        await client.get("/api/v1/playback/" + asset_id + "/progress", headers=headers["learner"])
    ).status_code == 404


@pytest.mark.asyncio
async def test_provider_validation_rejects_malformed_and_missing_assets(provider, monkeypatch):
    for data in [
        {},
        {"public_id": "expected", "resource_type": "video", "type": "upload"},
        {
            "public_id": "expected",
            "resource_type": "video",
            "type": "authenticated",
            "asset_id": "x",
            "bytes": 100,
            "format": "mp4",
            "duration": float("nan"),
        },
    ]:
        response = SimpleNamespace(raise_for_status=lambda: None, json=lambda data=data: data)
        mock = AsyncMock(return_value=response)
        monkeypatch.setattr(httpx.AsyncClient, "get", mock)
        with pytest.raises(APIError):
            await media_provider.inspect_upload("expected", "video")


@pytest.mark.asyncio
async def test_watch_resume_threshold_no_manual_bypass_and_history(academic_env):
    client, headers, factory = academic_env
    path = "/api/v1/playback/a-video/progress"
    h = headers["learner"]
    assert (await client.get(path)).status_code == 401
    assert (await client.get(path, headers=h)).json()["positionSeconds"] == 0
    assert (await client.post(path, headers=h, json={"positionSeconds": 60})).status_code == 422
    async with factory() as db:
        row = await db.scalar(select(VideoWatchProgress))
        row.checkpoint_at = datetime.now(UTC) - timedelta(seconds=30)
        await db.commit()
    result = await client.post(path, headers=h, json={"positionSeconds": 57})
    assert result.status_code == 200, result.text
    assert result.json()["completed"]
    async with factory() as db:
        assert (await db.scalar(select(LessonProgress))).completed
        asset = await db.get(MediaAsset, "media")
        asset.provider_asset_id = "migrated-provider-identity"
        asset.origin_key = "new-provider/path"
        await db.commit()
    resume = (await client.get(path, headers=h)).json()
    assert resume["positionSeconds"] == 57
    rewind = (await client.post(path, headers=h, json={"positionSeconds": 10})).json()
    assert rewind["positionSeconds"] == 10 and rewind["furthestSeconds"] == 57
    assert (await client.get(path, headers=h)).json()["completed"]


def test_progress_clock_budget_and_no_tolerance_accumulation():
    now = datetime.now(UTC)
    row = SimpleNamespace(
        checkpoint_at=now, position_seconds=0, furthest_seconds=0, completed=False
    )
    for _ in range(20):
        advance_watch(row, 2, 100, now)
    assert row.furthest_seconds == 0
    advance_watch(row, 20, 100, now + timedelta(seconds=10))
    assert row.furthest_seconds == 20
    with pytest.raises(APIError):
        advance_watch(row, 95, 100, now + timedelta(seconds=11))
    advance_watch(row, 10, 100, now + timedelta(seconds=12))
    assert row.position_seconds == 10 and row.furthest_seconds == 20


@pytest.mark.asyncio
async def test_failed_upload_has_no_record_and_cover_uses_offering(
    academic_env, provider, monkeypatch
):
    client, headers, factory = academic_env
    path = "/api/v1/admin/media/uploads"
    auth = (await client.post(path, headers=headers["admin"], json={"lessonId": "a-lesson"})).json()
    monkeypatch.setattr(
        media_provider,
        "inspect_upload",
        AsyncMock(side_effect=APIError(422, "UPLOAD_NOT_READY", "Missing")),
    )
    result = await client.post(
        path + "/complete", headers=headers["admin"], json={"uploadToken": auth["uploadToken"]}
    )
    assert result.status_code == 422
    async with factory() as db:
        assert await db.scalar(select(func.count()).select_from(MediaAsset)) == 1
    auth = (await client.post(path, headers=headers["admin"], json={"courseId": "a"})).json()
    assert auth["fields"]["type"] == "upload"
    monkeypatch.setattr(media_provider, "inspect_upload", AsyncMock(return_value={"format": "jpg"}))
    result = await client.post(
        path + "/complete", headers=headers["admin"], json={"uploadToken": auth["uploadToken"]}
    )
    assert result.status_code == 200
    course = (await client.get("/api/v1/courses/a")).json()
    assert course["summary"]["coverReference"] == result.json()["coverReference"]
    assert (await client.get("/api/v1/admin/courses/a", headers=headers["admin"])).json()["coverReference"] == result.json()["coverReference"]
    assert (await client.get("/api/v1/courses/b")).json()["summary"]["coverReference"] is None


@pytest.mark.asyncio
async def test_two_videos_isolate_progress_and_gate_completion(academic_env):
    client, headers, factory = academic_env
    h = headers["learner"]
    async with factory() as db:
        for number in [1, 2]:
            item = LessonContentItem(
                id=f"item-{number}",
                lesson_id="a-lesson",
                content_type="video",
                reference_id=f"video-{number}",
                position=number,
                status=Lifecycle.published,
            )
            db.add(item)
            await db.flush()
            db.add(
                MediaAsset(
                    id=f"asset-{number}",
                    lesson_id="a-lesson",
                    content_item_id=item.id,
                    asset_id=f"video-{number}",
                    origin_key=f"new-{number}",
                    kind="hls",
                    metadata_json={"duration": 100},
                )
            )
        await db.commit()
    for number in [1, 2]:
        assert (await client.get(f"/api/v1/playback/video-{number}/progress", headers=h)).json()[
            "positionSeconds"
        ] == 0
    for number in [1, 2]:
        async with factory() as db:
            row = await db.scalar(
                select(VideoWatchProgress).where(
                    VideoWatchProgress.media_asset_id == f"asset-{number}"
                )
            )
            row.checkpoint_at = datetime.now(UTC) - timedelta(seconds=30)
            await db.commit()
        result = await client.post(
            f"/api/v1/playback/video-{number}/progress", headers=h, json={"positionSeconds": 55}
        )
        assert result.status_code == 200
        async with factory() as db:
            row = await db.scalar(
                select(VideoWatchProgress).where(
                    VideoWatchProgress.media_asset_id == f"asset-{number}"
                )
            )
            row.checkpoint_at = datetime.now(UTC) - timedelta(seconds=20)
            await db.commit()
        assert (
            await client.post(
                f"/api/v1/playback/video-{number}/progress", headers=h, json={"positionSeconds": 95}
            )
        ).json()["completed"]
        ready = (
            await client.get("/api/v1/lessons/a-lesson/completion-readiness", headers=h)
        ).json()["canComplete"]
        assert ready == (number == 2)
        if number == 1:
            assert (await client.get("/api/v1/playback/video-2/progress", headers=h)).json()[
                "furthestSeconds"
            ] == 0
