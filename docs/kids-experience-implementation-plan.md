# Kids experience and production hardening — implementation plan

Audit date: 2026-09-09. This is an existing Flutter/Riverpod/GoRouter student app, independent Flutter CMS, and modular FastAPI/SQLAlchemy backend. No AGENTS.md, Sites configuration, or Git metadata exists in the supplied folder. A source snapshot was preserved outside the workspace for change review.

## Repository audit and evidence

- Inspected feature/domain/data/application/presentation boundaries, routing, auth stores, adapters, catalog caches, learning outbox, download manager, assessments, entitlements, certificates, notifications, settings, native projects, backend routes/services/models, seven migrations, security/operations tests, CI, Compose, backup scripts, and readiness/contract documents.
- Preserve existing authority boundaries, learner-partitioned progress/downloads, unique constraints, server grading, private media tokens and fail-closed provider integrations.
- Theme is a minimal seed color; preferences for reduced motion/high contrast are stored but unused at the root. Navigation recreates the router on every auth state change. Home renders equal-weight server rails without a primary next action. Repeated course artwork is a generic gradient.
- Assessment start has no in-flight guard. Retrying submission reloads the intro; a new submission recomputes timestamps despite retaining its idempotency key. Summary-fetch/callback failures can mask a committed result. Learning completion toggles and late player callbacks can target newly selected content.
- Both app bootstraps inject an unconfigured Dio(), bypassing configured base URL/timeouts. Refresh storage updates do not notify the auth controller of authoritative invalidation.
- Backend legacy /v1 auth routes bypass exact rate-limit policies. Forwarded IP is trusted in both middleware and container wildcard proxy configuration. INCR/EXPIRE is non-atomic. Refresh/reset token consumption lacks row locks. Duplicate progress IDs within one batch aren't added to the seen map. Default validation responses can echo input, and unexpected exceptions lack a safe envelope. Metrics use arbitrary unmatched paths as labels.
- Release Android uses debug signing. CI omits CMS and dependency manifests disagree. .gitignore omits environment files/signing keys. Existing readiness docs contain obsolete migration and capability claims.

## Execute in order

1. Establish repeatable baseline; use installed PostgreSQL/Redis if runnable, otherwise record exact blockers. Preserve test failures as baseline evidence.
2. Add shared semantic theme, motion, accessible feedback, progress, art and celebration components; apply throughout navigation and core learning screens; fix assessment/lesson races and resilient retries.
3. Harden both API clients, auth expiration, backend configuration/errors/rate limits/token transactions/progress idempotency, native release setup, privacy defaults, integration infrastructure and CI. Add focused regression tests for demonstrated faults.
4. Resolve dependencies, format/analyze/test/build student and CMS, lint/test/migrate backend, execute real dependency/concurrency tests, inspect screen renders and source differences; document exact evidence, limitations and owner gates.

No provider credentials, signed release, physical-device performance, SMTP delivery, legal compliance or deployed infrastructure will be called verified without execution.
