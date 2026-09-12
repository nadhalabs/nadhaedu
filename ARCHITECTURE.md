# Architecture

## Scope

This repository contains the Flutter learner application and a FastAPI/PostgreSQL backend for identity, catalog, learning progress, entitlements, assessments, certificates, downloads, notifications, and commerce verification boundaries. Live payment processing and recommendation ML are not enabled.

## Module layout

`lib/features/<feature>` is the scaling unit. A feature may contain:

- `presentation`: widgets and interaction adapters
- `application`: state and use-case orchestration
- `domain`: business concepts and rules with no Flutter or infrastructure dependency
- `data`: implementations of domain-facing repositories or sources

`lib/core` contains narrowly shared technical capabilities and design-system primitives. `lib/bootstrap` is the composition root. `lib/config` owns validated runtime/build configuration and replaceable UI branding.

Dependencies point inward: presentation uses application/domain; data implements inward-facing contracts; concrete infrastructure is selected at bootstrap. Features must not import another feature's presentation or data layer.

## Runtime foundations

- Riverpod provides explicit dependency injection and state ownership.
- `go_router` provides declarative, deep-link-ready navigation.
- Dio is hidden behind `ApiClient`; timeouts and generic error mapping are configured centrally.
- shared preferences is used only for non-sensitive local key/value data.
- platform secure storage is hidden behind `SecureStore`; sensitive values must not use shared preferences.
- connectivity is a hint, not proof that the backend is reachable. Requests remain the source of truth.
- analytics and crash reporting currently use no-op adapters until a vendor and consent/privacy policy are selected.
- framework and platform uncaught errors flow through the crash-reporting boundary.

## Authentication and learner identity

Authentication uses unidirectional flow from `AuthRemoteDataSource` through DTO mapping, `AuthRepository`, `AuthService`, and `AuthController` to presentation. UI state receives only `AuthSession` metadata and `LearnerIdentity`; access and refresh tokens remain in the data layer and encrypted secure storage.

The state machine distinguishes bootstrapping, unauthenticated, onboarding-required, authenticated, expired, and recoverable bootstrap-failure states. Declarative route redirects enforce those client navigation states. These redirects improve UX but are not authorization controls.

Email/password, registration, password recovery, optional OTP, refresh, all-device logout, external identity-provider capability, and account deletion have backend-neutral contracts. Google and Apple remain disabled capabilities until their server and platform configurations exist.

`FoundationAuthDataSource` is a deterministic in-memory development adapter. Staging and production use `BackendAuthDataSource` against the configured HTTPS API. The development OTP is not a production authentication mechanism.

## Course catalog and discovery

The content hierarchy is `Course` → `CourseModule` → `Lesson`. Sealed lesson content models cover video, article, PDF/resource, quiz, assignment, live class, and project delivery without implementing their later-phase execution behavior.

Catalog access flows through `CatalogDataSource`, `CatalogRepository`, application controllers, and presentation. Queries contain search, category, level, sort, opaque cursor, and a bounded page size. The UI never downloads or locally filters the complete production catalog. Pagination merges pages with an ID-keyed map to avoid duplicates.

Home is an ordered server-driven list of `HomeFeedSection` values rather than a fixed widget structure. It supports continue-learning, recommended, trending, new releases, categories, recently viewed, and contextual recommendation sections. Recommendation ranking and section ordering belong to future server services.

Repository caches are query-keyed and bounded by the active process. Cached home/pages/course details may be returned during temporary failures and are explicitly marked stale. Bookmark and recently-viewed contracts call the data source for cross-device authority and retain bounded local fallback indexes. Staging and production use the remote catalog adapter and fail closed when the API is unavailable or invalidly configured.

## Freemium access and entitlements

Entitlement modeling avoids single-boolean simplifications by introducing typed domain concepts: `Entitlement`, `EntitlementSource`, `EntitlementStatus`, `ResourceType`, `AccessPolicy`, `AccessDecision`, and `AccessReason`.

