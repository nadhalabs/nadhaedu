import 'package:learning_platform/core/errors/result.dart';
import 'package:learning_platform/core/networking/api_client.dart';
import 'package:learning_platform/features/downloads/data/download_data_source.dart';
import 'package:learning_platform/features/downloads/domain/download_authorization.dart';
import 'package:learning_platform/features/downloads/domain/download_task.dart';

final class RemoteDownloadDataSource implements DownloadDataSource {
  const RemoteDownloadDataSource(this._client);
  final ApiClient _client;

  @override
  Future<DownloadAuthorization> fetchDownloadAuthorization({
    required String learnerId,
    required DownloadResourceType resourceType,
    required String resourceId,
    DownloadQuality quality = DownloadQuality.standard,
  }) async {
    final result = await _client.post(
      '/api/v1/downloads/authorize',
      body: {
        'resourceType': resourceType.name,
        'resourceId': resourceId,
        'quality': quality.name,
      },
    );

    return switch (result) {
      Success(value: final v) => DownloadAuthorization.fromJson(v),
      Failure(failure: final f) => throw _mapFailure(f),
    };
  }

  @override
  Future<List<DownloadRevalidationResult>> revalidateDownloads({
    required String learnerId,
    required List<String> resourceIds,
  }) async {
    final result = await _client.post(
      '/api/v1/downloads/revalidate',
      body: {'resourceIds': resourceIds},
    );

    return switch (result) {
      Success(value: final v) =>
        (v['results'] as List<Object?>? ?? const [])
            .map(
              (x) => DownloadRevalidationResult.fromJson(
                Map<String, Object?>.from(x! as Map),
              ),
            )
            .toList(growable: false),
      Failure(failure: final f) => throw _mapFailure(f),
    };
  }

  DownloadDataException _mapFailure(Object f) {
    if (f is ApiFailure) {
      final kind = switch (f.kind) {
        ApiErrorKind.entitlementRequired =>
          DownloadDataErrorKind.entitlementRequired,
        ApiErrorKind.authenticationRequired ||
        ApiErrorKind.accessDenied => DownloadDataErrorKind.unauthorized,
        ApiErrorKind.notFound => DownloadDataErrorKind.notFound,
        ApiErrorKind.offline => DownloadDataErrorKind.offline,
        ApiErrorKind.timeout => DownloadDataErrorKind.timeout,
        _ =>
          f.code == 'DOWNLOAD_NOT_PERMITTED'
              ? DownloadDataErrorKind.notDownloadable
              : DownloadDataErrorKind.server,
      };
      return DownloadDataException(kind, f.message, cause: f);
    }
    return DownloadDataException(
      DownloadDataErrorKind.server,
      'Download authorization failed.',
      cause: f,
    );
  }
}
