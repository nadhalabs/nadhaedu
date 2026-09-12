from types import SimpleNamespace

import pytest
from httpx import ASGITransport, AsyncClient
from redis.exceptions import ConnectionError as RedisConnectionError
from starlette.requests import Request

from app.config import Settings
from app.errors import APIError
from app.observability import Metrics, scrub_error_event
from app.rate_limit import DistributedRateLimiter, Policy, policy_for


def production_settings(**overrides):
    values = {
        "_env_file": None,
        "environment": "production",
        "jwt_secret": "j" * 48,
        "media_signing_secret": "m" * 48,
        "metrics_token": "t" * 48,
        "database_url": "postgresql+asyncpg://app:owner-secret@postgres.internal/app",
        "redis_url": "rediss://redis.internal/0",
        "redis_namespace": "app:production",
        "public_base_url": "https://api.example.com",
        "cors_origins": "https://app.example.com",
        "allowed_hosts": "api.example.com",
        "smtp_host": "smtp.example.com",
        "smtp_from_address": "security@example.com",
        "password_reset_url": "https://app.example.com/recover",
        "media_cdn_base_url": "https://media.example.com",
    }
    values.update(overrides)
    return Settings(**values)


def test_complete_production_configuration_is_valid():
    production_settings().validate_runtime()


@pytest.mark.parametrize(
    "override",
    [
        {"public_base_url": "http://api.example.com"},
        {"password_reset_url": "https://secret:password@app.example.com"},
        {"allowed_hosts": "*"},
        {"cors_origins": "*"},
        {"cors_origins": "http://app.example.com"},
        {"database_url": "postgresql+asyncpg://learning:learning@localhost/app"},
        {"metrics_token": "short"},
        {"media_signing_secret": "j" * 48},
        {"smtp_use_tls": False},
        {"redis_namespace": "app:development"},
    ],
)
def test_unsafe_production_configuration_is_rejected(override):
    with pytest.raises(ValueError):
        production_settings(**override).validate_runtime()


@pytest.mark.parametrize(
    "suffix", ["login", "refresh", "register", "password-reset/request", "password-reset/confirm"]
)
def test_auth_rate_limits_cover_both_api_prefixes(suffix):
    def policy(prefix):
        return policy_for(
            Request(
                {
                    "type": "http",
                    "method": "POST",
                    "path": prefix + "/auth/" + suffix,
                    "headers": [],
                }
            )
        )

    assert policy("/v1") == policy("/api/v1")
    assert policy("/v1") is not None


def test_forwarded_ip_cannot_change_rate_limit_identity():
    limiter = DistributedRateLimiter(None, Settings())
    request = SimpleNamespace(
        headers={"X-Forwarded-For": "attacker-chosen"}, client=SimpleNamespace(host="192.0.2.4")
    )
    assert limiter._identity(request) == "ip:192.0.2.4"


@pytest.mark.asyncio
async def test_redis_outage_fails_closed_for_auth_but_allows_search():
    class OfflineRedis:
        async def eval(self, *args):
            raise RedisConnectionError("private infrastructure detail")

    limiter = DistributedRateLimiter(OfflineRedis(), Settings())
    request = SimpleNamespace(headers={}, client=SimpleNamespace(host="192.0.2.4"))
    with pytest.raises(APIError) as failure:
        await limiter.enforce(request, Policy("login", 2, 60))
    assert failure.value.status == 503
    await limiter.enforce(request, Policy("search", 2, 60, False))


@pytest.mark.asyncio
async def test_validation_and_request_ids_never_echo_sensitive_input():
    from app.main import app

    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://testserver"
    ) as client:
        response = await client.post(
            "/api/v1/auth/login",
            headers={"X-Request-ID": "x" * 500},
            json={"email": "invalid", "password": "sensitive-reset-secret"},
        )
        assert response.status_code == 422
        assert "sensitive-reset-secret" not in response.text
        assert "input" not in response.text
        assert len(response.headers["x-request-id"]) <= 64
        assert response.headers["cache-control"] == "no-store"
        assert response.headers["x-content-type-options"] == "nosniff"


@pytest.mark.asyncio
async def test_unmatched_paths_share_one_metric_and_do_not_log_identifiers(caplog):
    from app.main import app

    app.state.metrics = Metrics()
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://testserver"
    ) as client:
        for index in range(12):
            assert (await client.get(f"/private-child-name-{index}")).status_code == 404
    assert len(app.state.metrics.requests) == 1
    assert "private-child" not in app.state.metrics.render()


def test_crash_transport_removes_personal_data_and_exception_values():
    event = {
        "request": {"data": "password"},
        "user": {"email": "child@example.test"},
        "breadcrumbs": ["token"],
        "extra": {"private": "data"},
        "exception": {
            "values": [
                {
                    "value": "SQL password",
                    "stacktrace": {"frames": [{"vars": {"token": "secret"}, "filename": "app.py"}]},
                }
            ]
        },
    }
    result = scrub_error_event(event, {})
    assert "password" not in str(result)
    assert "secret" not in str(result)
    assert "child@example" not in str(result)
    assert result["exception"]["values"][0]["stacktrace"]["frames"][0]["filename"] == "app.py"