The architecture supports multiple simultaneous entitlement sources (subscriptions, individual purchases, bundles, promotions, trials, coupons, scholarships/grants, time-limited access, and administrative grants) with deterministic precedence resolution:
`Administrative Grant` > `Scholarship` > `Individual Purchase` > `Bundle` > `Subscription` > `Promotion` > `Coupon` > `Trial` > `Time-Limited Access`.

Access policy inheritance cascades naturally:
`Course Access Policy` → `Section / Module Override` (when configured) → `Lesson / Resource / Quiz / Certificate Override` (when configured).

Access evaluation is centralized in `AccessEvaluator` and consumed reactively via `accessDecisionProvider`. Presentation code consumes typed `AccessDecision` objects (`free`, `preview`, `locked`, `included`, `purchased`, `subscribed`, `expired`, `unavailable`) via `AccessStatusBadge` and `AccessGateView` rather than reproducing business logic in widgets.

Entitlements are cached in learner-isolated persistent storage for offline usability. Repository results are filtered to the authenticated learner, and cached evaluations preserve explicit stale provenance through application state (`isStale: true`). Required subscription tiers and bundle identifiers are enforced for their respective entitlement sources. Unavailable content short-circuits all grants.

Development playback authorization resolves each asset to server-owned lesson, course, category, and policy metadata before evaluating access. It does not infer authorization from client state or permissive asset-name prefixes. Staging and production use an unconfigured fail-closed adapter until a real server implementation is supplied; dependency construction never silently falls back to development services.

## Responsive and accessible UI

Window-size classes choose distinct compact, medium, and expanded compositions at 600 and 1024 logical pixels. The authenticated shell switches between bottom navigation and navigation rails. Course grids select columns from available layout width rather than device type. Content width is bounded, system text scaling is preserved, core actions meet a 48 logical-pixel target, state changes expose semantics, and light/dark/system modes are supported.

## Learning experience and progress

`CourseOutlineIndex` flattens the ordered module/lesson hierarchy once and stores ID-to-index and lesson-to-module maps. Next/previous navigation and lesson lookup are O(1); course completion is O(number of course lessons) only when progress state changes, not during repeated nested scans.

Learning progress is local-first. Each position or completion change creates a stable mutation ID, records its server base revision, updates the local snapshot, and enters a bounded durable outbox. The controller schedules at most one server synchronization per 30-second window and flushes on lifecycle/navigation boundaries. The server snapshot and revision remain authoritative; acknowledged mutations are removed, while unacknowledged local mutations are replayed in event order over the latest server baseline. The server contract must deduplicate mutation IDs and return the accepted authoritative snapshot plus acknowledged IDs.

Learning history is a bounded, learner-isolated most-recent index rather than an unbounded event log. Continue Learning selects its target from this index, while resume within a course prefers the latest incomplete lesson with a position and otherwise the first incomplete lesson.

Video playback uses a feature-facing playback-source contract and Flutter's maintained `video_player` implementation. The current source type is HTTPS HLS, leaving adaptive rendition selection to native players. Controls expose play/pause, seek, speed, embedded captions, fullscreen, and next/previous lesson navigation. Playback resumes from persisted position, pauses and checkpoints in background/inactive states, restores system UI/orientation after fullscreen, and disposes platform controllers with the widget. Production playback URLs should be short-lived and server-authorized.

## Assessments and evaluation engine

Assessments support single choice, multiple choice, true/false, and text response question types.

### Assessment integrity
To ensure assessment integrity, production correct answers and grading remain strictly server-side. The production client models (`Question`, `QuestionOption`) never parse answer keys or rubrics. `RemoteAssessmentDataSource` calls the configured HTTPS API. `FoundationAssessmentDataSource` is an in-memory development fixture whose embedded rubrics are not secure and must never be used as a production authority.

The server creates an attempt before answers can be submitted and returns an opaque attempt ID, server timestamp, and authoritative expiry. Submission uses that attempt ID plus an `Idempotency-Key` header. The server must atomically bind an idempotency key to the request payload, return the original result for exact retries, reject reuse with a different payload, and accept only one result per attempt.

