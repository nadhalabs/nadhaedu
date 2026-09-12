# CMS Phase 3 + Phase 4 Engineering Report

## Phase 3

Learner operations now provide deterministic ID-keyset pagination, ID/name/email/status/course
filtering, and a detail projection containing identity, enrollments, lesson progress, assessment
results, certificates, entitlements, purchases, and subscriptions without credentials or secrets.
Queries batch counts and load each relationship set directly rather than issuing per-user queries.

Commerce operations expose purchases, provider transaction identifiers, subscriptions, and plans.
Responses distinguish provider-verified, internal, and pending/unverified state. Provider refunds,
cancellations, upgrades, downgrades, proration, and billing corrections remain unavailable and are
reported as provider-owned and fail-closed.

Manual course/resource access uses the existing entitlement model with `admin_grant` source and
explicit manual-override metadata. Grant, extend, and revoke require admin authorization and a
human reason. Extension and revocation require the current version, lock the row, reject stale
operators, reject provider-owned sources, and audit previous/resulting state and target learner.

Notification operations create real in-app notification records. The API and CMS explicitly report
`createdInApp`, `delivered: false`, and unavailable push infrastructure; no delivery is fabricated.

New API groups are under `/api/v1/admin/learners`, `/commerce`, `/entitlements`, and
`/notifications`. Existing certificate revocation remains available and audited.

## Phase 4

`super_admin` is a server-enforced role above admin, content manager, support, and learner. Only the
explicit `SuperAdminPrincipal` dependency reaches `/admin/super/*`; normal admin API calls and CMS
route manipulation are rejected. The first owner is provisioned outside HTTP with:

```sh
python -m app.provision_super_admin --email owner@example.com
```

The command requires an existing active account and refuses to run after any owner exists.

Admin management lists operators, changes approved roles, suspends/reactivates accounts, and revokes
sessions. It prevents self-role changes, self-suspension, learner conversion through role mutation,
and suspension of the last active super admin. Suspension revokes active sessions transactionally;
the existing authentication dependency rejects inactive users and revoked sessions.

Platform controls use one typed `platform_settings` table with a fixed allowlist, safe defaults,
descriptions, version checks, timestamps, and updater identity. Arbitrary keys are rejected. New
registration, purchase verification/emergency commerce, and course-publishing controls are enforced
inside existing backend operations. The CMS presents these as a visually separated Ultimate Control
area with reason-required confirmations.

Integration status reports credential-safe states for PostgreSQL, Redis, Apple, Google Play, Stripe,
SMTP, FCM, APNs, media/CDN, analytics, and crash reporting. Configuration is not called healthy;
live authoritative database/Redis/exact-migration validation remains in `/health/ready`.

The audit explorer accepts actor, actor role, action, target type, exact target ID, result, and date filters. Audit
events remain append-only with no edit/delete API, and existing metadata sanitization remains active.

## Completion pass

The former generic operational projections have been replaced at the affected routes by focused
operator workspaces:

- Learner search submits name/email/ID, account-state, and course filters to the backend. Filter
  changes reset the ID cursor, previous cursors are retained deterministically, and every result has
  an explicit **View learner** action to the stable detail route.
- Entitlements expose grant, extend, and destructive revoke flows only for manual grants. Forms show
  learner/resource/current state/expiry, enforce a reason, confirm mutations, submit the current
  version, refresh authoritative state after every outcome, and surface backend conflicts and
  authorization safeguards. Provider-owned access is visibly read-only.
- Ultimate Control exposes role, suspension, reactivation, and session-revocation actions with
  target/current-state summaries, mandatory reasons, confirmations, disabled self-modification
  affordances, backend error messages, and authoritative refresh.
- Notifications now have validated learner/title/body/type/priority composition. The UI consistently
  says that it creates an in-app record and that scheduling and FCM/APNs delivery are unavailable.
- Commerce learner/provider/limit controls drive server queries and render provider-verified,
  internal, and pending/unverified authority classifications without provider mutation controls.
- Audit filters and pagination drive the backend. Metadata inspection remains sanitised and there are
  no mutation controls.

## Architecture

The CMS remains a standalone Flutter Web application under `cms/`. Its new operations repository,
providers, routes, navigation, workspaces, and Ultimate Control UI are CMS-owned. The student app
contains no CMS routes, state, presentation, or imports. Both remain sibling clients of the shared
backend, which is authoritative for permissions, commerce, entitlements, global controls, sessions,
and audit. No content or commerce business logic was duplicated in Flutter.

## Database

Migration `0007_cms_phase34` adds:

- PostgreSQL `super_admin` user-role enum value;
- `users.suspended_at` and `users.suspension_reason`;
- `entitlements.version` for optimistic concurrency;
- typed `platform_settings` table;
- audit subject/time investigation index.

The local PostgreSQL database was upgraded successfully from `0006_r3_query_indexes` to
`0007_cms_phase34`; exact migration-head readiness now requires `0007_cms_phase34`.

## Verification

- CMS: 38 tests passed; formatter passed; analyzer has no errors/warnings (legacy informational
  notices remain); standalone web build passed, including its WebAssembly dry run.
- Student: 234 tests passed; only the regression assertion that `/admin/dashboard` is rejected
  mentions an admin path.
- Backend: 90 tests collected. Default full run passed 85 with 5 PostgreSQL-gated tests skipped.
- PostgreSQL: the 2 API integration and 3 concurrency tests were explicitly rerun against the local
  migrated PostgreSQL database with `POSTGRES_TEST_URL`; all 5 passed.
- Backend changed-file Ruff lint and format checks passed. The repository-wide Ruff format check
  still reports pre-existing formatting drift in `app/api.py`, `app/schemas.py`, `app/services.py`,
  and `tests/test_cms_content.py`; this narrow pass did not mechanically rewrite those files.
- Migration upgrade and exact-head query passed on PostgreSQL.

## External limitations

Apple, Google Play, Stripe provider-owned administrative mutations, FCM, and APNs remain unavailable
without real production adapters/credentials. SMTP, media/CDN, Sentry, Redis, and PostgreSQL status
distinguish configuration from live health. These integrations intentionally remain fail-closed.
