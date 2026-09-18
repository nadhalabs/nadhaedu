import hashlib
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


class DistributedRateLimiter:
    def __init__(self, redis: Redis, settings: Settings):
        self.redis, self.settings = redis, settings

    async def enforce(self, request: Request, policy: Policy) -> None:
        identity = self._identity(request)
        digest = hashlib.sha256(identity.encode()).hexdigest()[:32]
        key = f"{self.settings.redis_namespace}:rate:{policy.action}:{digest}"
        try:
            count, ttl = await self.redis.eval(RATE_LIMIT_SCRIPT, 1, key, policy.window_seconds)
            ttl = max(1, ttl)
        except RedisError as error:
            if policy.fail_closed:
                raise APIError(
                    503,
                    "RATE_LIMIT_UNAVAILABLE",
                    "The protected operation is temporarily unavailable.",
                ) from error
            return
        if count > policy.limit:
            failure = APIError(429, "RATE_LIMITED", "Too many requests. Try again later.")
            failure.retry_after = ttl
            raise failure

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