### Orchestration and lifecycle
`AssessmentController` manages the assessment session lifecycle (`initial` → `loading` → `intro` → `taking` → `submitting` → `completed` / `error`). The countdown is presentation only and is recalculated from the server deadline after lifecycle resume; the server independently rejects expired attempts. When an accepted result is passed, the client refreshes authoritative progress instead of manufacturing a local quiz completion.

Production assessment endpoints are `/v1/assessments/:id`, `/attempts/summary`, `/attempts`, and `/attempts/:attemptId/submission`. Authentication, learner binding, entitlement checks, attempt limits, timing, grading, rate limiting, audit records, progress updates, and idempotency are backend responsibilities.

## Certificate issuance and verification

Certificates are formal academic and professional credentials issued upon qualifying achievement.

### Server-authoritative eligibility and issuance
A client cannot issue a certificate merely because local state indicates course completion. `RemoteCertificateDataSource` asks the configured HTTPS API to evaluate and issue credentials. The development fixture fails closed whenever any eligibility dependency is missing or errors. The backend evaluates:
1. Complete course progress verified by the server (completion fraction == 1.0).
2. Authoritative pass records for all mandatory course assessments and quizzes.
3. Entitlement policy requirements (e.g., verifying active subscription tier or certificate purchase entitlement).

### Verification and revocation
Each issued certificate receives a backend-generated, opaque, globally unique credential identifier and verification link. `/verify/:credentialId` is public for authenticated and unauthenticated visitors and resolves through `/v1/public/credentials/:credentialId`. Revocation and unavailable states come from that public service. Development credentials use a `DEV-` prefix and are not trustworthy credentials.

## Commerce, subscriptions, and platform billing

The commerce architecture strictly decouples payment transaction processing from entitlement authorization.

### Separation of concerns
The system enforces four distinct domain models:
1. `PaymentTransaction`: Low-level platform payment attempt, receipt, or token generated by Apple StoreKit 2, Google Play Billing, or web checkout.
2. `Purchase`: Verified commercial purchase of an individual course, bundle, or certificate unlock.
3. `Subscription`: Ongoing agreement with billing intervals (monthly, annual, quarterly), tiers (standard, pro, student, family, institution), and lifecycle statuses (`active`, `trialing`, `inGracePeriod`, `billingRetry`, `cancelled`, `paused`, `expired`, `revoked`).
4. `Entitlement`: Authoritative resource access grant.

**Invariant**: `payment_success == entitlement_granted` is never implemented on the client. Native platform payment receipts are sent to `/api/v1/commerce/transactions/verify`. Development can use the explicit mock verifier; Apple, Google, and Stripe verification currently fail closed and issue no entitlement until their provider-native integrations are completed.

### Concurrency and idempotency
- Checkout sessions generate a unique `idempotencyKey` passed to backend verification headers (`Idempotency-Key`).
- State machines prevent duplicate purchase submissions while a transaction or verification is in-flight.

### Lifecycle, upgrades, and reconciliation
- Domain models represent trials, introductory offers, coupons, plan changes, grace periods, and billing recovery. Real-provider cancellation and plan changes fail closed until provider-native lifecycle calls are implemented.
- `restoreAndReconcilePurchases` synchronizes native store receipts across reinstallations, device switches, and auth changes.
- UI components (`FullScreenPaywall`, `BottomSheetPaywall`, `InlineLockedState`, `PremiumBadge`, `UpgradeCtaButton`) are driven by server/config models (`SubscriptionPlan`, `CourseProduct`, `BundleProduct`) and provide mandatory store compliance links (Terms of Use/EULA, Privacy Policy, Restore Purchases, auto-renewal disclaimers).

## Authoritative Commerce and Subscriptions Backend (Phase 7B)

The backend provides authoritative normalized commerce records, mock-only development verification, lifecycle reconciliation boundaries, and entitlement provisioning. Live provider verification remains explicitly fail-closed.

### Core Architectural Invariant
```
Payment Provider Transaction → Server Verification → Authoritative Purchase / Subscription → Authoritative Entitlement
```
Under no circumstances does `payment_success` on the client grant access directly. Entitlement evaluation is computed authoritatively by `resolve_access(...)`.

