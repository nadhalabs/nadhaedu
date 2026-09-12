from datetime import UTC, datetime, timedelta
from urllib.parse import quote

import jwt
from jwt import InvalidTokenError

from .config import Settings
from .errors import APIError


def issue_media_token(
    *, settings: Settings, learner_id: str, asset_id: str, lesson_id: str, course_id: str
) -> tuple[str, datetime]:
    expires = datetime.now(UTC) + timedelta(minutes=settings.media_token_minutes)
    payload = {
        "sub": learner_id,
        "asset": asset_id,
        "lesson": lesson_id,
        "course": course_id,
        "aud": "protected-media",
        "iss": settings.issuer,
        "iat": datetime.now(UTC),
        "exp": expires,
    }
    return jwt.encode(payload, settings.media_signing_secret, algorithm="HS256"), expires


def validate_media_token(*, settings: Settings, token: str, asset_id: str) -> dict:
    try:
        payload = jwt.decode(
            token,
            settings.media_signing_secret,
            algorithms=["HS256"],
            audience="protected-media",
            issuer=settings.issuer,
            options={"require": ["sub", "asset", "lesson", "course", "exp", "iat", "aud", "iss"]},
        )
    except InvalidTokenError as error:
        raise APIError(
            401, "MEDIA_AUTHORIZATION_EXPIRED", "Media authorization is invalid or expired."
        ) from error
    if payload.get("asset") != asset_id:
        raise APIError(
            403,
            "MEDIA_RESOURCE_MISMATCH",
            "Media authorization does not match the requested asset.",
        )
    return payload


def signed_media_url(settings: Settings, asset_id: str, token: str) -> str:
    return f"{settings.media_cdn_base_url.rstrip('/')}/{quote(asset_id, safe='')}?token={quote(token, safe='')}"


def issue_download_token(
    *,
    settings: Settings,
    learner_id: str,
    asset_id: str,
    lesson_id: str,
    course_id: str,
    offline_hours: int = 168,
    offline_expires_at: datetime | None = None,
    download_minutes: int = 120,
) -> tuple[str, datetime, datetime]:
    now = datetime.now(UTC)
    download_expires = now + timedelta(minutes=download_minutes)
    maximum_lease_expires = now + timedelta(hours=offline_hours)
    if offline_expires_at is not None and offline_expires_at.tzinfo is None:
        offline_expires_at = offline_expires_at.replace(tzinfo=UTC)
    offline_lease_expires = min(
        maximum_lease_expires,
        offline_expires_at or maximum_lease_expires,
    )
    if offline_lease_expires <= now:
        raise APIError(403, "ENTITLEMENT_EXPIRED", "Offline entitlement has expired.")
    download_expires = min(download_expires, offline_lease_expires)
    payload = {
        "sub": learner_id,
        "asset": asset_id,
        "lesson": lesson_id,
        "course": course_id,
        "aud": "protected-download",
        "iss": settings.issuer,
        "iat": now,
        "exp": download_expires,
        "offline_exp": offline_lease_expires.isoformat().replace("+00:00", "Z"),
    }
    token = jwt.encode(payload, settings.media_signing_secret, algorithm="HS256")
    return token, download_expires, offline_lease_expires


def validate_download_token(*, settings: Settings, token: str, asset_id: str) -> dict:
    try:
        payload = jwt.decode(
            token,
            settings.media_signing_secret,
            algorithms=["HS256"],
            audience="protected-download",
            issuer=settings.issuer,
            options={"require": ["sub", "asset", "lesson", "course", "exp", "iat", "aud", "iss"]},
        )
    except InvalidTokenError as error:
        raise APIError(
            401, "DOWNLOAD_AUTHORIZATION_EXPIRED", "Download authorization is invalid or expired."
        ) from error
    if payload.get("asset") != asset_id:
        raise APIError(
            403,
            "DOWNLOAD_RESOURCE_MISMATCH",
            "Download authorization does not match the requested asset.",
        )
    return payload


def signed_download_url(settings: Settings, asset_id: str, token: str) -> str:
    return f"{settings.media_cdn_base_url.rstrip('/')}/downloads/{quote(asset_id, safe='')}?token={quote(token, safe='')}"
