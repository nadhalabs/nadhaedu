import 'package:learning_platform/features/content_protection/domain/content_protection_policy.dart';

enum DownloadState {
  queued,
  preparing,
  downloading,
  paused,
  completed,
  failed,
  expired,
  deleting,
  cancelled;

  bool get isActive =>
      this == DownloadState.queued ||
      this == DownloadState.preparing ||
      this == DownloadState.downloading;

  bool get isTerminal =>
      this == DownloadState.completed ||
      this == DownloadState.failed ||
      this == DownloadState.expired ||
      this == DownloadState.cancelled;
}

enum DownloadResourceType { video, audio, document, resource, subtitle, course }

enum DownloadQuality {
  dataSaver,
  standard,
  high;

  String get label => switch (this) {
    DownloadQuality.dataSaver => 'Data Saver (480p)',
    DownloadQuality.standard => 'Standard (720p)',
    DownloadQuality.high => 'High (1080p)',
  };
}

enum DownloadFailureReason {
  networkUnavailable,
  authorizationExpired,
  entitlementExpired,
  insufficientStorage,
  resourceUnavailable,
  integrityFailure,
  unsupportedPlatform,
  permissionDenied,
  serverFailure,
  unknown;

  bool get isRetryable => switch (this) {
    DownloadFailureReason.networkUnavailable ||
    DownloadFailureReason.authorizationExpired ||
    DownloadFailureReason.serverFailure ||
    DownloadFailureReason.unknown => true,
    DownloadFailureReason.entitlementExpired ||
    DownloadFailureReason.insufficientStorage ||
    DownloadFailureReason.resourceUnavailable ||
    DownloadFailureReason.integrityFailure ||
    DownloadFailureReason.unsupportedPlatform ||
    DownloadFailureReason.permissionDenied => false,
  };
}

final class DownloadFailure implements Exception {
  const DownloadFailure({
    required this.reason,
    required this.message,
    this.statusCode,
    this.retryable = true,
  });

  factory DownloadFailure.fromJson(Map<String, Object?> json) =>
      DownloadFailure(
        reason: DownloadFailureReason.values.byName(json['reason']! as String),
        message: json['message']! as String,
        statusCode: json['statusCode'] as int?,
        retryable: json['retryable'] as bool? ?? true,
      );

  final DownloadFailureReason reason;
  final String message;
  final int? statusCode;
  final bool retryable;

  Map<String, Object?> toJson() => {
    'reason': reason.name,
    'message': message,
    if (statusCode != null) 'statusCode': statusCode,
    'retryable': retryable,
  };
}

final class DownloadedSubtitle {
  const DownloadedSubtitle({
    required this.id,
    required this.label,
    required this.languageCode,
    required this.localRelativePath,
    this.remoteUrl,
  });

  factory DownloadedSubtitle.fromJson(Map<String, Object?> json) =>
      DownloadedSubtitle(
        id: json['id']! as String,
        label: json['label']! as String,
        languageCode: json['languageCode']! as String,
        localRelativePath: json['localRelativePath']! as String,
        remoteUrl: json['remoteUrl'] as String?,
      );

  final String id;
  final String label;
  final String languageCode;
  final String localRelativePath;
  final String? remoteUrl;

  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'languageCode': languageCode,
    'localRelativePath': localRelativePath,
    if (remoteUrl != null) 'remoteUrl': remoteUrl,
  };
}

final class DownloadTask {
  const DownloadTask({
    required this.id,
    required this.learnerId,
    required this.resourceType,
    required this.resourceId,
    required this.courseId,
    this.lessonId,
    required this.title,
    required this.courseTitle,
    required this.remoteAssetId,
    required this.state,
    required this.bytesDownloaded,
    required this.totalBytes,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    this.expiresAt,
    this.entitlementExpiresAt,
    this.retryCount = 0,
    this.failure,
    this.localRelativePath,
    this.checksum,
    this.assetVersion,
    this.quality = DownloadQuality.standard,
    this.protectionPolicy = ContentProtectionPolicy.blockCaptureWhereSupported,
    this.subtitles = const [],
  });