### Normalized Commerce Entities
1. `SubscriptionPlan`: Canonical subscription tier definitions (Pro Monthly, Pro Annual, Student Pro, Family Plan, Institution) with trial intervals, savings calculations, and benefit manifests.
2. `CommerceProduct`: Standalone courses and course bundles with pricing, discounts, and feature lists.
3. `ProviderProductMapping`: Explicit bi-directional mapping from internal commercial plans/products to store identifiers (`Apple StoreKit`, `Google Play Billing`, `Stripe`).
4. `PaymentTransaction`: Immutable journal of verified provider receipts, transaction identifiers, payment status, and gateway payloads.
5. `Purchase`: Authoritative records of completed, refunded, or revoked single-course and bundle purchases.
6. `Subscription`: Authoritative subscription state machine (`trialing`, `active`, `inGracePeriod`, `billingRetry`, `cancelled`, `paused`, `expired`, `revoked`), tracking billing periods, auto-renew status, and trial metadata.
7. `Coupon` & `CouponRedemption`: Discount rules (percentage, fixed amount, expiration, usage caps, product restrictions) with per-learner redemption tracking.
8. `ProviderEvent`: Asynchronous server notification audit and replay log with unique constraint deduplication.

### Multi-Grant Coexistence
A learner can simultaneously possess a subscription, individual course purchases, and promotional grants. The centralized access evaluator evaluates access using deterministic precedence:
`Admin Grant` > `Scholarship` > `Purchase` > `Bundle` > `Subscription` > `Promotion` > `Trial` > `Free`.
Revoking or cancelling a subscription preserves perpetual access to courses purchased individually.

### Webhook Engine & Lifecycle Synchronization
- The development mock webhook exercises signature-independent lifecycle reconciliation, idempotency, ownership, and ordering. Apple, Google Play RTDN, and Stripe production reconciliation fail closed until their complete provider-native verification and object mapping are implemented.
- Out-of-order and replayed events are audited and handled safely without race conditions.

### Security and Fail-Closed Boundary
- Staging and production fail closed when provider verification credentials are unconfigured.
- Transaction verification enforces strict learner principal ownership to prevent cross-user transaction hijacking.

## Content Protection and Screen Capture Deterrence

The platform implements defense-in-depth content protection designed to discourage and mitigate casual piracy and recording of protected materials.

### Crucial Security Invariant
Screen-capture deterrence is a defense-in-depth measure. Software controls cannot prevent analog recording (photographing or recording the physical screen with another device or camera).

### Four Distinct Media Protection Tiers
1. **Screen Capture Deterrence**:
   - **Android**: Dynamically manages `WindowManager.LayoutParams.FLAG_SECURE` on the window exclusively while protected content is on-screen. Prevents screenshots, ordinary screen recordings, insecure external monitor mirroring, and blacks out recent-apps overview thumbnails.
   - **iOS / iPadOS**: Real-time `UIScreen.capturedDidChangeNotification` and `UIScene` capture observation over native EventChannels. Actively detects screen recording, AirPlay mirroring, and remote capture. When active, pauses video playback immediately and redacts UI with a neutral, non-accusatory notice (*"Screen recording or sharing is active. Stop screen capture to continue this protected lesson."*). Restores playback when capture stops.
   - **App-Switcher Privacy**: Inactive/background state transitions display an opaque privacy cover over the window snapshot, preventing sensitive frames from remaining visible in task switchers.
   - **Screenshot Notifications**: Observed on iOS for analytics and telemetry only, never for punitive bans or automated punishment.
   - **Unprotected Scope**: Standard screens (catalog, discovery, home, profile, marketing, and free lesson previews) do not acquire window locks and remain 100% screenshot-capable.
2. **Short-Lived Signed Media Tokens**: Expiring HMAC tokens are generated; production CDN/origin enforcement remains an external integration requirement.
3. **Application-Private Storage**: Downloads use application-sandboxed files. They are not claimed to have application-level encryption or secure-keystore-backed media encryption.
4. **Hardware/Software DRM**: FairPlay and Widevine are not implemented and remain planned external integrations.

