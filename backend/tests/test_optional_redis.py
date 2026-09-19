import asyncio
from contextlib import asynccontextmanager
from types import SimpleNamespace
from unittest.mock import AsyncMock, Mock

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from redis.exceptions import ConnectionError as RedisConnectionError
from sqlalchemy import text
from sqlalchemy.exc import OperationalError
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool
from test_hardening import production_settings

from app import main
from app.config import Settings
from app.db import get_session
from app.errors import APIError
from app.models import Base
from app.rate_limit import POLICIES, DistributedRateLimiter, LocalRateLimiter, Policy
from app.readiness import expected_migration_head


def request(identity="192.0.2.1"):
    return SimpleNamespace(headers={}, client=SimpleNamespace(host=identity))


def redis_client(available):
    return SimpleNamespace(
        eval=AsyncMock(
            return_value=[1, 60], side_effect=None if available else RedisConnectionError("private")
        ),
        ping=AsyncMock(
            return_value=True, side_effect=None if available else RedisConnectionError("private")
        ),
        aclose=AsyncMock(),
    )


@pytest.mark.parametrize("required", [True, False])
@pytest.mark.parametrize("available", [True, False])
@pytest.mark.asyncio
async def test_required_optional_matrix(required, available):
    redis = redis_client(available)
    limiter = DistributedRateLimiter(redis, Settings(_env_file=None, redis_required=required))
    policy = Policy("login", 1, 60)
    if required and not available:
        with pytest.raises(APIError) as failure:
            await limiter.enforce(request(), policy)
        assert failure.value.status == 503
        assert failure.value.code == "RATE_LIMIT_UNAVAILABLE"
    else:
        await limiter.enforce(request(), policy)
        if not available:
            with pytest.raises(APIError) as failure:
                await limiter.enforce(request(), policy)
            assert failure.value.status == 429
            assert failure.value.retry_after > 0
    assert redis.eval.await_count == 1


@pytest.mark.asyncio
async def test_local_concurrency_expiry_and_bounded_capacity():
    clock = [0.0]
    local = LocalRateLimiter(max_entries=2, clock=lambda: clock[0])
    policy = Policy("register", 5, 10)
    results = await asyncio.gather(*(local.consume("a", policy) for _ in range(100)))
    assert sum(count <= 5 for count, ttl in results) == 5
    assert all(ttl == 10 for count, ttl in results)
    await local.consume("b", policy)
    for n in range(100):
        count, ttl = await local.consume(f"new-{n}", policy)
        assert count > policy.limit and ttl == 10
    assert len(local.entries) == len(local.expirations) == 2
    clock[0] = 10
    assert await local.consume("new", policy) == (1, 10)
    assert list(local.entries) == ["new"]
    assert len(local.expirations) == 1


@pytest.mark.asyncio
async def test_recovery_cooldown_and_retained_local_budget(monkeypatch):
    redis = redis_client(True)
    limiter = DistributedRateLimiter(redis, Settings(_env_file=None, redis_required=False))
    clock = [1.0]
    limiter.clock = limiter.local.clock = lambda: clock[0]
    policy = Policy("register", 3, 60)
    logger = Mock()
    monkeypatch.setattr(
        "app.rate_limit.logging", SimpleNamespace(getLogger=lambda _: logger, WARNING=30, INFO=20)
    )
    await limiter.enforce(request(), policy)  # Shadow healthy traffic locally.
    redis.eval.side_effect = RedisConnectionError("private")
    await limiter.enforce(request(), policy)
    await limiter.enforce(request(), policy)
    with pytest.raises(APIError) as failure:
        await limiter.enforce(request(), policy)
    assert failure.value.status == 429
    assert redis.eval.await_count == 2
    clock[0] += 5
    redis.eval.side_effect = None
    await limiter.enforce(request(), policy)  # Redis is authoritative after recovery.
    assert redis.eval.await_count == 3
    assert limiter.retry_at == 0
    assert "rate_limit" not in limiter.degraded_operations
    redis.eval.side_effect = RedisConnectionError("private")
    with pytest.raises(APIError) as failure:
        await limiter.enforce(request(), policy)
    assert failure.value.status == 429  # Returning to fallback does not clear its budget.
    assert "private" not in str(logger.mock_calls)
    assert [c.args[1] for c in logger.log.call_args_list] == ["redis.degraded", "redis.recovered"]


