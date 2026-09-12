# Phase C operations-readiness report

Date: 2026-08-31

Decision: **NO-GO for production**. The repository-owned controls are implemented and locally verified, but no real staging host, DNS/TLS, object store/CDN, transactional email account, Sentry project, CI credentials, Android device, or iOS device was supplied. Those are release gates; this report does not substitute local simulation for external evidence.

## Delivered controls

- Isolated staging topology: API, PostgreSQL 16, Redis 7 with AOF, persistent volumes, and staging-only Mailpit capture in `ops/staging/compose.yaml`. The API image runs as a non-root user.
- Runtime validation rejects staging/production startup with development defaults, localhost URLs, missing delivery/metrics configuration, or short signing keys. Auth and media keys are separate.
- Password reset uses a cryptographically random, hashed, 15-minute, single-use token; known and unknown accounts receive the same response; successful reset revokes existing sessions. SMTP delivery is behind a provider-neutral interface.
- Protected media is represented by `media_assets`; playback and renewal require centralized lesson access and return short-lived, learner/asset/lesson/course-bound HMAC authorization. Raw origin keys are never returned.
- Redis-backed fixed-window limits cover login, refresh, reset, assessment start/submission, public credential checks, and search. Security operations fail closed when Redis is unavailable; search degrades open. Keys contain hashed identity, not email or bearer tokens.
- JSON request logs include environment, request ID, route, status, and latency without bodies, credentials, or tokens. Sentry is enabled when a DSN is injected, with default PII disabled. Authenticated Prometheus-format metrics and live/ready probes are available.
- Readiness verifies database connectivity, exact Alembic revision `0002_operations`, and Redis. Liveness has no dependency checks.
- CI gates Flutter format/analyze/test/staging web build and backend format/lint/compile/migration/PostgreSQL tests/container build. Deployment is intentionally absent until a target and credentials exist.

## Evidence recorded locally

- Alembic head: `0002_operations`.
- Staging seed: three representative course shapes and six personas, including free, premium, expired, assessment, certificate, and admin cases. It refuses production and requires explicit opt-in plus a test password.
- PostgreSQL backup/restore drill: custom-format dump validated by `pg_restore --list`, restored into isolated `learning_platform_restore_test`; 15 users, 11 courses, and zero orphan lessons were verified. The first attempt correctly failed on a PostgreSQL 15 client/16 server mismatch; scripts now accept an explicit `POSTGRES_BIN`, and the rerun passed.
- Python formatting, Ruff lint, and byte compilation pass. Backend test and Flutter results belong in the final handoff after the last run.

## Secrets and access operations

The example environment file contains placeholders only and must never be copied with real values into source control. Store PostgreSQL, Redis, JWT, media-signing, SMTP, metrics, and Sentry values in the deployment platform's secret manager. Grant read access only to the API runtime and release operators. Rotate JWT/media keys by deploying new keys during a planned session/media-token invalidation window; rotate database/Redis/SMTP credentials in their providers first, update the secret manager, then roll the API. Record owner, timestamp, and validation result in the incident log. Emergency response is to revoke the exposed credential, rotate it, restart workloads, invalidate affected sessions, and review request/audit logs.

## Backup, recovery, and durability

Target RPO: 24 hours; target RTO: 4 hours until production traffic evidence establishes tighter needs. Run `backup_postgres.sh` daily to encrypted, versioned, cross-zone object storage with 30 daily and 12 monthly copies. Run `verify_restore.sh` against an isolated database monthly and before destructive schema changes. PostgreSQL and Redis volumes in Compose are durable only on one host; production requires managed multi-zone PostgreSQL with point-in-time recovery and Redis appropriate to the accepted rate-limit availability policy. User-uploaded media must use versioned object storage; the API stores only origin keys.

## Required external verification before GO

1. Deploy the exact container and migrations to a real, isolated staging environment; prove TLS, CORS, DNS, network restrictions, non-public database/Redis, readiness, metrics authentication, log ingestion, and a captured Sentry event.
2. Configure a real staging mail sender and prove delivery, expired/malformed/reused reset rejection, uniform unknown-user behavior, session revocation, and no token leakage in logs.
3. Configure private object storage/CDN and prove entitled playback, unauthorized denial, asset/learner mismatch denial, expiry, renewal, seek/resume, subtitle and download policy, and origin-key privacy.
4. Execute the full learner matrix on physical Android and iOS devices: onboarding, catalog/search, free/premium/expired access, lesson progression, resources, timed assessment resume/expiry/submission, credential issuance and public verification, password reset, offline/reconnect, app restart, token refresh/revocation, and forced errors.
5. Run representative staging load tests and record p50/p95/p99, throughput, error rate, saturation, connection-pool use, slow queries/query plans, and rate-limit behavior across at least two API instances. Define alert thresholds from measured baselines.
6. Exercise dependency failures (database, Redis, SMTP, media/CDN, observability) and demonstrate documented graceful/fail-closed behavior and recovery.
7. Configure protected CI environments, approval gates, deployment, migration policy, smoke tests, rollback, and artifact traceability. Run one full deploy and one rollback drill.

The legacy `/v1` alias remains deprecated with a 2027-08-31 sunset because no inventory of deployed clients/integrations was available. Remove it only after access logs show zero use for an agreed observation window and every supported client uses `/api/v1`.