### Server-Authoritative Protection Policies
The protection requirement is governed authoritatively by backend content metadata (`ContentProtectionPolicy`: `none`, `discourageCapture`, `blockCaptureWhereSupported`, `drmRequired`):
`Course Protection Policy` → `Module Override` → `Lesson / Assessment Override`.
The client cannot downgrade or disable the required protection level locally.

## Offline Learning, Downloads and Resilient Content Access

The platform provides a production-grade offline learning subsystem that allows learners to download video lectures, reading materials, and course assets while preserving server-authoritative entitlements, bounded storage, and media security.

### End-to-End Download Lifecycle
1. **Pre-Flight Authorization (`POST /api/v1/downloads/authorize`)**:
   - The client requests authorization for a specific resource (video, document, asset) at a requested quality level.
   - The backend checks learner authentication, course/lesson entitlements (free, purchased, active subscription, or valid promotional grant), and content downloadable flags (`Lesson.is_downloadable`).
   - The backend generates a short-lived cryptographic download token (HMAC-SHA256 with timestamp, resource ID, learner ID, and entitlement expiry) and returns a signed download URL, media file size, SHA-256 checksum, asset version, and subtitle tracks.
2. **Pre-Check Constraints**:
   - **Network Policy**: Verifies current network status and respects user preference (Wi-Fi only vs cellular allowed).
   - **Storage Space Pre-Check**: Ensures device has sufficient disk space for the target file plus a 50MB safety reserve before beginning download.
3. **Resumable Byte-Range Streaming**:
   - Downloads stream directly to sandboxed, application-private storage (`Directory.getApplicationSupportDirectory()/downloads/secure`).
   - If interrupted, the manager verifies partial file size on disk and issues an HTTP `Range: bytes={existingBytes}-` request to resume without re-downloading existing chunks.
   - Concurrency is strictly bounded (maximum 2 simultaneous downloads) with a FIFO queue.
4. **Integrity & Subtitle Verification**:
   - On download completion, file byte size is verified against backend metadata.
   - Computes SHA-256 hash across the downloaded file stream to detect corruption or incomplete transfers.
   - Associated WebVTT subtitle tracks are downloaded alongside the main media file.
5. **Offline Entitlement Leases & Revalidation (`POST /api/v1/downloads/revalidate`)**:
   - Completed downloads store an `entitlementExpiresAt` timestamp (default 30 days for subscriptions/courses, matching backend grant expiry).
   - When the client is online, background or explicit revalidation batches active resource IDs to `/api/v1/downloads/revalidate`. If subscription has renewed, offline lease is extended; if refunded or cancelled, offline access is immediately revoked.
   - Expired offline leases prevent local playback while preserving files on disk for easy one-tap re-authorization upon reconnection.

### Crucial Security Invariants
- **No Permanent Bypass**: Offline access is time-bounded by backend cryptographic leases. Disconnecting a device cannot grant indefinite access to expired premium content.
- **Server-Authoritative Boundaries**: Timed assessments, certificate issuance, live sessions, and commerce purchases strictly require an active online connection and cannot be completed offline.
- **Storage Sandboxing**: All media files are stored exclusively in application-private sandbox directories with directory traversal guards (`..` normalization checks). Downloaded files are never indexed in public media galleries or shared external storage.
- **Learner Isolation**: Download metadata and indexes are partitioned by learner identity (`learnerId`), preventing cross-learner access on shared devices.

## Platform Experience, Notifications, Profile, Settings and Deep Links

Phase 9 introduces the cohesive platform-experience layer, tying together navigation, user identity, cross-device session management, granular notification preferences, comprehensive accessibility/playback settings, and resilient deep linking.

