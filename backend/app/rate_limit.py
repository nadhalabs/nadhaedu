import asyncio
import hashlib
import heapq
import logging
import math
import time
from dataclasses import dataclass

import jwt
from fastapi import Request
from redis.asyncio import Redis
from redis.exceptions import RedisError

from .config import Settings
from .errors import APIError
from .security import decode_token


@dataclass(frozen=True)
class Policy:
    action: str
    limit: int
    window_seconds: int
    fail_closed: bool = True


# One atomic operation also repairs legacy counters with a missing expiry.
RATE_LIMIT_SCRIPT = """
local count = redis.call('INCR', KEYS[1])
local ttl = redis.call('TTL', KEYS[1])
if ttl < 0 then
  redis.call('EXPIRE', KEYS[1], ARGV[1])
  ttl = tonumber(ARGV[1])
end
return {count, ttl}
"""

POLICIES = {
    ("POST", "/api/v1/auth/register"): Policy("auth-register", 5, 900),
    ("POST", "/api/v1/auth/password-reset/confirm"): Policy("password-reset-confirm", 10, 900),
    ("POST", "/api/v1/account/password"): Policy("password-change", 5, 900),
    ("POST", "/api/v1/account/password-change"): Policy("password-change", 5, 900),
    ("POST", "/api/v1/auth/login"): Policy("auth-login", 10, 60),
    ("POST", "/api/v1/auth/refresh"): Policy("auth-refresh", 30, 60),
    ("POST", "/api/v1/auth/password-reset/request"): Policy("password-reset", 5, 900),
}


def policy_for(request: Request) -> Policy | None:
    path = request.url.path
    if path.startswith("/v1/"):
        path = "/api" + path
    direct = POLICIES.get((request.method, path))
    if direct:
        request.state.rate_limit_route = path
        return direct
    if request.method == "POST" and path.endswith("/attempts"):
        return Policy("assessment-start", 10, 300)
    if request.method == "POST" and path.endswith("/submission"):
        return Policy("assessment-submit", 20, 300)
    if request.method == "GET" and "/public/credentials/" in path:
        return Policy("credential-verify", 60, 60)
    if request.method == "GET" and path == "/api/v1/courses" and request.query_params.get("search"):
        return Policy("catalog-search", 60, 60, False)
    return None


def rate_limited(ttl: float) -> APIError:
    error = APIError(429, "RATE_LIMITED", "Too many requests. Try again later.")
    error.retry_after = max(1, math.ceil(ttl))
    return error


class LocalRateLimiter:
    """Bounded fixed windows; never evict active identities to admit new ones."""

    def __init__(self, max_entries=10_000, clock=time.monotonic):
        self.max_entries = max_entries
        self.clock = clock
        self.entries = {}
        self.expirations = []
        self.lock = asyncio.Lock()

    async def consume(self, key: str, policy: Policy) -> tuple[int, int]:
        async with self.lock:
            now = self.clock()
            while self.expirations and self.expirations[0][0] <= now:
                _, expired_key = heapq.heappop(self.expirations)
                del self.entries[expired_key]
            if key not in self.entries:
                if len(self.entries) >= self.max_entries:
                    # Conservatively reject new identities until a slot expires.
                    return policy.limit + 1, max(1, math.ceil(self.expirations[0][0] - now))
                expiry = now + policy.window_seconds
                self.entries[key] = (0, expiry)
                heapq.heappush(self.expirations, (expiry, key))
            count, expiry = self.entries[key]
            count = min(count + 1, policy.limit + 1)
            self.entries[key] = (count, expiry)
            return count, max(1, math.ceil(expiry - now))


class DistributedRateLimiter:
    def __init__(self, redis: Redis, settings: Settings):
        self.redis, self.settings = redis, settings
        self.local = LocalRateLimiter()
        self.clock = time.monotonic
        self.retry_at = 0.0
        self.probing = False
        self.log_times = {}
        self.degraded_operations = set()

    def report(self, operation: str, error: Exception | None = None) -> None:
        now = self.clock()
        degraded = error is not None
        if not degraded and operation not in self.degraded_operations:
            return
        if degraded:
            self.degraded_operations.add(operation)
        else:
            self.degraded_operations.discard(operation)
        event = "redis.degraded" if degraded else "redis.recovered"
        log_key = (operation, event)
        if now - self.log_times.get(log_key, float("-inf")) < 60:
            return
        self.log_times[log_key] = now
        logging.getLogger("learning_platform_api").log(
            logging.WARNING if degraded else logging.INFO,
            event,
            extra={
                "fields": {
                    "operation": operation,
                    "redis_required": self.settings.redis_required,
                    "exception_type": type(error).__name__ if error else None,
                    "fallback": "local" if not self.settings.redis_required else "disabled",
                }
            },
        )

    async def redis_ready(self) -> bool:
        try:
            async with asyncio.timeout(2):
                await self.redis.ping()
        except (RedisError, TimeoutError) as error:
            self.report("readiness", error)
            return False
        self.report("readiness")
        # Readiness probes must recover independently of student traffic.
        # PING does not prove EVAL/INCR permissions; limiter failures are logged separately.
        return True

    async def enforce(self, request: Request, policy: Policy) -> None:
        identity = self._identity(request)
        digest = hashlib.sha256(identity.encode()).hexdigest()[:32]
        key = f"{self.settings.redis_namespace}:rate:{policy.action}:{digest}"
        optional = not self.settings.redis_required
        local_result = await self.local.consume(key, policy) if optional else None
        # A single retry probe after a short cooldown avoids outage connection
        # storms. Healthy Redis requests retain their normal concurrent path.
        retrying = optional and self.retry_at > 0
        if retrying and (self.clock() < self.retry_at or self.probing):
            count, ttl = local_result
        else:
            if retrying:
                self.probing = True
            try:
                async with asyncio.timeout(2):
                    count, ttl = await self.redis.eval(
                        RATE_LIMIT_SCRIPT, 1, key, policy.window_seconds
                    )
                ttl = max(1, ttl)
                self.retry_at = 0.0
                self.report("rate_limit")
            except (RedisError, TimeoutError) as error:
                self.report("rate_limit", error)
                if optional:
                    self.retry_at = self.clock() + 5
                    count, ttl = local_result
                elif policy.fail_closed:
                    raise APIError(
                        503,
                        "RATE_LIMIT_UNAVAILABLE",
                        "The protected operation is temporarily unavailable.",
                    ) from error
                else:
                    return
            finally:
                if retrying:
                    self.probing = False
        if count > policy.limit:
            raise rate_limited(ttl)

    def _identity(self, request: Request) -> str:
        authorization = request.headers.get("Authorization", "")
        if authorization.startswith("Bearer "):
            try:
                return f"principal:{decode_token(authorization[7:]).get('sub')}"
            except jwt.PyJWTError:
                pass
        # Proxy trust is configured at Uvicorn's socket boundary. Never trust a
        # caller-supplied forwarded header here.
        return f"ip:{request.client.host if request.client else 'unknown'}"
