import 'package:learning_platform/features/downloads/data/download_data_source.dart';
import 'package:learning_platform/features/downloads/domain/download_authorization.dart';
import 'package:learning_platform/features/downloads/domain/download_task.dart';

final class UnconfiguredDownloadDataSource implements DownloadDataSource {
  const UnconfiguredDownloadDataSource();

  @override
  Future<DownloadAuthorization> fetchDownloadAuthorization({
    required String learnerId,
    required DownloadResourceType resourceType,
    required String resourceId,
    DownloadQuality quality = DownloadQuality.standard,
  }) async {
    throw const DownloadDataException(
      DownloadDataErrorKind.server,
      'Downloads service is unconfigured.',
    );
  }

  @override
  Future<List<DownloadRevalidationResult>> revalidateDownloads({
    required String learnerId,
    required List<String> resourceIds,
  }) async {
    throw const DownloadDataException(
      DownloadDataErrorKind.server,
      'Downloads service is unconfigured.',
    );
  }
}
