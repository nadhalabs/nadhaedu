# Nadha Edu

Nadha Edu — by Nadha Labs. This Flutter learning platform targets Android, iOS, and Web. The implemented scope includes authentication/onboarding, scalable course catalog/discovery, core learning experience with durable progress, and a first-class freemium access and entitlement architecture. Payments gateway processing, assessment execution engines, and recommendation ML remain outside the current phase.

The user-facing product name is centralized in `lib/config/branding_config.dart`. Engineering identifiers remain brand-neutral.

## Requirements

- Flutter 3.41.9 stable or a compatible newer stable release
- Dart 3.11.5 or compatible

## Run

```sh
flutter pub get
flutter run -t lib/main_development.dart --dart-define=API_BASE_URL=https://api.dev.example.com
```

Production defaults to a deliberately non-routable `.invalid` endpoint. Supply a real HTTPS endpoint at build time. Compile-time defines are configuration, not a secret store; never place credentials in them.

The independently deployable CMS is in `cms/` and talks directly to the same backend:

```sh
cd cms
flutter pub get
flutter run -d chrome --dart-define=APP_ENV=development --dart-define=API_BASE_URL=http://localhost:8000
```

Staging and production CMS builds require an HTTPS `API_BASE_URL`. The student application contains no CMS routes or CMS presentation module.

The development entry point enables a deterministic in-memory authentication adapter for UI development. Register an account in the running app; recovery OTP verification uses `123456` only in this local adapter. Staging and production fail closed until a real `AuthRemoteDataSource` is provided.

Development also enables a bounded in-memory catalog with cursor pagination and server-driven home sections. Staging and production fail closed until a real `CatalogDataSource` implements server-side querying, filtering, sorting, bookmark synchronization, and recently-viewed synchronization.

Development enables an in-memory learning-service adapter and a public HTTPS HLS demonstration stream. Learning progress is written locally first, isolated by learner ID, and synchronized in idempotent batches after a throttle interval and at lifecycle boundaries. Staging and production fail closed until a server-backed `LearningDataSource` provides authoritative progress, signed playback manifests, and subtitle metadata.

Development provides a deterministic `FoundationEntitlementDataSource` with rich seed data modeling multi-tier subscriptions, individual purchases, bundles, trials, promotional codes, scholarships, and administrative grants. Access policy inheritance (`Course` → `Module` → `Lesson`) is resolved deterministically, and server authority is enforced for protected assets. Staging and production fail closed until a server-backed `EntitlementDataSource` is configured.

## Capability Status Matrix

| Capability / Subsystem | Current Status | Description & Boundary |
| :--- | :--- | :--- |
| **Authentication & Identity** | **IMPLEMENTED** | Multi-session tokens, refresh flow, email/password, Argon2id/bcrypt hashes, account deletion. |
| **Catalog & Discovery** | **IMPLEMENTED** | Server-driven home feed, cursor-paginated search/browse, bookmark & history tracking. |
| **Learning & Progress** | **IMPLEMENTED** | Local-first durable outbox, throttled sync, server revision conflict resolution. |
| **Entitlements & AccessGate** | **IMPLEMENTED** | Multi-grant precedence engine, server-authoritative lease evaluation, inline AccessGate UI. |
| **Assessments & Quizzes** | **IMPLEMENTED** | Server-side grading, attempt limits, timing deadlines, and idempotency keying. |
| **Certificates** | **IMPLEMENTED** | Server-issued credentials, SHA-256 signatures, public verification links. |
| **Content Protection** | **IMPLEMENTED** | `FLAG_SECURE` (Android), `UIScreen.capturedDidChangeNotification` observer (iOS), app-switcher covers. |
| **Offline Downloads** | **IMPLEMENTED** | HTTP 206 byte-range streaming, SHA-256 checksums, disk reserve checks, Wi-Fi policies, bounded task store. |
| **Notifications (In-App & Local)** | **IMPLEMENTED** | Notification center, optimistic mark-all read, unread counts, user channel preferences. |
| **Push Notifications (FCM / APNs)** | **FAIL-CLOSED / BLOCKED** | Requires production FCM/APNs credentials; service fails closed in staging/production without fake success. |
| **Commerce (Apple StoreKit 2)** | **FAIL-CLOSED / BLOCKED** | Requires App Store Connect API keys; service fails closed (`503 / 501`) when unconfigured. |
| **Commerce (Google Play Billing)** | **FAIL-CLOSED / BLOCKED** | Requires Google Cloud service account; service fails closed (`503 / 501`) when unconfigured. |
| **Commerce (Stripe Live)** | **FAIL-CLOSED / BLOCKED** | Requires live Stripe secret keys and webhook secret; service fails closed (`503 / 501`) when unconfigured. |
| **Signed Media CDN Origin** | **PARTIAL** | HMAC-SHA256 URL token generation implemented; production requires cloud CDN bucket wiring. |
| **Hardware DRM (Widevine / FairPlay)**| **PLANNED** | Application sandboxing and lease verification active; native CDM decryption pipeline planned. |
| **Analytics & Crash Reporting** | **NO-OP / PLANNED** | Privacy-conscious contract boundaries present; vendor SDK integration planned. |
| **Admin CMS (Phase 1–2)** | **IMPLEMENTED / STANDALONE** | Independently runnable Flutter web client in `cms/`, backed by server-authoritative admin APIs. |

## Quality checks

```sh
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

See [ARCHITECTURE.md](ARCHITECTURE.md), [CONTRIBUTING.md](CONTRIBUTING.md), and [docs/adr](docs/adr).
