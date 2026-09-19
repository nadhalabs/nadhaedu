# Optional Redis for the Nadha Edu pilot

## Cause and repository audit

The reported `RATE_LIMIT_UNAVAILABLE` is the production middleware refusing protected requests when Redis EVAL fails. `NOT_READY` can additionally reflect PostgreSQL or migration failures; optional Redis must not hide those failures. Startup constructs a Redis client without connecting, so successful startup did not prove Redis availability.

Repository-wide Redis/Valkey search found these dependencies (no separate Valkey client):

| Dependency | Classification | Pilot behavior |
| --- | --- | --- |
| `app/rate_limit.py`: register, login, refresh, reset request/confirmation, password change | B: local fallback | Same policy limits, identity hashing, 429 and Retry-After |
| Same limiter: assessment start/submission, credential verification, catalog search | B: local fallback | Same fixed windows; optional-mode search is limited locally too |
| `app/main.py`: client lifecycle and public readiness | C: may degrade | Client retained; Redis outage alone no longer fails optional readiness |
| `app/cms_operations.py`: integration metadata and super-admin readiness | C: diagnostic | Live Redis status and required/optional mode; same migration authority as public readiness |
| `app/services.py` and CMS health screen | C: diagnostic | Removed hardcoded connected cache/old migration claims; dashboard marks runtime readiness unverified |
| `config.py`, `.env.example`, Python dependencies, Docker lifecycle | Configuration | Required defaults to true; valid production Redis URL/namespace checks remain |
| `ops/staging`, `ops/testing`, integration script and GitHub workflow | Deployment/test services | Remain Redis-enabled; no production infrastructure changes |
| Tests and historical operations/investigation documents | Verification/history | Existing distributed tests retained; this document describes the new opt-in behavior |

There are no Redis-backed sessions, authentication tokens, revocation records, password reset records, queues, CMS writes, learning progress, cache reads, idempotency locks or commerce records in the runtime code. These correctness/security paths remain PostgreSQL-backed (category A: cannot degrade) or use their existing independent provider integrations. Redis support is not removed.

The audit also found a stale password-change rate-limit path: the actual endpoint is `/api/v1/account/password-change`. It now shares the existing `password-change` policy (5/900 seconds) with the old path. Neither authentication nor password validation is bypassed.

## Explicit configuration

`LEARNING_PLATFORM_REDIS_REQUIRED` is a boolean in the existing Pydantic settings system. Its default is **true in every environment**. Staging/production continue to apply the existing rate-limit middleware; development/test activation behavior is unchanged.

For the temporary Render pilot, the only required environment change is:

```text
LEARNING_PLATFORM_REDIS_REQUIRED=false
```

Keep the existing `LEARNING_PLATFORM_REDIS_URL` and `LEARNING_PLATFORM_REDIS_NAMESPACE` configured. Do not replace them with placeholders, unset them, or paste credentials into logs. A syntactically valid production URL/namespace is still required; this option tolerates connectivity/service/Redis command failures, not malformed configuration. PostgreSQL URL, JWT/media secrets, allowed hosts, CORS, SMTP and all other existing production requirements remain unchanged.

Run **one application instance with one Uvicorn worker** during this pilot. The repository Docker command uses one worker. Verify the actual Render start command/instance count before rollout; multiple processes have separate fallback budgets. The option has no automatic expiry: schedule an operator review at two months or before scaling beyond the pilot. To restore mandatory Redis, make it healthy and set `LEARNING_PLATFORM_REDIS_REQUIRED=true` (or remove the override).

## Exact fallback behavior

- Healthy Redis remains authoritative and uses the existing atomic INCR/TTL/EXPIRE Lua script.
- Optional mode also tracks this process's attempts locally while Redis is healthy. An outage does not immediately grant a fresh local budget.
- Redis errors and timeouts switch optional requests to fixed-window local counters. Each Redis attempt has a two-second overall deadline. Following failure, requests use local counters for five seconds; then one incoming request probes Redis while concurrent requests continue locally. Recovery returns automatically to Redis.
- Counters are keyed by the same namespace, policy action and hashed identity. No token, email or raw IP is stored in the fallback table.
- An asyncio lock protects local updates. A monotonic clock determines windows. A heap removes expired entries on the next access; idle expired entries remain bounded until then.
- Both the table and expiry heap are capped at 10,000 active keys. Counters saturate at limit+1. At capacity, existing keys retain their budgets and new identities receive 429 until the earliest slot expires. No active entry is evicted to admit a new identity.
- Limit exhaustion returns `429 RATE_LIMITED` and a positive integer `Retry-After`, including under concurrent requests.
- Required mode preserves `503 RATE_LIMIT_UNAVAILABLE` for protected policies. Its existing catalog-search fail-open exception is unchanged.
- `redis.degraded` and `redis.recovered` events include only operation, mode and exception class. Each event/operation is throttled to once per minute, including flapping connections. Normal access logs continue per request; credentials and exception text are not logged.

