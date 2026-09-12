# Nadha Edu media V1

## Architecture and changes

1. **Existing architecture:** `MediaAsset.id` is the database identity, `asset_id` is the public application identifier, and `origin_key` locates provider media. Existing kinds include HLS, download, subtitle and thumbnail. Assets optionally bind to `LessonContentItem`; legacy lessons use `content_ref`. Progress was lesson-wide. Courses had no cover field.
2. **Reused:** those identities, ordered content authoring, lesson/course entitlement resolution, CMS content-manager permissions, the existing Flutter video player, downloads, and lesson completion aggregation. No hierarchy or demo data was removed.
3. **Migration:** `0009_media_v1` adds nullable provider identifiers plus generic metadata to MediaAsset, a nullable course `cover_reference`, and `video_watch_progress`. Existing IDs, lessons, content items, progress and other history remain intact. Readiness now requires this migration. Existing audit-index metadata was brought into agreement with its earlier migration; no new audit index is created.
4. **Provider integration:** backend-only `LEARNING_PLATFORM_CLOUDINARY_CLOUD_NAME`, `LEARNING_PLATFORM_CLOUDINARY_API_KEY`, and `LEARNING_PLATFORM_CLOUDINARY_API_SECRET`. Configuration is optional for legacy deployments; partially configured credentials fail runtime validation. Cloudinary implementation is isolated in `media_provider.py`. The API secret is excluded from settings repr and never returned.
5. **CMS upload:** Add content → video → choose file → direct, sequential 10 MB browser chunks → backend verification → save content item. The backend issues a one-hour, user/target-bound upload ticket and signs a unique non-overwriting public ID. Cloudinary's signed-upload validity is one hour. The backend reads authoritative metadata from Cloudinary; client-supplied asset URLs and duration are not accepted. No FastAPI video buffering. The browser supports videos up to 2 GB and images up to 10 MB. Interrupted transfers restart; finalization retries reuse the uploaded file/ticket.
6. **Video thumbnails:** authenticated, provider-generated first-frame poster, CMS thumbnail and browser preview, student poster, and fallback UI. A custom video thumbnail editor/upload is deferred.
7. **Offering covers:** public image uploads attach to the existing course/offering, appear in the reopened CMS editor and student CourseCard, and fall back to existing artwork if missing or broken. The canonical Subject is unchanged. The generic cover reference can be replaced independently of course identity.
8. **Student player:** play/pause, bounded seek slider, time/duration, mute/unmute, playback speed, full-window overlay, loading/buffering, poster, and retry. Controls wrap on narrow screens. Legacy lesson navigation keys the player by asset to avoid carrying a controller into another lesson.
9. **Watch/resume/completion:** progress is keyed by learner and stable MediaAsset database ID; the immutable content binding supplies lesson/item ownership. Backend resume overrides the former lesson-wide position for each remote video. Updates occur every ten seconds and on pause/background. The backend limits new progress to server elapsed time at maximum supported 2x speed, caps stale windows at 30 seconds, and never accumulates tolerance. Rewind changes resume without reducing furthest progress. Completion occurs at 95%. Every published required video and quiz must finish; mixed note/resource lessons retain their explicit lesson-completion action. Pure video lessons have no manual completion button. Existing completed history is not reset.
10. **Access control:** existing learner authentication, publication checks and lesson entitlement checks precede playback and every watch request. Mismatched item/asset references fail closed. Authenticated Cloudinary video URLs have a backend-signed expiry; covers are intentionally public. Unconfigured/unknown providers do not silently authorize new provider playback.
11. **Replaceability:** provider ID, origin reference and metadata can change while MediaAsset database/public IDs and all lesson/content/progress IDs remain stable. V1 replacement preserves asset identity only on courses without learner history; historically used videos must be added as new content rather than silently replacing their meaning. Provider objects are never physically deleted by this workflow.

## Validation

12. **Backend:** 132 passed, zero skipped, including PostgreSQL concurrency/API tests, Redis integration, and preservation of existing IDs/history across migrations. `alembic check` reports no schema drift.
13. **Student:** analyzer clean; 257 tests passed; web build passed.
14. **CMS:** analyzer clean; 49 tests passed; web build passed. The build reports an existing optional Cupertino font-family warning; compilation succeeds.
15. **Regressions:** repaired the pre-existing audit-index model/migration mismatch. Updated the exact-revision assertion for the additive migration and strengthened mixed-content completion tests to require watched video as well as a passed quiz. During implementation, cover-response filtering and stale legacy player identity were fixed. Reused integration databases exposed a fixed reset-code fixture collision; the final full run used fresh disposable databases and passed without changing that test.

Commands:

- `ops/scripts/test_backend_integration.sh` with fresh isolated PostgreSQL databases, `ACADEMIC_MIGRATION_TEST_URL`, and Redis.
- `flutter analyze --no-pub`, `flutter test --no-pub`, `flutter build web --no-pub` in the student root and CMS directory.
- Focused backend provider, permissions, asset creation, relationship, clock-budget, watch/resume, multi-video, cover and history-preservation tests.
- Focused student player tests for asset selection, authoritative resume, seek clamping, server completion and retry; CMS upload-state, interrupted-upload, and cover-thumbnail tests.

## Deployment and limits

Run `alembic upgrade head` before deploying the backend. Configure credentials only in the backend environment. Keep existing CDN configuration for provider-less demo/legacy assets. Verify one real authenticated video upload/play/seek/resume and one image upload in the target Cloudinary account before rollout; no live Cloudinary credentials were supplied for this implementation.

Cloudinary delivery uses its time-limited download API for authenticated media rather than introducing adaptive streaming infrastructure. This delivery path has additional bandwidth cost and no CDN caching; verify account limits and real browser/mobile range playback in staging. Sources: [Cloudinary access control](https://cloudinary.com/documentation/control_access_to_media) and [upload API](https://cloudinary.com/documentation/image_upload_api_reference).

16. **Intentionally deferred:** Custom video thumbnails, resumable cross-session uploads, provider deletion/orphan cleanup, automatic URL renewal, new offline watch-credit protocols, future providers, DRM, captions and all requested out-of-scope features are deferred. Existing downloaded files still play through the existing compatibility path; authoritative required-video completion needs online progress. A playback URL that expires during later range access uses the retry/resume path. This is lightweight progression validation, not proof of attention or DRM.

17. **Final verdict:** Implementation and required automated validation are complete. No deployment was performed. Automated validation alone does not replace the live-provider smoke test; production sign-off remains pending that test.