@pytest.mark.asyncio
async def test_only_one_recovery_probe_and_cancellation_releases_it():
    redis = redis_client(False)
    limiter = DistributedRateLimiter(redis, Settings(_env_file=None, redis_required=False))
    policy = Policy("login", 10, 60)
    await limiter.enforce(request(), policy)
    limiter.retry_at = limiter.clock() - 1
    entered = asyncio.Event()
    release = asyncio.Event()

    async def blocked(*args):
        entered.set()
        await release.wait()
        return [1, 60]

    redis.eval.side_effect = blocked
    probe = asyncio.create_task(limiter.enforce(request("probe"), policy))
    await entered.wait()
    await asyncio.gather(*(limiter.enforce(request(str(i)), policy) for i in range(20)))
    assert redis.eval.await_count == 2
    probe.cancel()
    with pytest.raises(asyncio.CancelledError):
        await probe
    assert limiter.probing is False
    redis.eval.side_effect = None
    await limiter.enforce(request("recovered"), policy)
    assert limiter.retry_at == 0


@pytest.mark.asyncio
async def test_optional_timeout_and_search_are_locally_limited():
    redis = redis_client(True)
    redis.eval.side_effect = TimeoutError()
    limiter = DistributedRateLimiter(redis, Settings(_env_file=None, redis_required=False))
    policy = Policy("search", 1, 60, False)
    await limiter.enforce(request(), policy)
    with pytest.raises(APIError) as failure:
        await limiter.enforce(request(), policy)
    assert failure.value.status == 429


@pytest_asyncio.fixture
async def pilot(monkeypatch):
    engine = create_async_engine("sqlite+aiosqlite:///:memory:", poolclass=StaticPool)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
        await conn.execute(text("CREATE TABLE alembic_version (version_num VARCHAR(64))"))
        await conn.execute(
            text("INSERT INTO alembic_version VALUES (:head)"), {"head": expected_migration_head()}
        )
    factory = async_sessionmaker(engine, expire_on_commit=False)
    settings = production_settings(redis_required=False)
    redis = redis_client(False)
    monkeypatch.setattr(main, "settings", settings)
    monkeypatch.setattr(main, "session_factory", lambda: factory)
    monkeypatch.setattr(main.app.state, "settings", settings)
    monkeypatch.setattr(main.app.state, "rate_limiter", DistributedRateLimiter(redis, settings))

    async def session():
        async with factory() as db:
            yield db

    main.app.dependency_overrides[get_session] = session
    try:
        async with AsyncClient(
            transport=ASGITransport(app=main.app), base_url="https://api.example.com"
        ) as client:
            yield client, factory, settings, redis
    finally:
        main.app.dependency_overrides.pop(get_session, None)
        await engine.dispose()


@pytest.mark.asyncio
@pytest.mark.parametrize("required", [False, True])
@pytest.mark.parametrize("available", [False, True])
async def test_readiness_matrix(pilot, required, available):
    client, _, settings, redis = pilot
    settings.redis_required = required
    redis.ping.side_effect = None if available else RedisConnectionError("private")
    response = await client.get("/health/ready")
    assert response.status_code == (503 if required and not available else 200)
    if response.status_code == 200:
        assert response.json()["redisStatus"] == ("healthy" if available else "degraded")
    else:
        assert response.json()["error"]["code"] == "NOT_READY"
    assert "private" not in response.text


@pytest.mark.asyncio
@pytest.mark.parametrize("revision", ["old", None, "extra"])
async def test_optional_redis_does_not_mask_migration_failures(pilot, revision):
    client, factory, _, redis = pilot
    async with factory() as db:
        if revision == "old":
            await db.execute(text("UPDATE alembic_version SET version_num='old'"))
        elif revision is None:
            await db.execute(text("DROP TABLE alembic_version"))
        else:
            await db.execute(text("INSERT INTO alembic_version VALUES ('extra')"))
        await db.commit()
    response = await client.get("/health/ready")
    assert response.status_code == 503
    assert response.json()["error"]["code"] == "NOT_READY"
    redis.ping.assert_not_awaited()


@pytest.mark.asyncio
async def test_optional_redis_does_not_mask_database_failure(pilot, monkeypatch):
    client, _, _, redis = pilot

    @asynccontextmanager
    async def broken():
        raise OperationalError("private query", {}, Exception("secret"))
        yield

    monkeypatch.setattr(main, "session_factory", lambda: broken)
    response = await client.get("/health/ready")
    assert response.status_code == 503
    assert response.json()["error"]["code"] == "NOT_READY"
    assert "secret" not in response.text
    redis.ping.assert_not_awaited()