  factory DownloadTask.fromJson(Map<String, Object?> json) => DownloadTask(
    id: json['id']! as String,
    learnerId: json['learnerId']! as String,
    resourceType: DownloadResourceType.values.byName(
      json['resourceType']! as String,
    ),
    resourceId: json['resourceId']! as String,
    courseId: json['courseId']! as String,
    lessonId: json['lessonId'] as String?,
    title: json['title']! as String,
    courseTitle: json['courseTitle']! as String,
    remoteAssetId: json['remoteAssetId']! as String,
    state: DownloadState.values.byName(json['state']! as String),
    bytesDownloaded: json['bytesDownloaded']! as int,
    totalBytes: json['totalBytes']! as int,
    createdAt: DateTime.parse(json['createdAt']! as String).toUtc(),
    updatedAt: DateTime.parse(json['updatedAt']! as String).toUtc(),
    completedAt: json['completedAt'] == null
        ? null
        : DateTime.parse(json['completedAt']! as String).toUtc(),
    expiresAt: json['expiresAt'] == null
        ? null
        : DateTime.parse(json['expiresAt']! as String).toUtc(),
    entitlementExpiresAt: json['entitlementExpiresAt'] == null
        ? null
        : DateTime.parse(json['entitlementExpiresAt']! as String).toUtc(),
    retryCount: json['retryCount'] as int? ?? 0,
    failure: json['failure'] == null
        ? null
        : DownloadFailure.fromJson(
            Map<String, Object?>.from(json['failure']! as Map),
          ),
    localRelativePath: json['localRelativePath'] as String?,
    checksum: json['checksum'] as String?,
    assetVersion: json['assetVersion'] as String?,
    quality: json['quality'] == null
        ? DownloadQuality.standard
        : DownloadQuality.values.byName(json['quality']! as String),
    protectionPolicy: json['protectionPolicy'] == null
        ? ContentProtectionPolicy.blockCaptureWhereSupported
        : ContentProtectionPolicy.values.byName(
            json['protectionPolicy']! as String,
          ),
    subtitles: (json['subtitles'] as List<Object?>? ?? const [])
        .map(
          (x) =>
              DownloadedSubtitle.fromJson(Map<String, Object?>.from(x! as Map)),
        )
        .toList(growable: false),
  );

  final String id;
  final String learnerId;
  final DownloadResourceType resourceType;
  final String resourceId;
  final String courseId;
  final String? lessonId;
  final String title;
  final String courseTitle;
  final String remoteAssetId;
  final DownloadState state;
  final int bytesDownloaded;
  final int totalBytes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final DateTime? expiresAt;
  final DateTime? entitlementExpiresAt;
  final int retryCount;
  final DownloadFailure? failure;
  final String? localRelativePath;
  final String? checksum;
  final String? assetVersion;
  final DownloadQuality quality;
  final ContentProtectionPolicy protectionPolicy;
  final List<DownloadedSubtitle> subtitles;

  double get progress => totalBytes <= 0
      ? (state == DownloadState.completed ? 1.0 : 0.0)
      : (bytesDownloaded / totalBytes).clamp(0.0, 1.0);

  bool get isCompleted => state == DownloadState.completed;
  bool get isFailed => state == DownloadState.failed;
  bool get isPaused => state == DownloadState.paused;
  bool get isActive => state.isActive;

  bool get isOfflineEntitlementValid {
    if (entitlementExpiresAt == null) return false;
    return DateTime.now().toUtc().isBefore(entitlementExpiresAt!);
  }

  bool get canPlayOffline =>
      isCompleted && isOfflineEntitlementValid && localRelativePath != null;

  DownloadTask copyWith({
    String? remoteAssetId,
    DownloadState? state,
    int? bytesDownloaded,
    int? totalBytes,
    DateTime? updatedAt,
    DateTime? completedAt,
    DateTime? expiresAt,
    DateTime? entitlementExpiresAt,
    int? retryCount,
    DownloadFailure? failure,
    bool clearFailure = false,
    String? localRelativePath,
    String? checksum,
    String? assetVersion,
    DownloadQuality? quality,
    ContentProtectionPolicy? protectionPolicy,
    List<DownloadedSubtitle>? subtitles,
  }) => DownloadTask(
    id: id,
    learnerId: learnerId,
    resourceType: resourceType,
    resourceId: resourceId,
    courseId: courseId,
    lessonId: lessonId,
    title: title,
    courseTitle: courseTitle,
    remoteAssetId: remoteAssetId ?? this.remoteAssetId,
    state: state ?? this.state,
    bytesDownloaded: bytesDownloaded ?? this.bytesDownloaded,
    totalBytes: totalBytes ?? this.totalBytes,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    completedAt: completedAt ?? this.completedAt,
    expiresAt: expiresAt ?? this.expiresAt,
    entitlementExpiresAt: entitlementExpiresAt ?? this.entitlementExpiresAt,
    retryCount: retryCount ?? this.retryCount,
    failure: clearFailure ? null : (failure ?? this.failure),
    localRelativePath: localRelativePath ?? this.localRelativePath,
    checksum: checksum ?? this.checksum,
    assetVersion: assetVersion ?? this.assetVersion,
    quality: quality ?? this.quality,
    protectionPolicy: protectionPolicy ?? this.protectionPolicy,
    subtitles: subtitles ?? this.subtitles,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'learnerId': learnerId,
    'resourceType': resourceType.name,
    'resourceId': resourceId,
    'courseId': courseId,
    if (lessonId != null) 'lessonId': lessonId,
    'title': title,
    'courseTitle': courseTitle,
    'remoteAssetId': remoteAssetId,
    'state': state.name,
    'bytesDownloaded': bytesDownloaded,
    'totalBytes': totalBytes,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
    if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
    if (entitlementExpiresAt != null)
      'entitlementExpiresAt': entitlementExpiresAt!.toIso8601String(),
    'retryCount': retryCount,
    if (failure != null) 'failure': failure!.toJson(),
    if (localRelativePath != null) 'localRelativePath': localRelativePath,
    if (checksum != null) 'checksum': checksum,
    if (assetVersion != null) 'assetVersion': assetVersion,
    'quality': quality.name,
    'protectionPolicy': protectionPolicy.name,
    'subtitles': subtitles.map((s) => s.toJson()).toList(growable: false),
  };
}
