# Nadha Edu — Phase 5 Final Adversarial Production Audit

Audit date: 2026-09-01 (Asia/Kolkata)

## Executive verdict

**FAIL — not production-ready**

Two P1 backend authority defects were found and repaired. The repaired paths and all executable backend, CMS, and student tests pass. Release remains blocked because the repository's live Apple, Google Play, and Stripe transaction/provider lifecycle implementations deliberately return `501 NOT_IMPLEMENTED`; PostgreSQL-specific migration and concurrency tests could not run because no `POSTGRES_TEST_URL` or local PostgreSQL service was available. CMS and backend repository-wide static checks also have pre-existing failures recorded below.

No P0 defect was confirmed.

## Scope audited

- FastAPI/SQLAlchemy backend, JWT access tokens, database-backed refresh sessions, account state, password reset, logout, session revocation, and CMS authentication.
- CMS route-level RBAC and direct API access for dashboards, content, learners, entitlements, commerce, notifications, administrator management, platform settings, integrations, readiness, and audit logs.
- Entitlement provenance, manual grant/extend/revoke, version checks, row locks, provider-owned mutation rejection, access resolution, and commerce reconciliation code.
- Apple StoreKit, Google Play, Stripe, and development-only mock provider selection and webhook handling.
- Notification creation semantics and delivery claims.
- Audit generation, filtering, sanitization, append-oriented model, and transaction placement.
- Learner search/filter/cursor/detail paths and object ownership checks in student APIs.
- Production configuration validation, CORS, signing secrets, Redis/rate limiting, SMTP reset delivery, media signing, and readiness checks.
- Migration graph and schema constraints/indexes.
- Student/CMS separation, production adapter selection, Flutter tests, analyzers, formatting checks, and release web builds.

## Real architecture and authorities

- The student and CMS clients are separate Flutter applications. Both use the FastAPI service as the production authority; development-only in-memory adapters are selected only in development.
- PostgreSQL is the intended correctness authority through async SQLAlchemy and Alembic. Redis provides distributed production rate limits and participates in readiness.
- JWT access tokens carry user/session identifiers, while every authenticated request reloads the `AuthSession` and `User`; the database role and active flag, not the JWT role claim, determine current authority.
- Entitlements are authoritative database records. Manual CMS records use `admin_grant`; provider-derived records retain purchase/subscription foreign-key provenance. Provider-owned records reject manual extend/revoke.
- CMS notification creation currently creates an in-app record only and truthfully returns `createdInApp`, `delivered: false`.
- Audit events are created server-side in the same unit of work as critical mutations. Metadata passes a recursive sensitive-key sanitizer.

## Attacks performed

- Called CMS routes without credentials and with learner, support, content-manager, admin, and super-admin identities rather than relying on frontend guards.
- Exercised suspended login, suspended refresh-token replay, expired authoritative sessions, revoked sessions, role gates, self-promotion, and last-super-admin suspension.
- Exercised manual entitlement grant, mandatory reason validation, extend, revoke, stale versions, provider-owned mutation rejection, and audit persistence.
- Reviewed row-lock and PostgreSQL advisory-lock paths for entitlement/admin/provider operations, duplicate and reordered webhooks, ambiguous transaction identifiers, and event idempotency.
- Exercised learner search/detail and combined backend filtering/cursor paths; reviewed exact-ID filters and ownership predicates.
- Exercised notification validation and confirmed that acceptance is not represented as delivery.
- Reviewed audit exact target filtering, actor/result/date filters, pagination, output fields, sanitization, and absence of mutation endpoints.
- Reviewed production provider selection to confirm mock aliases are unavailable outside development/test and unconfigured providers fail closed.
- Searched the student application for CMS routes/components. The student route parser test rejects `/admin/dashboard`; CMS presentation code remains under the separate `cms/` application.
- Exercised invalid/missing fields through Pydantic and existing endpoint suites, including malformed IDs, invalid enums, bounds, stale versions, and provider signatures.

## Defects discovered

### P1 — suspended/deactivated accounts could mint fresh sessions