@pytest.mark.asyncio
async def test_registration_login_and_refresh_work_with_fallback(pilot):
    client, _, _, _ = pilot
    body = {"email": "pilot@example.com", "password": "PilotPass123!", "displayName": "Pilot"}
    registration = await client.post("/api/v1/auth/register", json=body)
    assert registration.status_code == 201
    login = await client.post("/api/v1/auth/login", json=body)
    assert login.status_code == 200
    refreshed = await client.post(
        "/api/v1/auth/refresh", json={"refreshToken": login.json()["refreshToken"]}
    )
    assert refreshed.status_code == 200
    # Existing account attempts are still charged to the registration budget.
    for _ in range(4):
        assert (await client.post("/api/v1/auth/register", json=body)).status_code == 409
    limited = await client.post("/api/v1/auth/register", json=body)
    assert limited.status_code == 429
    assert limited.json()["error"]["code"] == "RATE_LIMITED"
    assert int(limited.headers["Retry-After"]) > 0


@pytest.mark.asyncio
@pytest.mark.parametrize("path", [path for method, path in POLICIES])
async def test_all_fixed_auth_policies_enforced_by_optional_fallback(pilot, path):
    client, _, _, _ = pilot
    policy = POLICIES[("POST", path)]
    for _ in range(policy.limit):
        response = await client.post(path, json={})
        assert response.status_code in ({404} if path == "/api/v1/account/password" else {401, 422})
    response = await client.post(path, json={})
    assert response.status_code == 429
    assert response.json()["error"]["code"] == "RATE_LIMITED"
    assert 1 <= int(response.headers["Retry-After"]) <= policy.window_seconds


def test_default_required_and_environment_opt_in(monkeypatch):
    monkeypatch.delenv("LEARNING_PLATFORM_REDIS_REQUIRED", raising=False)
    assert Settings(_env_file=None).redis_required is True
    monkeypatch.setenv("LEARNING_PLATFORM_REDIS_REQUIRED", "false")
    assert Settings(_env_file=None).redis_required is False
    production_settings(redis_required=False).validate_runtime()


@pytest.mark.asyncio
async def test_startup_succeeds_and_readiness_recovers_without_auth_traffic(pilot, monkeypatch):
    client, factory, settings, redis = pilot
    for name in ("logger", "metrics", "redis", "password_reset_delivery"):
        monkeypatch.setattr(main.app.state, name, getattr(main.app.state, name))
    monkeypatch.setattr(main.Redis, "from_url", Mock(return_value=redis))
    monkeypatch.setattr(main, "session_factory", Mock(return_value=factory))
    async with main.lifespan(main.app):
        assert (await client.get("/health/ready")).status_code == 200
        assert main.app.state.rate_limiter.settings.redis_required is False
        settings.redis_required = True
        assert (await client.get("/health/ready")).status_code == 503
        redis.ping.side_effect = None
        assert (await client.get("/health/ready")).status_code == 200
    redis.aclose.assert_awaited_once()


@pytest.mark.asyncio
@pytest.mark.parametrize("required", [True, False])
async def test_cms_and_public_readiness_use_actual_head(pilot, required):
    from app.cms_operations import system_readiness

    client, factory, settings, _ = pilot
    settings.redis_required = required
    async with factory() as db:
        result = await system_readiness(SimpleNamespace(app=main.app), None, db)
        assert result["requiredMigrationHead"] == expected_migration_head()
        assert result["currentMigrationHead"] == expected_migration_head()
        assert result["schemaReady"] is True
        assert result["redisRequired"] is required
        assert result["isReady"] is (not required)
        await db.execute(text("UPDATE alembic_version SET version_num='stale'"))
        await db.commit()
        result = await system_readiness(SimpleNamespace(app=main.app), None, db)
        assert result["schemaReady"] is False
        assert result["isReady"] is False
    assert (await client.get("/health/ready")).status_code == 503


@pytest.mark.asyncio
async def test_migration_head_discovery_tracks_new_migrations_and_rejects_multiple_heads(
    monkeypatch, tmp_path
):
    from alembic.script import ScriptDirectory

    from app import readiness

    versions = tmp_path / "versions"
    versions.mkdir()
    (versions / "first.py").write_text("revision = 'first'\ndown_revision = None\n")
    monkeypatch.setattr(readiness, "ScriptDirectory", lambda _: ScriptDirectory(str(tmp_path)))
    readiness.expected_migration_head.cache_clear()
    try:
        assert readiness.expected_migration_head() == "first"
        (versions / "second.py").write_text("revision = 'second'\ndown_revision = 'first'\n")
        readiness.expected_migration_head.cache_clear()  # A new deployment starts a new process.
        assert readiness.expected_migration_head() == "second"
        (versions / "branch.py").write_text("revision = 'branch'\ndown_revision = 'first'\n")
        readiness.expected_migration_head.cache_clear()
        with pytest.raises(RuntimeError, match="Exactly one Alembic head"):
            readiness.expected_migration_head()
    finally:
        readiness.expected_migration_head.cache_clear()
