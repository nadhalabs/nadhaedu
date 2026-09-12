import 'package:learning_platform/features/content_protection/domain/content_protection_policy.dart';
import 'package:learning_platform/features/downloads/data/download_data_source.dart';
import 'package:learning_platform/features/downloads/domain/download_authorization.dart';
import 'package:learning_platform/features/downloads/domain/download_task.dart';

final class FoundationDownloadDataSource implements DownloadDataSource {
  const FoundationDownloadDataSource();

  @override
  Future<DownloadAuthorization> fetchDownloadAuthorization({
    required String learnerId,
    required DownloadResourceType resourceType,
    required String resourceId,
    DownloadQuality quality = DownloadQuality.standard,
  }) async {
    final now = DateTime.now().toUtc();
    return DownloadAuthorization(
      resourceType: resourceType,
      resourceId: resourceId,
      courseId: 'course_foundation',
      lessonId: resourceType == DownloadResourceType.video ? resourceId : null,
      title: 'Foundation Lesson Title',
      courseTitle: 'Foundation Course Title',
      remoteAssetId: 'asset_$resourceId',
      downloadUrl:
          'https://media.cdn.example.com/downloads/asset_$resourceId?token=dev_token',
      downloadToken: 'dev_token',
      expiresAt: now.add(const Duration(hours: 2)),
      entitlementExpiresAt: now.add(const Duration(days: 7)),
      sizeBytes: 1024 * 1024 * 25, // 25 MB
      checksumSha256: 'dev_checksum_$resourceId',
      assetVersion: 'v1.0',
      quality: quality,
      contentType: 'video/mp4',
      protectionPolicy: ContentProtectionPolicy.blockCaptureWhereSupported,
      subtitles: [
        DownloadAuthorizationSubtitle(
          id: 'sub_en_$resourceId',
          label: 'English',
          languageCode: 'en',
          url:
              'https://media.cdn.example.com/subtitles/sub_en_$resourceId.vtt?token=dev_token',
        ),
      ],
      isDownloadable: true,
    );
  }

  @override
  Future<List<DownloadRevalidationResult>> revalidateDownloads({
    required String learnerId,
    required List<String> resourceIds,
  }) async {
    final now = DateTime.now().toUtc();
    return resourceIds
        .map(
          (id) => DownloadRevalidationResult(
            resourceId: id,
            status: RevalidationStatus.valid,
            entitlementExpiresAt: now.add(const Duration(days: 7)),
            assetVersion: 'v1.0',
            message: 'Foundation entitlement valid',
          ),
        )
        .toList(growable: false);
  }
}
