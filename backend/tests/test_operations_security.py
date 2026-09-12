from datetime import UTC, datetime, timedelta

import jwt
import pytest

from app.config import Settings
from app.errors import APIError
from app.media import issue_media_token, validate_media_token
from app.rate_limit import DistributedRateLimiter, Policy


class SharedRedis:
    def __init__(self):
        self.values = {}
        self.ttls = {}

    async def eval(self, script, number_of_keys, key, seconds):
        count = await self.incr(key)
        if await self.ttl(key) < 0:
            await self.expire(key, seconds)
        return count, await self.ttl(key)

    async def incr(self, key):
        self.values[key] = self.values.get(key, 0) + 1
        return self.values[key]

    async def expire(self, key, seconds):
        self.ttls[key] = seconds

    async def ttl(self, key):
        return self.ttls.get(key, -1)


class RequestStub:
    def __init__(self):
        self.method = "POST"
        self.headers = {"X-Forwarded-For": "198.51.100.8"}
        self.client = None


@pytest.mark.asyncio
async def test_distributed_rate_limit_shares_state_across_instances():
    store = SharedRedis()
    settings = Settings(redis_namespace="test")
    first = DistributedRateLimiter(store, settings)
    second = DistributedRateLimiter(store, settings)
    policy = Policy("reset", 2, 60)
    await first.enforce(RequestStub(), policy)
    await second.enforce(RequestStub(), policy)
    with pytest.raises(APIError) as error:
        await first.enforce(RequestStub(), policy)
    assert error.value.code == "RATE_LIMITED"
    assert error.value.retry_after == 60
    store.values.clear()
    await second.enforce(RequestStub(), policy)


def test_media_token_is_expiring_and_bound_to_one_asset():
    settings = Settings(media_signing_secret="x" * 48, media_token_minutes=5)
    token, expires = issue_media_token(
        settings=settings,
        learner_id="learner",
        asset_id="asset-a",
        lesson_id="lesson-a",
        course_id="course-a",
    )
    assert expires > datetime.now(UTC)
    assert (
        validate_media_token(settings=settings, token=token, asset_id="asset-a")["lesson"]
        == "lesson-a"
    )
    with pytest.raises(APIError) as mismatch:
        validate_media_token(settings=settings, token=token, asset_id="asset-b")
    assert mismatch.value.code == "MEDIA_RESOURCE_MISMATCH"
    expired = jwt.encode(
        {
            "sub": "learner",
            "asset": "asset-a",
            "aud": "protected-media",
            "iss": settings.issuer,
            "exp": datetime.now(UTC) - timedelta(seconds=1),
        },
        settings.media_signing_secret,
        algorithm="HS256",
    )
    with pytest.raises(APIError) as expiry:
        validate_media_token(settings=settings, token=expired, asset_id="asset-a")
    assert expiry.value.code == "MEDIA_AUTHORIZATION_EXPIRED"


def test_production_configuration_rejects_wildcard_cors_and_partial_providers():
    common = {
        "environment": "production",
        "jwt_secret": "j" * 40,
        "media_signing_secret": "m" * 40,
        "redis_url": "rediss://redis.example.com/0",
        "smtp_host": "smtp.example.com",
        "smtp_from_address": "security@example.com",
        "password_reset_url": "https://app.example.com/reset",
        "media_cdn_base_url": "https://media.example.com",
        "metrics_token": "metrics-secret",
    }
    with pytest.raises(ValueError, match="Wildcard CORS"):
        Settings(**common, cors_origins="*").validate_runtime()
    with pytest.raises(ValueError, match="Stripe provider configuration is incomplete"):
        Settings(**common, stripe_api_key="sk_live_only").validate_runtime()
    with pytest.raises(ValueError, match="Apple provider configuration is incomplete"):
        Settings(**common, apple_key_id="key-only").validate_runtime()
    with pytest.raises(ValueError, match="Google Play provider configuration is incomplete"):
        Settings(**common, google_play_package_name="com.example.app").validate_runtime()
