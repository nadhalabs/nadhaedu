"""Cloudinary adapter. Domain callers retain Nadha asset identities."""

import hashlib
import math
import time
from urllib.parse import quote, urlencode

import httpx

from .config import get_settings
from .errors import APIError


def configuration():
    s = get_settings()
    if not all((s.cloudinary_cloud_name, s.cloudinary_api_key, s.cloudinary_api_secret)):
        raise APIError(503, "MEDIA_NOT_CONFIGURED", "Media uploads are not configured.")
    return s


def signature(params, secret):
    payload = "&".join(f"{k}={v}" for k, v in sorted(params.items()))
    return hashlib.sha256((payload + secret).encode()).hexdigest()


def upload_authorization(public_id, kind):
    s = configuration()
    params = {
        "timestamp": int(time.time()),
        "public_id": public_id,
        "overwrite": "false",
        "type": "authenticated" if kind == "video" else "upload",
    }
    return {
        "uploadUrl": f"https://api.cloudinary.com/v1_1/{s.cloudinary_cloud_name}/{kind}/upload",
        "fields": {
            **params,
            "api_key": s.cloudinary_api_key,
            "signature": signature(params, s.cloudinary_api_secret),
        },
    }


async def inspect_upload(public_id, kind):
    s = configuration()
    delivery = "authenticated" if kind == "video" else "upload"
    url = f"https://api.cloudinary.com/v1_1/{s.cloudinary_cloud_name}/resources/{kind}/{delivery}/{quote(public_id, safe='')}"
    try:
        async with httpx.AsyncClient(timeout=20) as client:
            response = await client.get(url, auth=(s.cloudinary_api_key, s.cloudinary_api_secret))
            response.raise_for_status()
            data = response.json()
    except (httpx.HTTPError, ValueError):
        raise APIError(
            422, "UPLOAD_NOT_READY", "Upload could not be verified. Retry after upload finishes."
        )
    if (
        data.get("public_id") != public_id
        or data.get("resource_type") != kind
        or data.get("type") != delivery
        or not data.get("asset_id")
        or not isinstance(data.get("bytes"), int)
        or data["bytes"] <= 0
        or data.get("format")
        not in ({"mp4", "mov", "webm"} if kind == "video" else {"jpg", "png", "webp"})
    ):
        raise APIError(422, "INVALID_PROVIDER_ASSET", "Provider asset metadata is invalid.")
    if kind == "video" and (
        not isinstance(data.get("duration"), (int, float))
        or not math.isfinite(data["duration"])
        or data["duration"] <= 0
    ):
        raise APIError(422, "INVALID_PROVIDER_ASSET", "Video duration is invalid.")
    return data


def delivery_url(asset, *, poster=False):
    s = configuration()
    params = {
        "public_id": asset.origin_key,
        "format": "jpg" if poster else asset.metadata_json["format"],
        "type": "authenticated",
        "expires_at": int(time.time()) + s.media_token_minutes * 60,
    }
    if poster:
        params["transformation"] = "so_0,w_960,c_limit"
    return f"https://api.cloudinary.com/v1_1/{s.cloudinary_cloud_name}/video/download?" + urlencode(
        {
            **params,
            "api_key": s.cloudinary_api_key,
            "signature": signature(params, s.cloudinary_api_secret),
        }
    )


def cover_url(public_id, format):
    s = configuration()
    return f"https://res.cloudinary.com/{s.cloudinary_cloud_name}/image/upload/{quote(public_id, safe='/')}.{format}"
