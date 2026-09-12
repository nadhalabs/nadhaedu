# Backend Phase A implementation report

## Delivered architecture and contracts

The new `backend/` service uses FastAPI, Pydantic, SQLAlchemy 2, PostgreSQL and Alembic. It separates configuration/database/security/dependencies, transport schemas/routes, central domain services, and persistence models. Canonical paths are `/api/v1`; existing assessment/certificate `/v1` calls remain supported as a compatibility alias. The audited endpoint/error/idempotency matrix is in `backend-contract-matrix.md`.

The initial migration covers users, revocable multi-device sessions, catalog hierarchy and taxonomy, enrollments, primitive lesson progress and deduplicated mutations, bookmarks, access policies, scoped entitlements, assessments/questions/options/attempts/responses, idempotency records, certificates/revocations and audit events. Important owner/resource, pagination and resolution indexes plus uniqueness/check constraints are declared in metadata.

## Authority lifecycles

Access is resolved centrally using inherited Course → Module → Lesson policy, request-time grant validity and deterministic source precedence. No client learner ID or entitlement claim is trusted.

Assessment start checks access and atomically allocates a server attempt number. The server owns start/deadline, returns safe questions without `grading_data`, locks on submission, validates ownership/references/types, grades privately and persists one result. An idempotency record binds principal, operation and key to a canonical fingerprint and replay result.

Certificate eligibility derives active enrollment, primitive lesson completion, required assessment passes and current course access. Issuance uses opaque random credentials and a learner/course uniqueness constraint. History uses bounded stable keyset pagination. Public verification returns a privacy-minimized projection. Admin-only revocation is immediate and audited.

## Security and concurrency review

Implemented controls cover bearer/session validation and revocation, password hashing, cross-owner attempt/certificate concealment, protected-resource access checks, deadline enforcement using server time, answer-key secrecy, fingerprinted replay prevention, attempt-limit serialization, progress mutation deduplication, issuance uniqueness, admin-only revocation, exact CORS allowlists and correlation IDs. Edge/distributed rate limiting is documented as a deployment prerequisite; it is not implemented in-process because an instance-local limiter would give misleading guarantees in a scaled deployment.

## Verification results

- `python3 -m compileall -q backend/app backend/alembic`: passed.
- `cd backend && pytest -q`: 5 passed (dependency deprecation warnings only).
- OpenAPI construction and required assessment/public-verification route assertions: passed; 25 canonical paths.
- `flutter analyze`: passed, no issues.
- Relevant Flutter assessment, certificate and entitlement suite: 11 passed.
- Backend identifier brand scan: clean.

## Contract mismatches resolved

- Both `/api/v1` and the Flutter adapter's `/v1` paths are mounted.
- Certificate status is emitted as Flutter's `issued`, not an internal `active` label.
- Eligibility emits the exact Dart enum names (`eligible`, `alreadyIssued`, and the three typed ineligible states).
- Public certificate DTO retains the decoder-required fields while suppressing the private learner account ID and metadata.
- Learner identity/name arguments are replaced by the authenticated principal.

## Known limitations and Phase 7 prerequisites

This is a production-oriented foundation, but production rollout still requires: installing project dependencies (the current host lacks `asyncpg`), provisioning PostgreSQL, running the migration against a disposable and then staging database, adding seeded fixtures/admin content workflows, executing live PostgreSQL API/concurrency/migration upgrade-downgrade tests, wiring the currently unconfigured Flutter auth/catalog/progress/entitlement adapters, and mapping the typed API error envelope in `DioApiClient`.

Before Phase 7 commerce, additionally finalize product/SKU and subscription-tier semantics; define payment-provider webhooks and ledger/reconciliation ownership; decide entitlement activation/refund/revocation rules; add a durable outbox/worker; configure KMS/secrets, TLS, backups/PITR and observability; deploy distributed rate limiting; complete privacy/retention policies; and load-test the entitlement and idempotency paths. No payment or subscription processing is included in Phase A.