- Affected component: backend authentication (`POST /auth/login`, `POST /auth/refresh`).
- Root cause: login validated only password correctness; refresh validated only the refresh-session row. Neither checked whether the referenced user was active before calling `create_session`.
- Failure scenario: a suspended user with a password or still-valid refresh token could repeatedly mint new sessions. Subsequent requests were rejected by `current_user`, but session issuance and restoration semantics were inconsistent and refresh replay remained possible.
- Repair: login and refresh now reject unavailable users; refresh also revokes the presented session before returning the failure.
- Regression: `test_suspended_account_cannot_login_or_refresh_and_existing_session_is_revoked` verifies HTTP results and authoritative session state.

### P1 — authoritative session expiry was not enforced on access-token requests

- Affected component: backend authentication dependency.
- Root cause: `current_user` checked presence and revocation but not `AuthSession.expires_at`.
- Failure scenario: if access-token lifetime were configured beyond session lifetime, an access token remained usable after the database session expired.
- Repair: every authenticated request now rejects an expired session, with timezone-safe handling for SQLite tests and PostgreSQL timezone values.
- Regression: `test_access_token_is_rejected_after_authoritative_session_expiry` directly exercises a valid JWT bound to an expired database session.

### P1 — content manager could query the security audit explorer

- Affected component: `GET /admin/audit-logs`.
- Root cause: the endpoint used the broad `CmsPrincipal` guard despite the declared RBAC matrix granting `view_audit_logs` only to super-admin, admin, and support.
- Failure scenario: a content manager could bypass navigation intent and directly query actor identities, targets, reasons, and security events.
- Repair: the endpoint now requires the support/admin/super-admin guard.
- Regression: `test_content_manager_cannot_query_security_audit_explorer`; the existing content mutation test now reads its audit through a permitted support identity.

## Authorization matrix

| Operation | Learner | Content manager | Support | Admin | Super-admin |
|---|---:|---:|---:|---:|---:|
| CMS dashboard/read content | No | Yes | Yes | Yes | Yes |
| Mutate courses/curriculum/assessments | No | Yes | No | Yes | Yes |
| Learner search/detail | No | No | Yes | Yes | Yes |
| View audit explorer | No | No | Yes | Yes | Yes |
| Manual entitlement grant/extend/revoke | No | No | No | Yes | Yes |
| View commerce | No | No | No | Yes | Yes |
| Create in-app notification | No | No | No | Yes | Yes |
| Change admin roles | No | No | No | No | Yes |
| Suspend/reactivate/revoke sessions | No | No | No | No | Yes |
| Platform settings/integration status | No | No | No | No | Yes |

Role evaluation uses the current database role on every request. A stale token therefore does not preserve a removed role. Suspension revokes sessions and the active-user check prevents subsequent access.

## Provider authority

Locally verified:

- Mock/test/dev provider aliases resolve only in development/test.
- Unknown or missing production providers fail closed.
- Provider-owned entitlements cannot be manually extended or revoked.
- Provider events have a `(provider, event_id)` uniqueness constraint, PostgreSQL advisory lock path, row locks, duplicate detection, out-of-order checks, ambiguous-identifier rejection, and bounded supported event types.
- Stripe webhook HMAC/timestamp verification exists, but intentionally stops before mutation.

Release blockers:

- Apple transaction and webhook verification return `501 PROVIDER_NOT_IMPLEMENTED` even when configured.
- Google Play transaction and Pub/Sub verification return `501 PROVIDER_NOT_IMPLEMENTED` even when configured.
- Stripe live transaction verification and post-signature webhook reconciliation return `501 PROVIDER_NOT_IMPLEMENTED`.
- No real credential-backed purchase, renewal, cancellation, refund, restoration, account mapping, or reordered-event run was possible. These are code/integration gaps, not successful verification.

## Concurrency results

