# CMS Standalone Extraction

## Inventory

The CMS previously lived in `lib/features/cms` and its tests in `test/features/cms`.
The feature already contained the Phase 1–2 domain models, repositories, backend and
foundation data sources, Riverpod controllers, dark theme, screens, shell, navigation,
tables, dialogs, and state views. Those files were copied into `cms/lib/features/cms`
and the tests into `cms/test/features/cms` before the student integration was removed.

The extracted feature depended on student-owned infrastructure at four edges:

- `core/routing/app_router.dart` and `app_destination.dart` for `/admin` routes;
- authentication providers and student authentication presentation;
- root bootstrap providers for API and session initialization;
- shared `Result`, `AppFailure`, `ApiClient`, authentication protocol/domain, and
  responsive breakpoint primitives.

The last group represents platform infrastructure rather than student presentation.
It was copied with minimal package-import adaptation so the CMS has no runtime or
package dependency on the student application.

The backend endpoints used by the CMS remain the existing `/api/v1/admin/*` dashboard,
course, category, module, lesson, assessment, question, user, audit-log, publish,
unpublish, validation, and status APIs. Authentication continues to use the existing
`/api/v1/auth/*` endpoints. Backend permission dependencies remain authoritative.

## Final architecture

```text
repository/
├── lib/                 student Flutter application
├── test/                student tests
├── cms/                 standalone Flutter web CMS
│   ├── lib/main.dart
│   ├── lib/bootstrap/
│   ├── lib/core/routing/cms_router.dart
│   ├── lib/features/authentication/
│   ├── lib/features/cms/
│   ├── test/
│   └── web/
├── backend/             shared FastAPI backend and authoritative permissions
└── docs/
```

`cms/lib/main.dart` initializes CMS-owned configuration and session storage, then
starts `CmsApp`. The CMS router owns sign-in, unauthorized, dashboard, courses,
course/assessment editors, users, audit logs, and system health routes. Both clients
communicate with the backend directly; neither frontend imports the other.

## Reuse and adaptation

The existing CMS domain, data, application, presentation, theme, and widget files
were preserved. Package imports were mechanically changed to the standalone package.
The copied backend data source is now selected in all CMS environments; the foundation
data source remains only as a deterministic test fixture. Existing tests were moved
and retained.

CMS-owned code was introduced only for the app entry point, provider/bootstrap graph,
route guard/router, staff sign-in screen, build environment parsing, and web session
store. The student-facing login UI, router, shell, navigation destinations, bootstrap,
mobile services, and presentation state were not copied into the CMS runtime.

## Backend

No backend endpoint, schema, service, permission mapping, or business rule was changed.
The standalone CMS uses the existing backend contracts directly. Roles and permissions
continue to be rejected server-side independently of the frontend route guard.

## Removal

After the standalone tests and web build passed, `lib/features/cms` and
`test/features/cms` were removed from the student package. All CMS imports, route
constants, `/admin` route declarations, redirect behavior, and typed admin
destinations were removed from the student router. Shared backend code remains in
place because it is the canonical implementation.

## Configuration

The CMS accepts `APP_ENV` (`development`, `staging`, or `production`) and
`API_BASE_URL` through Dart build defines. Development defaults to
`http://localhost:8000`; staging and production require an explicit HTTPS URL.
No secret is stored in frontend configuration.

## Verification

- CMS format check: passed.
- CMS tests: 31 passed.
- CMS analyzer: no errors or warnings; preserved code reports 66 informational
  style/deprecation notices under the repository lint set.
- CMS production-like web build: passed with staging environment and an HTTPS API URL.
- Student application tests: 234 passed after route and module removal.
- Student analyzer: no errors or warnings (the nested CMS contributes the same
  informational notices when analysis is run from the repository root).
- Backend CMS/admin tests: 13 passed.
- Full backend suite: passed with 5 environment-dependent tests skipped.

## Remaining limitations

The preserved Phase 1–2 UI has informational Flutter deprecation/style notices. They
do not block analysis, tests, or the web build and were intentionally not rewritten
during this extraction. Production hosting and domain configuration remain deployment
work; the build is independently deployable and contains no backend secrets.
