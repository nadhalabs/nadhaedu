import asyncio
import hashlib
import os
import uuid
from types import SimpleNamespace

import pytest
from redis.asyncio import Redis

from app.config import Settings
from app.errors import APIError
from app.rate_limit import DistributedRateLimiter, Policy

pytestmark = pytest.mark.skipif(
    not os.getenv("REDIS_TEST_URL"), reason="REDIS_TEST_URL is required for real Redis verification"
)


@pytest.mark.asyncio
async def test_atomic_limit_across_instances_and_expiry_repair():
    redis = Redis.from_url(os.environ["REDIS_TEST_URL"], decode_responses=True)
    namespace = f"integration:{uuid.uuid4().hex}"
    settings = Settings(redis_namespace=namespace)
    limiters = [DistributedRateLimiter(redis, settings), DistributedRateLimiter(redis, settings)]
    request = SimpleNamespace(headers={}, client=SimpleNamespace(host="192.0.2.9"))
    policy = Policy("concurrent", 5, 60)
    digest = hashlib.sha256(b"ip:192.0.2.9").hexdigest()[:32]
    key = f"{namespace}:rate:concurrent:{digest}"
    try:
        results = await asyncio.gather(
            *(limiters[index % 2].enforce(request, policy) for index in range(20)),
            return_exceptions=True,
        )
        assert sum(result is None for result in results) == 5
        assert (
            sum(isinstance(result, APIError) and result.status == 429 for result in results) == 15
        )
        assert 0 < await redis.ttl(key) <= 60
        await redis.persist(key)
        with pytest.raises(APIError):
            await limiters[0].enforce(request, policy)
        assert 0 < await redis.ttl(key) <= 60
    finally:
        await redis.delete(key)
        await redis.aclose()
