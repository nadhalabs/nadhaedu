# Registration 503 investigation

## Root cause and limits of the evidence

For this checkout, there are two application-generated registration 503 paths:

| Code | Trigger | Stage |
| --- | --- | --- |
| `RATE_LIMIT_UNAVAILABLE` | Redis raises `RedisError` during the atomic rate-limit `EVAL` | Production/staging middleware, before routing, validation or PostgreSQL |
| `REGISTRATIONS_DISABLED` | Stored `registrations_enabled` is false | Inside registration, after routing and the settings query |

The supplied `route="unmatched", status=503` and 1–9 ms timing strongly indicate the first path. The middleware returns without calling the router, so the old logger cannot obtain `scope['route']`. A Redis connection refusal, authentication/ACL error, or immediate Redis command error can fail this quickly. Latency alone cannot distinguish causes. A false database flag is also fast, but does not explain an unmatched route with this implementation.

**Production response bodies, deployed revision, Redis configuration and database rows have not been inspected in this investigation.** The exact Redis failure and actual production flag value remain unverified. Do not change the flag on the strength of an HTTP status alone. Confirm the response code and inspect the row using the commands below.

## Complete request path

1. Render ingress/proxy forwards to Uvicorn. An ingress-generated 503 is outside this application and normally has no corresponding application `request.completed` event.
2. Outer correlation middleware assigns a request ID and starts observability. In production/staging, registration uses `Policy('auth-register', 5, 900)` for either API prefix. The limiter hashes the authenticated principal or socket peer IP and calls Redis `EVAL` with atomic INCR/TTL/EXPIRE. Redis errors fail closed with 503; exceeding the limit returns 429 with Retry-After. No PostgreSQL access occurs on this rejection.
3. CORS and production TrustedHost middleware run. Host/CORS rejection can return 400, not 503. CORS preflight is not registration.
4. FastAPI routes and validates the body and opens the SQLAlchemy session dependency. There is no readiness or maintenance middleware. `/health/ready` independently checks PostgreSQL, revision `0009_media_v1`, then Redis PING; its `NOT_READY` 503 does not directly gate registration. An external health-check policy may gate traffic independently.
5. Registration reads the boolean flag. Missing row means true; false raises `REGISTRATIONS_DISABLED`. `maintenance_mode` is not consulted here.
6. Check duplicate email (409), hash password, insert user, flush, create auth session, sign tokens, commit, return 201. Validation errors are 422. Unhandled DB connection/query/commit errors are sanitized to `INTERNAL_ERROR` 500, not 503. SMTP, commerce and media providers are not used.

Startup validates configuration and constructs Redis, but does not connect/ping it. Successful startup therefore does not prove Redis works. Redis PING readiness also does not prove the account can execute EVAL and its script commands.

## Settings provenance

- `api.platform_flag`: missing row defaults to true for registration.
- `cms_operations.SETTING_DEFINITIONS`: registration default is true. GET settings synthesizes defaults/version 0 and does not write them.
- `PlatformSetting.value`: non-null Boolean, no false Python/server default.
- Migration `0007_cms_phase34` creates an empty table. No migration inserts/updates this flag.
- Lifespan and Docker entrypoint do not initialize flags. `seed_staging` refuses production before touching the database and never writes platform settings. First-owner provisioning only updates the user's role.
- CMS bootstrap performs no settings writes. The controls screen sends PUT only after a switch interaction, confirmation and reason.
- The only repository production writer is the super-admin PUT endpoint. It checks expectedVersion, locks existing rows, updates value/version/actor, and commits an audit event in the same transaction. External/manual database changes cannot be excluded without production audit evidence.

No migration, default or registration safety behavior has been changed. Existing intentional administrator settings must remain intact.

## Changes

API error handling now records the error code and sanitized cause class in request state for completion logs. The limiter supplies a bounded route label from its fixed policy allowlist, so early auth rejections identify `/api/v1/auth/register` (the legacy alias uses the same label). Arbitrary URL paths, exception messages, credentials and request bodies are not logged. Fail-closed behavior is preserved.

Tests cover missing/true/false flag behavior with production limiting, repeated production lifespan and CMS reads preserving state, committed users, audited false-to-true changes, production seed refusal, Redis unavailable/healthy/exhausted behavior, both route prefixes, rejection before DB access, and sanitized logging.

## Exact production diagnostics (operator-run)

Run in the deployed backend directory in a Render shell. These checks do not change platform settings. Never paste connection strings or tokens into an incident report.

