import 'package:learning_platform/features/downloads/domain/download_authorization.dart';
import 'package:learning_platform/features/downloads/domain/download_task.dart';

enum DownloadDataErrorKind {
  unauthorized,
  entitlementRequired,
  notDownloadable,
  notFound,
  offline,
  timeout,
  server,
}

final class DownloadDataException implements Exception {
  const DownloadDataException(this.kind, this.message, {this.cause});
  final DownloadDataErrorKind kind;
  final String message;
  final Object? cause;

  @override
  String toString() => 'DownloadDataException($kind, $message)';
}

abstract interface class DownloadDataSource {
  Future<DownloadAuthorization> fetchDownloadAuthorization({
    required String learnerId,
    required DownloadResourceType resourceType,
    required String resourceId,
    DownloadQuality quality = DownloadQuality.standard,
  });

  Future<List<DownloadRevalidationResult>> revalidateDownloads({
    required String learnerId,
    required List<String> resourceIds,
  });
}