### 1. Centralized Deep Link & Destination Hierarchy (`AppDestination`)
- **Sealed Destination Model**: `AppDestination` defines a closed hierarchy representing all valid navigation targets across the application (`Home`, `Discover`, `Search`, `Course`, `Lesson`, `Assessment`, `Certificates`, `Downloads`, `Subscription`, `Paywall`, `Notifications`, `NotificationPreferences`, `Profile`, `EditProfile`, `Sessions`, `Security`, `Settings`, `Unavailable`).
- **Defensive URI Sanitization**: `AppDestination.parse(Uri)` sanitizes input paths against directory traversal (`..`), double slashes (`//`), backslashes (`\`), and injection characters (`<`, `>`). Malformed or unroutable links safely resolve to a typed `AppDestinationUnavailable` rather than causing runtime routing exceptions or crashes.
- **Auth-Aware Deep Link Preservation**: Navigating to a protected destination (`isProtected == true`) while unauthenticated preserves the target URI via the `?redirect=` parameter. Upon successful login or registration, the router immediately restores and pushes the intended destination.
- **Entitlement-Aware Destination Routing**: Deep links to premium course content evaluate `AccessEvaluator`. If access is denied, the application routes the user to the `PaywallScreen` with attribution query parameters (`?source=deep_link`), preserving the target course ID.

### 2. Notifications Subsystem
- **Notification Hierarchy & Categorization**: `NotificationType` categorizes system events (`courseUpdate`, `lessonReminder`, `liveClassReminder`, `learningReminder`, `assessmentResult`, `certificateIssued`, `downloadCompleted`, `paymentEvent`, `subscriptionEvent`, `systemAnnouncement`, `securityEvent`) with priority weighting (`low`, `normal`, `high`, `urgent`).
- **In-App Notification Center**: Backed by `NotificationController` with optimistic `markAsRead` and `markAllAsRead`, date-bucketed list view, unread badge counter, and pagination support.
- **Resilient Offline Cache**: `NotificationCacheStore` caches up to 50 recent notifications in learner-isolated local storage (`KeyValueStore`), ensuring instant retrieval without network connectivity.
- **Granular Preference Matrix**: `NotificationPreferencesController` manages multichannel preference toggles (push, email, in-app) across learning reminders, updates, and marketing. Security alerts and critical transaction receipts remain non-suppressible.
- **Device Push Token Registration**: `PushNotificationService` registers platform-native push tokens (`APNs` on iOS, `FCM` on Android) with backend device binding while strictly treating push tokens as delivery addresses, never as authorization tokens.

### 3. Learner Profile & Device Session Management
- **Learner Profile**: Encapsulates verified identity, display name, contact information, avatar image, language preference, and learning interests.
- **Active Device Sessions**: `SessionManagementController` displays all logged-in devices (`deviceName`, `platform`, `lastActiveAt`, `isCurrent`). Learners can remotely revoke individual sessions or perform a bulk revocation of all other active sessions with instant confirmation.
- **Account Security & Deletion**: Provides authenticated password changes and a multi-step confirmation dialog for permanent account deletion with explicit confirmation text matching.

### 4. Settings, Preferences, & Accessibility
- **Reactive Settings Domain**: `AppSettings` contains nested immutable sub-configurations for `AppearanceSettings`, `PlaybackSettings`, `DownloadPreferences`, `AccessibilitySettings`, and `PrivacySettings`.
- **Dynamic Theming**: `themeModeProvider` reactively listens to `settingsControllerProvider`, seamlessly updating Flutter's `ThemeMode` (`system`, `light`, `dark`).
- **Accessibility & Motion Controls**: Supports explicit high-contrast presentation and reduced motion preferences, disabling non-essential decorative animations across UI components.
- **Data & Storage Separation**: Cache management is strictly decoupled from offline media storage. Clearing application cache purges network and metadata caches without deleting user-downloaded lesson media.

## Security boundaries

Clients may improve UX with local state but never authorize access. Backend APIs must enforce authentication, authorization, token rotation/revocation, multi-device session policy, deletion verification, validation, rate limits, and audit requirements. Never log credentials, OTPs, tokens, or unnecessary personal data. Build-time defines are public application configuration.

The server remains the sole authority for protected resources. Modifying local device storage or client cache cannot grant access to server-protected media playback streams, assessment answer keys, or downloadable resources.

Valid unexpired persisted sessions survive temporary offline, timeout, and server failures. Secure tokens are removed on explicit logout/deletion or when server authority confirms invalidation. Expired sessions attempt refresh and remain unavailable until refresh succeeds; temporary failures do not silently erase their persisted refresh material.

## Performance

Providers are lazy, width-based layout selection is O(1), and readable content is bounded. Catalog/search use server-side query contracts with cursor pagination and a maximum page size of 50. Grids, lists, and home rails use builder constructors. Search debounces input before issuing queries. Bookmark IDs use sets, course caches use maps, pagination deduplication is O(n), and recently viewed is capped at 20 IDs.

Course outlines use ID-indexed maps and learning history/outbox storage is capped at 100/500 entries. Player callbacks checkpoint locally at five-second movement intervals; backend synchronization is batched and throttled rather than occurring per playback tick. Entitlement resolution evaluates in O(n) where n is the small set of active learner entitlements. Assessment answer maps and question index lookups operate in O(1). Certificate lists and verification lookups are indexed by unique identifier. Download task lookups operate in O(1) via multi-key memory index backed by persistent storage; UI download progress updates are throttled to 250ms intervals.

## Capability Implementation Status Matrix

| Capability / Subsystem | Current Status | Description & Boundary |
| :--- | :--- | :--- |
| **Authentication & Identity** | **IMPLEMENTED** | Multi-session tokens, refresh flow, email/password, Argon2id/bcrypt hashes, account deletion. |
| **Catalog & Discovery** | **IMPLEMENTED** | Server-driven home feed, cursor-paginated search/browse, bookmark & history tracking. |
| **Learning & Progress** | **IMPLEMENTED** | Local-first durable outbox, throttled sync, server revision conflict resolution. |
| **Entitlements & AccessGate** | **IMPLEMENTED** | Multi-grant precedence engine, server-authoritative lease evaluation, inline AccessGate UI. |
| **Assessments & Quizzes** | **IMPLEMENTED** | Server-side grading, attempt limits, timing deadlines, and idempotency keying. |
| **Certificates** | **IMPLEMENTED** | Server-issued credentials, SHA-256 tamper-evident digests, public verification links. This is not a public-key digital signature. |
| **Content Protection** | **DETERRENCE IMPLEMENTED** | `FLAG_SECURE` (Android), `UIScreen.capturedDidChangeNotification` observer (iOS), and app-switcher covers; no hardware DRM claim. |
| **Offline Downloads** | **IMPLEMENTED** | HTTP 206 byte-range streaming, SHA-256 checksums, disk reserve checks, Wi-Fi policies, bounded task store. |
| **In-App Notifications** | **IMPLEMENTED** | Notification center, optimistic mark-all read, unread counts, and user channel preferences. |
| **Native Local Notifications** | **FAIL-CLOSED / BLOCKED** | Production adapter is intentionally unconfigured until platform SDK wiring exists. |
| **Push Notifications (FCM / APNs)** | **FAIL-CLOSED / BLOCKED** | Requires production FCM/APNs credentials; service fails closed in staging/production without fake success. |
| **Commerce (Apple StoreKit 2)** | **FAIL-CLOSED / BLOCKED** | Requires App Store Connect API keys; service fails closed (`503 / 501`) when unconfigured. |
| **Commerce (Google Play Billing)** | **FAIL-CLOSED / BLOCKED** | Requires Google Cloud service account; service fails closed (`503 / 501`) when unconfigured. |
| **Commerce (Stripe Live)** | **FAIL-CLOSED / BLOCKED** | Requires live Stripe secret keys and webhook secret; service fails closed (`503 / 501`) when unconfigured. |
| **Signed Media CDN Origin** | **PARTIAL** | HMAC-SHA256 URL token generation implemented; production requires cloud CDN bucket wiring. |
| **Hardware DRM (Widevine / FairPlay)**| **PLANNED** | Application sandboxing and lease verification active; native CDM decryption pipeline planned. |
| **Analytics & Crash Reporting** | **NO-OP / PLANNED** | Privacy-conscious contract boundaries present; vendor SDK integration planned. |
| **Admin CMS (Phase 9A)** | **PLANNED** | Backend REST endpoints support admin roles; dedicated admin web portal planned for Phase 9A. |