## Readiness and migrations

Public readiness always requires PostgreSQL SELECT 1 and exactly the single Alembic head packaged with the running backend. `app/readiness.py` derives that head from Alembic's migration graph, independent of the working directory. Missing version tables, old revisions and multiple database revision rows fail readiness. Missing/branched migration graphs cannot be treated as ready. Include the `backend/alembic` directory when packaging (the existing Dockerfile does).

The current head is `0009_media_v1`. The shared helper replaces the public hardcoded head and CMS's stale `0008_academic_hierarchy`. The dashboard now reports the observed database revision instead of `0006_r3_query_indexes`; its lightweight summary explicitly leaves overall runtime readiness unverified. Use `/health/ready` or authenticated `/api/v1/admin/super/readiness` for live readiness.

With healthy PostgreSQL/schema and Redis offline:

- Optional: public HTTP 200, `{"status":"ready","redisStatus":"degraded"}`.
- Required: public HTTP 503, `NOT_READY`.

Healthy Redis reports `redisStatus: healthy`. Readiness uses bounded PING and recovers without waiting for a student request. PING alone cannot prove ACL permission for the limiter's EVAL/INCR/TTL/EXPIRE operations; those failures are separately logged by the limiter. CMS super readiness returns the same schema verdict plus `redisRequired` and `isReady`; its diagnostic response is not the public traffic-health contract.

## Security and availability trade-offs

This is process-local rate limiting, not a distributed replacement. A restart loses local counters. Replicas/workers, rolling deployment overlap and backend transitions may permit extra attempts; local and Redis window boundaries/counters are not synchronized or replayed. A response timeout may follow a successful Redis increment, conservatively charging an attempt twice across the two stores. Healthy Redis remains authoritative even if a local shadow counter is exhausted. Shared NATs/proxy identities can share budgets as before; retain correctly scoped proxy trust rather than trusting arbitrary forwarded headers.

Memory saturation fails with 429 instead of evicting active limits. This bounds resource consumption but can temporarily deny new identities during abuse. Keep monitoring enabled. Authentication, session validation/revocation, registration platform controls, database constraints, password checks and provider verification remain enforced. No current feature needs Redis for data correctness, but distributed limits still require it when running multiple processes or when mandatory mode is enabled.

No production data, Render settings or Redis service configuration was changed. No commit, push or deployment is part of this work.

## Files changed for this task

- `backend/app/config.py`: explicit required-by-default switch.
- `backend/app/rate_limit.py`: bounded fallback, cooldown/recovery, throttled sanitized events, actual password-change endpoint coverage.
- `backend/app/readiness.py`: shared Alembic graph/schema checks (new).
- `backend/app/main.py`: optional Redis readiness; PostgreSQL/schema remain mandatory.
- `backend/app/cms_operations.py`: consistent super-admin readiness.
- `backend/app/services.py`: truthful dashboard readiness summary.
- `backend/tests/test_optional_redis.py`: fallback/readiness/auth/recovery/concurrency/expiry/capacity/configuration tests (new).
- `backend/tests/test_schema_security.py`: test the migration authority rather than a hardcoded source string.
- `backend/tests/test_cms_admin.py`: verify dashboard does not claim unchecked readiness.
- `cms/lib/features/cms/presentation/screens/cms_system_health_screen.dart`: remove stale revision/active-cluster claims and correct limiter description.
- `backend/.env.example`: document default true and explicit pilot opt-in; placeholders only.
- `backend/README.md`: correct Redis requirements and link this guide.
- `docs/optional-redis-pilot.md`: audit, configuration, trade-offs and verification (new).

Pre-existing Android, student Flutter, root README/workflow and Android release-document changes were left untouched.

## Verification and deployment assessment

- Complete backend suite with fresh, isolated local PostgreSQL and Redis: **172 passed, zero skipped**. Includes existing distributed Redis, security, schema, concurrency and migration tests. Local services stopped automatically afterward.
- Without service URLs: 161 passed, 11 integration tests skipped.
- Fresh Alembic upgrade to `0009_media_v1` and `alembic check`: passed, no schema drift.
- Ruff lint on all changed/new Python files: passed. Whole-backend format check: all 54 files passed. Compileall and diff whitespace checks passed.
- Changed CMS Dart file format check: passed (no changes needed), using Dart's `--suppress-analytics` flag. The earlier wrapper/telemetry attempt was blocked by local filesystem permissions; the final direct check succeeded.
- Whole-backend lint retains 19 pre-existing findings in untouched files. They were not hidden or bulk-fixed. Integration execution emitted dependency deprecation warnings, with no failures.
- Suitable for the documented one-instance, one-worker pilot with the explicit opt-in and production smoke verification. This is not approval to scale with local limits or a claim that production has been tested. No migration is added by this change. Redis can remain unreachable during the pilot; PostgreSQL and the correct existing migration head must be healthy.
