# Phase B production integration

## Environment and startup

Entry points are `main_development.dart`, `main_staging.dart`, and `main.dart` (production). Build staging/production with an HTTPS origin:

```bash
flutter run -t lib/main_staging.dart --dart-define=API_BASE_URL=https://staging-api.example.com
flutter build appbundle -t lib/main.dart --dart-define=API_BASE_URL=https://api.example.com
```

Missing staging/production configuration fails closed. Flutter contains only public origin configuration—never backend secrets.

## Authentication and resilience

Sessions are stored only through platform secure storage. Bootstrap validates an unexpired local session with `/auth/me`; expired sessions rotate through `/auth/refresh`. The shared Dio boundary attaches access tokens, coalesces simultaneous refresh attempts, persists rotation before retry, and clears secure state only when refresh authority confirms revocation/expiry. Offline, timeout, 5xx and malformed responses remain distinguishable and do not erase recoverable refresh material.

Backend errors map from the typed `{error:{code,message,field?,requestId}}` envelope into `ApiFailure`. Correlation IDs remain diagnostic metadata rather than user-facing content.

## Cache, progress and access

Catalog repository caches remain bounded and provide stale content during transient outages. Learning progress keeps its bounded, learner-isolated outbox and 30-second synchronization throttle. Repeated mutation IDs are replay-safe; server snapshots/revisions remain the baseline across devices.

Course and active-lesson views request server-issued access decisions in staging/production, falling back to a stale local projection for presentation only. Opening playback always calls the protected backend endpoint, so an expired/revoked cached grant cannot disclose a stream.

## Staging backend and PostgreSQL

Required backend environment values are documented in `backend/.env.example`. Use non-production accounts/data, a dedicated PostgreSQL database, exact CORS origins, TLS, and a 32-byte-or-longer JWT secret. Apply `alembic upgrade head` as a deployment job before application rollout.

The local Phase B validation used PostgreSQL 16.14 and database `learning_platform_phase_b`. Migration from zero produced 27 public tables and revision `0001_phase_a`. PostgreSQL-backed tests cover final-attempt allocation and duplicate certificate context races; the HTTP contract test covers registration/login, correlation IDs, refresh rotation, old-session revocation, catalog, entitlements, and the compatibility alias.

## Compatibility removal plan

All Flutter production adapters now use `/api/v1`. Backend `/v1` remains a compatibility alias for already-distributed builds and emits `Deprecation`, `Sunset: 31 Aug 2027`, and successor-version `Link` headers. Monitor alias traffic by path/version; remove it only after supported client versions no longer use it and the sunset has passed.

## Performance and security findings

- Catalog/search remain cursor-paged and server-filtered; course lists deliberately use cached access projections to avoid an entitlement request per card. Server decisions are fetched for the course gate and current lesson only.
- Video progress stays locally checkpointed and batches remote synchronization rather than sending playback ticks.
- Refresh requests are single-flight, avoiding token-rotation races and duplicate retry storms.
- No tokens are logged. Cross-user authority comes from sessions, not body/query learner IDs. Assessment deadlines and grading remain server-owned. Public certificate identifiers are random and production never generates `DEV-*` credentials.
- PostgreSQL live testing found and fixed a missing Alembic transaction wrapper. It also led to explicit progress and certificate advisory-lock scopes in addition to uniqueness constraints.

## Validation and limitations

Validated: Dart formatting, zero-issue Flutter analysis, all 111 Flutter tests, Ruff formatting/linting, eight backend tests, PostgreSQL migration from zero, live concurrency tests, OpenAPI/canonical HTTP contract, fixture isolation, session rotation, bounded pagination and compatibility headers.

Remaining deployment integrations are operational rather than commerce work: connect password-reset code delivery through a notification provider; connect the signed playback URL to a real media origin/validator; seed staging catalog/enrollment/assessment data; and run device-level staging smoke tests against the deployed HTTPS origin. Distributed edge rate limiting and production observability also remain deployment prerequisites.

Phase 7 should not begin until those staging smoke tests, reset delivery, media signing/origin integration, rate limiting, secrets/KMS, backups/PITR and operational dashboards are complete.

