import 'package:flutter_test/flutter_test.dart';
import 'package:learning_platform/features/content_protection/domain/content_protection_policy.dart';
import 'package:learning_platform/features/downloads/domain/download_task.dart';

void main() {
  group('DownloadTask Domain Tests', () {
    final now = DateTime.utc(2026, 8, 31, 12, 0, 0);

    test('calculates progress accurately', () {
      final task = DownloadTask(
        id: 'task_1',
        learnerId: 'learner_1',
        resourceType: DownloadResourceType.video,
        resourceId: 'asset_1',
        courseId: 'course_1',
        title: 'Introduction',
        courseTitle: 'Flutter Mastery',
        remoteAssetId: 'remote_1',
        state: DownloadState.downloading,
        bytesDownloaded: 50 * 1024 * 1024,
        totalBytes: 100 * 1024 * 1024,
        createdAt: now,
        updatedAt: now,
      );

      expect(task.progress, closeTo(0.5, 0.001));
      expect(task.isActive, isTrue);
      expect(task.isCompleted, isFalse);
      expect(task.isFailed, isFalse);
      expect(task.isPaused, isFalse);
    });

    test('validates offline entitlement expiration window', () {
      final validTask = DownloadTask(
        id: 'task_valid',
        learnerId: 'learner_1',
        resourceType: DownloadResourceType.video,
        resourceId: 'asset_1',
        courseId: 'course_1',
        title: 'Introduction',
        courseTitle: 'Flutter Mastery',
        remoteAssetId: 'remote_1',
        state: DownloadState.completed,
        bytesDownloaded: 100,
        totalBytes: 100,
        createdAt: now,
        updatedAt: now,
        entitlementExpiresAt: DateTime.now().toUtc().add(
          const Duration(days: 5),
        ),
        localRelativePath: 'courses/course_1/asset_1.mp4',
      );

      expect(validTask.isOfflineEntitlementValid, isTrue);
      expect(validTask.canPlayOffline, isTrue);

      final expiredTask = validTask.copyWith(
        entitlementExpiresAt: DateTime.now().toUtc().subtract(
          const Duration(hours: 1),
        ),
      );

      expect(expiredTask.isOfflineEntitlementValid, isFalse);
      expect(expiredTask.canPlayOffline, isFalse);

      final missingLeaseTask = DownloadTask(
        id: 'task_missing_lease',
        learnerId: 'learner_1',
        resourceType: DownloadResourceType.video,
        resourceId: 'asset_1',
        courseId: 'course_1',
        title: 'Introduction',
        courseTitle: 'Flutter Mastery',
        remoteAssetId: 'remote_1',
        state: DownloadState.completed,
        bytesDownloaded: 100,
        totalBytes: 100,
        createdAt: now,
        updatedAt: now,
        localRelativePath: 'courses/course_1/asset_1.mp4',
      );

      expect(missingLeaseTask.isOfflineEntitlementValid, isFalse);
      expect(missingLeaseTask.canPlayOffline, isFalse);
    });

    test('serializes and deserializes JSON with failure and subtitles', () {
      final original = DownloadTask(
        id: 'task_full',
        learnerId: 'learner_123',
        resourceType: DownloadResourceType.video,
        resourceId: 'res_456',
        courseId: 'course_789',
        lessonId: 'lesson_101',
        title: 'Deep Dive Lecture',
        courseTitle: 'Architecture Mastery',
        remoteAssetId: 'asset_remote_1',
        state: DownloadState.failed,
        bytesDownloaded: 2048,
        totalBytes: 8192,
        createdAt: now,
        updatedAt: now,
        completedAt: null,
        expiresAt: now.add(const Duration(hours: 2)),
        entitlementExpiresAt: now.add(const Duration(days: 7)),
        retryCount: 2,
        failure: const DownloadFailure(
          reason: DownloadFailureReason.networkUnavailable,
          message: 'Connection dropped',
          statusCode: 503,
          retryable: true,
        ),
        localRelativePath: 'courses/course_789/res_456.mp4',
        checksum: 'sha256_mock_hash',
        assetVersion: 'v2.1',
        quality: DownloadQuality.high,
        protectionPolicy: ContentProtectionPolicy.blockCaptureWhereSupported,
        subtitles: const [
          DownloadedSubtitle(
            id: 'sub_en',
            label: 'English',
            languageCode: 'en',
            localRelativePath: 'courses/course_789/subtitles/sub_en.vtt',
          ),
        ],
      );

      final json = original.toJson();
      final reconstructed = DownloadTask.fromJson(json);

      expect(reconstructed.id, original.id);
      expect(reconstructed.learnerId, original.learnerId);
      expect(reconstructed.resourceType, original.resourceType);
      expect(reconstructed.resourceId, original.resourceId);
      expect(reconstructed.courseId, original.courseId);
      expect(reconstructed.lessonId, original.lessonId);
      expect(reconstructed.title, original.title);
      expect(reconstructed.state, DownloadState.failed);
      expect(
        reconstructed.failure?.reason,
        DownloadFailureReason.networkUnavailable,
      );
      expect(reconstructed.failure?.statusCode, 503);
      expect(reconstructed.subtitles.length, 1);
      expect(reconstructed.subtitles.first.label, 'English');
      expect(reconstructed.quality, DownloadQuality.high);
    });
  });
}