- SQLite-backed tests cover stale entitlement versions and mutation state, but SQLite is not accepted as proof of PostgreSQL locking semantics.
- Code inspection confirmed `SELECT ... FOR UPDATE` on entitlement changes and admin mutations, plus PostgreSQL advisory locks and uniqueness constraints on provider events and other critical flows.
- Three PostgreSQL concurrency tests and two PostgreSQL API tests were collected but skipped because `POSTGRES_TEST_URL` was absent and `pg_isready` reported no service on `/tmp:5432`.
- Therefore simultaneous entitlement, role/suspension, and provider-event outcomes are **not verified in this environment** and remain a release-gate requirement.

## Migration integrity

- `alembic heads`: exactly one head, `0007_cms_phase34`.
- Linear history: `0001_phase_a` → `0002_operations` → `0003_commerce` → `0004_protection` → `0005_p0_integrity` → `0006_r3_query_indexes` → `0007_cms_phase34`.
- Live `alembic current` and upgrade-on-PostgreSQL could not be executed without a database. Readiness requires the exact `0007_cms_phase34` revision.

## Verification

### Backend

- `pytest -q --disable-warnings`: **88 passed, 5 skipped** (93 collected); all skips are the five PostgreSQL-gated tests.
- Focused repaired-path suite: `pytest -q --disable-warnings tests/test_cms_phase34.py tests/test_cms_admin.py`: **16 passed**.
- `ruff check app tests`: **failed on 21 pre-existing unused imports**, located in `app/services.py` and `tests/test_cms_content.py`.
- `ruff format --check app tests`: **failed on four pre-existing unformatted files**: `app/api.py`, `app/schemas.py`, `app/services.py`, and `tests/test_cms_content.py`. The touched snippets themselves were kept conventionally formatted; repository-wide mechanical reformatting was outside the P0/P1 repair scope.

### CMS

- `flutter test`: **38 passed**.
- Production web build with HTTPS API base: **passed**, output `cms/build/web`.
- `dart format --output=none --set-exit-if-changed lib test`: **90 files checked, 0 changes**.
- `flutter analyze`: **failed with 76 existing info-level findings** (deprecated Flutter APIs, discarded/unawaited futures, style findings). No error-level compiler finding was reported, but the command is not green.

### Student application

- `flutter analyze lib test`: **passed, no issues**.
- `flutter test`: **234 passed**.
- Production web build with HTTPS API base: **passed**, output `build/web`.
- Student formatter check reports two existing files would change: `lib/features/authentication/data/auth_dtos.dart` and `lib/features/authentication/domain/learner_identity.dart`.
- Repository-root `flutter analyze` also descends into `cms/` and consequently reports the same 76 CMS findings; the student-only scoped analyzer is green.

## Remaining limitations and release blockers

### Code/integration blockers

- Live Apple, Google Play, and Stripe verification/reconciliation is not implemented. A commerce-enabled production release cannot proceed.

### Required deployment verification

- Run `alembic upgrade head`, `alembic current`, readiness, all five PostgreSQL-gated tests, and destructive/reordered concurrency scenarios against the supported PostgreSQL version.
- Verify production JWT/media secrets, exact CORS allowlist, TLS, secure edge headers/cookies as applicable, Redis availability and distributed rate limits, backups/PITR, connection pooling, statement timeout, and migration-as-separate-job behavior.

### Required external-provider verification

- Complete provider adapters, then run credential-backed sandbox and production-canary tests for purchase, renewal, cancellation, expiration, refund/reversal, restoration, plan changes, duplicate/replayed/delayed/reordered events, unknown products, and wrong-account mapping.
- Configure and verify SMTP reset delivery, FCM/APNs delivery (currently not implemented), signed CDN origin enforcement, Sentry, and operational alerting. Notification UI must continue to distinguish in-app creation from provider delivery.

### Pre-existing unrelated drift

- Backend lint/format failures and CMS analyzer findings listed in Verification.
- Student formatter drift in the two files listed above.
- The provided workspace is not a Git working tree (`git status` reports no `.git` repository), so baseline ownership/diff provenance could not be established through Git.

## Release decision

Do not release to real users as a production commerce system. Re-run this gate after live provider implementations exist, PostgreSQL/concurrency verification is green, and the repository's required static checks have an explicitly accepted or repaired baseline.
