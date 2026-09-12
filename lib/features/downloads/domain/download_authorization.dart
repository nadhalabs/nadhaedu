import 'package:learning_platform/features/content_protection/domain/content_protection_policy.dart';
import 'package:learning_platform/features/downloads/domain/download_task.dart';

final class DownloadAuthorizationSubtitle {
  const DownloadAuthorizationSubtitle({
    required this.id,
    required this.label,
    required this.languageCode,
    required this.url,
  });

  factory DownloadAuthorizationSubtitle.fromJson(Map<String, Object?> json) =>
      DownloadAuthorizationSubtitle(
        id: json['id']! as String,
        label: json['label']! as String,
        languageCode: json['languageCode']! as String,
        url: json['url']! as String,
      );

  final String id;
  final String label;
  final String languageCode;
  final String url;
}

final class DownloadAuthorization {
  const DownloadAuthorization({
    required this.resourceType,
    required this.resourceId,
    required this.courseId,
    this.lessonId,
    required this.title,
    required this.courseTitle,
    required this.remoteAssetId,
    required this.downloadUrl,
    required this.downloadToken,
    required this.expiresAt,
    required this.entitlementExpiresAt,
    required this.sizeBytes,
    required this.checksumSha256,
    required this.assetVersion,
    required this.quality,
    required this.contentType,
    required this.protectionPolicy,
    required this.subtitles,
    required this.isDownloadable,
  });

  factory DownloadAuthorization.fromJson(Map<String, Object?> json) =>
      DownloadAuthorization(
        resourceType: DownloadResourceType.values.byName(
          json['resourceType']! as String,
        ),
        resourceId: json['resourceId']! as String,
        courseId: json['courseId']! as String,
        lessonId: json['lessonId'] as String?,
        title: json['title']! as String,
        courseTitle: json['courseTitle']! as String,
        remoteAssetId: json['remoteAssetId']! as String,
        downloadUrl: json['downloadUrl']! as String,
        downloadToken: json['downloadToken']! as String,
        expiresAt: DateTime.parse(json['expiresAt']! as String).toUtc(),
        entitlementExpiresAt: DateTime.parse(
          json['entitlementExpiresAt']! as String,
        ).toUtc(),
        sizeBytes: json['sizeBytes']! as int,
        checksumSha256: json['checksumSha256']! as String,
        assetVersion: json['assetVersion']! as String,
        quality: DownloadQuality.values.byName(json['quality']! as String),
        contentType: json['contentType']! as String,
        protectionPolicy: ContentProtectionPolicy.values.byName(
          json['protectionPolicy']! as String,
        ),
        subtitles: (json['subtitles'] as List<Object?>? ?? const [])
            .map(
              (x) => DownloadAuthorizationSubtitle.fromJson(
                Map<String, Object?>.from(x! as Map),
              ),
            )
            .toList(growable: false),
        isDownloadable: json['isDownloadable']! as bool,
      );

  final DownloadResourceType resourceType;
  final String resourceId;
  final String courseId;
  final String? lessonId;
  final String title;
  final String courseTitle;
  final String remoteAssetId;
  final String downloadUrl;
  final String downloadToken;
  final DateTime expiresAt;
  final DateTime entitlementExpiresAt;
  final int sizeBytes;
  final String checksumSha256;
  final String assetVersion;
  final DownloadQuality quality;
  final String contentType;
  final ContentProtectionPolicy protectionPolicy;
  final List<DownloadAuthorizationSubtitle> subtitles;
  final bool isDownloadable;
}

enum RevalidationStatus { valid, expired, revoked, notFound }

final class DownloadRevalidationResult {
  const DownloadRevalidationResult({
    required this.resourceId,
    required this.status,
    this.entitlementExpiresAt,
    this.assetVersion,
    required this.message,
  });

  factory DownloadRevalidationResult.fromJson(Map<String, Object?> json) =>
      DownloadRevalidationResult(
        resourceId: json['resourceId']! as String,
        status: RevalidationStatus.values.byName(json['status']! as String),
        entitlementExpiresAt: json['entitlementExpiresAt'] == null
            ? null
            : DateTime.parse(json['entitlementExpiresAt']! as String).toUtc(),
        assetVersion: json['assetVersion'] as String?,
        message: json['message']! as String,
      );

  final String resourceId;
  final RevalidationStatus status;
  final DateTime? entitlementExpiresAt;
  final String? assetVersion;
  final String message;
}
