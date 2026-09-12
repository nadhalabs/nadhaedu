# Nadha Edu — Phase 5.1 Release Blocker Closure

## Executive verdict

**FAIL — unresolved code-level P0/P1 remains**

The static baseline, PostgreSQL verification, provider transaction/webhook boundaries, packaging, and production configuration checks were materially improved. However, production push delivery still has token registration/preferences only and no FCM/APNs dispatch adapter. If push notifications are part of launch scope, this is an unresolved production behavior gap and cannot honestly be reclassified as credential-only verification.

## Blockers closed

- Backend Ruff: all 21 unused imports fixed; four files formatted; lint and format now clean.
- CMS: all 76 prior findings investigated and fixed except the tested dynamic radio form, whose two deprecated properties carry narrow explanatory ignores; final analyzer is clean. Formatter, tests and build pass.
- Student: both drifting files formatted; formatter/analyzer/tests/build pass.
- PostgreSQL: Homebrew PostgreSQL 16.14 was found running. A new isolated `nadha_phase51_audit` database was created, migrated from empty to head, and used for the complete test suite.
- Apple/Google/Stripe: `501 NOT_IMPLEMENTED` provider paths were replaced with real production boundaries. Missing/incomplete configuration remains fail-closed.
- Backend packaging: editable install failed due ambiguous flat-layout discovery; explicit `app*` package discovery was added and installation now succeeds.

## Code defects discovered

- P1: live provider classes were configuration stubs that always returned 501. Replaced with official Apple App Store Server library verification, authenticated Google Android Publisher/Pub/Sub paths, and Stripe SDK PaymentIntent/Webhook verification.
- P1: production provider configuration could be partially supplied without startup rejection. Production validation now rejects partial Apple, Google and Stripe configuration and wildcard CORS.
- P1 remaining: push delivery is not implemented beyond preferences/device-token ownership. CMS in-app notifications remain truthful (`createdInApp`, never delivered), so there is no fake success, but required push delivery needs code before launch.

## Provider readiness

### Apple

- Implemented: official App Store Server API client, Apple certificate-chain/JWS verification with online checks, bundle/app/environment binding, transaction/product/account binding, revoked-state rejection, signed notification decoding, sanitized event projection, database idempotency/reordering downstream.
- Locally tested: selection, missing configuration and fail-closed behavior; imported/compiled official SDK and full regression suite.
- Not live-tested: Apple API/JWS fixtures and real App Store transactions were unavailable.
- Owner action: see launch checklist.

### Google Play

- Implemented: service-account OAuth, subscriptions v2/products v2 authority lookup, package/product/obfuscated-account binding, inactive-state rejection, authenticated Pub/Sub OIDC validation, RTDN parsing, safe event mapping and database replay controls.
- Locally tested: fail-closed selection/configuration and full application regression.
- Not live-tested: Android Publisher and Pub/Sub calls require owner credentials/project configuration.
- Owner action: see launch checklist.

### Stripe

- Implemented: SDK PaymentIntent retrieval, settled amount/status checks, learner/product metadata binding, SDK webhook signature/tolerance verification, supported lifecycle projection, sanitized event data, downstream idempotency/reordering.
- Locally tested: valid signed event, malformed/missing signature behavior, provider selection, configuration, replay/reconciliation suite.
- Not live-tested: no authorized Stripe account or deployed webhook.
- Owner action: see launch checklist.

## PostgreSQL

- Server: PostgreSQL 16.14 (Homebrew).
- Isolated database: `nadha_phase51_audit`.
- Fresh `alembic upgrade head`: passed.
- `alembic current`: `0007_cms_phase34 (head)`.
- `alembic heads`: exactly one, `0007_cms_phase34`.
- Full backend with `POSTGRES_TEST_URL`: **94 passed, 0 skipped** (including API, transaction, row/advisory-lock and concurrency tests).

## Static checks and builds

- CMS: formatter clean; analyzer clean; **38 tests passed**; production web build passed.
- Student: formatter clean; scoped analyzer clean; **234 tests passed**; production web build passed.
- Backend: Ruff format clean; Ruff lint clean; **94 tests passed with PostgreSQL, no skips**.

## Security regression

The Phase 5 direct API regressions remain green: suspended users cannot log in or refresh; refresh is revoked on unavailable accounts; expired database sessions invalidate access; content managers cannot query audit logs. Entitlement provenance, stale versions, manual/provider boundaries, admin self/last-owner protections, session revocation, webhook signature/replay/reordering, malformed input and production provider selection are covered by the passing suites.

## Production configuration and operations

Production rejects development/short secrets, insecure required URLs, wildcard CORS and partial provider configurations. Mock payment providers remain development/test-only. Redis participates in readiness and production rate limiting. SMTP hands messages to a configured TLS relay and reports failures without logging secrets. Signed media URLs are fail-closed. Health/readiness, structured logging and Sentry boundaries exist.

## Remaining owner actions

Credential-backed provider transactions, deployed SMTP/CDN/DNS/Redis/database/backup/monitoring validation are listed in [production-owner-launch-checklist.md](production-owner-launch-checklist.md). Those are real-world actions. Push is intentionally listed separately because its server adapter must first be implemented in code.
