# Nadha Edu backend

FastAPI/PostgreSQL authority for identity, catalog, learning progress, entitlements, assessments and certificates. The code is brand-neutral and intentionally excludes commerce.

## Architecture

HTTP schemas live in `app/api.py` and `app/schemas.py`; security/session boundaries are in `app/security.py` and `app/dependencies.py`; central access, grading, eligibility, cursor and projection rules live in `app/services.py`; persistence invariants live in `app/models.py`. PostgreSQL is the correctness authority. Redis is not required.

The effective access policy is resolved Course → Module → Lesson/resource. Unavailable content fails closed; free/preview policies short-circuit; otherwise currently usable grants are filtered by scope and resolved with deterministic precedence. Every protected endpoint invokes this service independently.

Assessment attempts are server-issued. Start time and deadline use the server clock. Attempt-number races are serialized with a PostgreSQL transaction advisory lock and backed by a uniqueness constraint. Submission locks the attempt, validates ownership/deadline/question references, grades from private `grading_data`, persists responses/results, and binds `(principal, operation, Idempotency-Key)` to a canonical request fingerprint and replay response.

Certificate eligibility derives enrollment, primitive lesson completion, mandatory pass records and current access. Issuance is idempotent through the learner/course unique constraint and generates a cryptographically random public credential. Public verification is privacy-minimized. Admin revocation changes verification immediately and appends an audit event.

## Development

Use Python 3.12 and PostgreSQL 16 or newer.

```bash
cd backend
python -m venv .venv
. .venv/bin/activate
pip install -e '.[test]'
cp .env.example .env
alembic upgrade head
uvicorn app.main:app --reload
pytest
```

Production must supply a random JWT secret, TLS termination, an exact CORS allowlist, managed PostgreSQL backups/PITR, connection pooling, and edge/distributed rate limits for login/reset, attempt creation, search and public verification. Tokens and password reset secrets must never be logged. Run migrations as a separate deployment job before rolling application instances.

## API and errors

OpenAPI is served at `/docs`. Canonical endpoints use `/api/v1`; `/v1` remains a Flutter compatibility alias. Errors use `{ "error": { "code", "message", "field"?, "requestId" } }`, and all responses include `X-Request-ID`. See `../docs/backend-contract-matrix.md` for the complete audited contract.

## Concurrency and retention

PostgreSQL row/advisory locks plus uniqueness constraints protect attempt limits, finalization, progress mutations and issuance. Idempotency records expire logically after seven days; a scheduled database job should purge expired rows. Audit events are append-oriented. Progress synchronization is capped at 100 mutations and catalog/certificate pages at 50.

## Media V1

Run `alembic upgrade head` (revision `0009_media_v1`). Set the three backend-only
`LEARNING_PLATFORM_CLOUDINARY_*` variables in `.env.example` to enable uploads.
CMS uploads directly to the provider; the backend verifies assets before registration.
Existing provider-less assets retain their CDN path. See [media V1 report](../docs/media-v1-report.md)
for configuration, validation, delivery tradeoffs and rollout requirements.