```sh
python - <<'PY'
import asyncio
import json
from sqlalchemy import text
from app.db import session_factory

async def main():
    factory = session_factory()
    try:
        async with factory() as db:
            await db.execute(text('SET TRANSACTION READ ONLY'))
            for label, query in [
                ('migration', 'SELECT version_num FROM alembic_version'),
                ('registration setting', "SELECT key, value, version, updated_at, updated_by FROM platform_settings WHERE key = 'registrations_enabled'"),
                ('registration audit', "SELECT occurred_at, actor_id, event_type, data FROM audit_events WHERE subject_type = 'platform_setting' AND subject_id = 'registrations_enabled' ORDER BY occurred_at DESC LIMIT 20"),
            ]:
                rows = (await db.execute(text(query))).mappings().all()
                print(label, json.dumps([dict(row) for row in rows], default=str))
    finally:
        await factory.kw['bind'].dispose()
asyncio.run(main())
PY
```

An empty settings result means enabled. If the row is false, review `updated_by` and audit reason/version before deciding to reverse it.

This read-only Redis probe checks connection/authentication and permission to invoke EVAL without touching keys (it does not exercise INCR/EXPIRE):

```sh
python - <<'PY'
import asyncio
from redis.asyncio import Redis
from app.config import get_settings

async def main():
    r = Redis.from_url(get_settings().redis_url, socket_connect_timeout=2, socket_timeout=2)
    try:
        for label, call in [('PING', lambda: r.ping()), ('EVAL', lambda: r.eval('return 1', 0))]:
            try:
                print(label, await call())
            except Exception as error:
                print(label, type(error).__name__)  # No credential-bearing exception text.
    finally:
        await r.aclose()
asyncio.run(main())
PY
```

From your shell, set the actual backend origin, then check readiness and make one intentionally invalid registration request. This cannot create an account, but uses one rate-limit attempt if Redis works:

```sh
export API_BASE='https://nadhaedu-api.onrender.com'
curl -sS -i "$API_BASE/health/ready"
curl -sS -i -X POST "$API_BASE/api/v1/auth/register" \
  -H 'Content-Type: application/json' \
  -H 'X-Request-ID: registration-diagnostic' --data '{}'
```

`RATE_LIMIT_UNAVAILABLE` confirms the pre-routing Redis path. `422 VALIDATION_FAILED` confirms middleware allows the request; the invalid body deliberately does not exercise the flag. `429` means the window is exhausted; wait for Retry-After. Use the DB query to determine the flag independently.

## Conditional remediation (not executed)

If Redis fails, correct the actual `LEARNING_PLATFORM_REDIS_URL`/credentials/TLS/network access or Redis ACL/service problem identified by the probes. The deployed Redis account needs EVAL and the script's INCR, TTL and EXPIRE commands plus access to the configured namespace. Check these with the Redis administrator; do not disable limiting, weaken TLS, or blindly retry registration. No exact infrastructure change is justified until the failure is identified.

If and only if the setting is false and re-enabling is approved, use the supported super-admin API, preserving the version and audit trail. These are reversible setting changes, not destructive SQL. Supply an existing super-admin access token privately in `SUPER_ADMIN_TOKEN`; do not create a token in source code. Read the current version:

```sh
curl --fail-with-body -sS "$API_BASE/api/v1/admin/super/settings" \
  -H "Authorization: Bearer $SUPER_ADMIN_TOKEN"
```

Set `SETTING_VERSION` to the returned integer for `registrations_enabled`. After review/approval of the previous reason, run:

```sh
export SETTING_VERSION=1  # Replace with the actual current version; never assume 1.
curl --fail-with-body -sS -X PUT \
  "$API_BASE/api/v1/admin/super/settings/registrations_enabled" \
  -H "Authorization: Bearer $SUPER_ADMIN_TOKEN" \
  -H 'Content-Type: application/json' \
  --data "{\"value\":true,\"expectedVersion\":$SETTING_VERSION,\"reason\":\"Approved restoration of learner registration after incident review\"}"
```

A 409 requires re-reading and reviewing the concurrent change, not force-overwriting it. GET again to verify true and the incremented version; inspect the audit query above. Do not UPDATE or DELETE the row directly. No production mutation, commit, push, deployment or Render configuration change was performed here.

## Verification results

- Focused registration/CMS/hardening suite: 39 passed, including maintenance_mode=true not blocking registration and logged disabled-setting reason.
- Full backend suite with isolated local PostgreSQL and Redis: 143 passed, zero skipped. The final additional maintenance/logging assertions were then verified by rerunning the 39 focused tests.
- Fresh Alembic upgrade through `0009_media_v1`: passed. `alembic check`: no new upgrade operations detected.
- Ruff check on all five touched Python files: passed. Whole-backend format check: 52 files already formatted. Compileall and git diff whitespace checks: passed.
- Whole-backend Ruff lint still reports 21 pre-existing findings in untouched files (imports, unused imports, unnecessary dict constructors). These unrelated files were not rewritten.
- Integration run emitted pytest-asyncio deprecation warnings under the execution environment's Python 3.14; no test failures.
- Local test services were stopped after verification. Production was neither contacted nor changed.
