import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_platform/core/connectivity/network_monitor.dart';
import 'package:learning_platform/features/content_protection/domain/content_protection_policy.dart';
import 'package:learning_platform/features/downloads/application/download_manager.dart';
import 'package:learning_platform/features/downloads/data/download_data_source.dart';
import 'package:learning_platform/features/downloads/data/download_file_manager.dart';
import 'package:learning_platform/features/downloads/data/download_repository_impl.dart';
import 'package:learning_platform/features/downloads/data/download_task_store.dart';
import 'package:learning_platform/features/downloads/domain/download_authorization.dart';
import 'package:learning_platform/features/downloads/domain/download_task.dart';

import '../../../helpers/memory_key_value_store.dart';

final class _WifiMonitor implements NetworkMonitor {
  @override
  Future<NetworkStatus> currentStatus() async => NetworkStatus.wifi;
  @override
  Stream<NetworkStatus> get status => const Stream.empty();
}

final class _FileManager implements DownloadFileManager {
  _FileManager(this.root);
  final Directory root;
  @override
  Future<String> computeSha256(String relativePath) async =>
      (await sha256
              .bind(File(await resolveAbsolutePath(relativePath)).openRead())
              .first)
          .toString();
  @override
  Future<void> deleteDirectory(String relativePath) async {}
  @override
  Future<void> deleteFile(String relativePath) async {
    final file = File(await resolveAbsolutePath(relativePath));
    if (await file.exists()) await file.delete();
  }

  @override
  Future<void> ensureDirectoryExists(String directoryPath) =>
      Directory(directoryPath).create(recursive: true);
  @override
  Future<bool> fileExists(String relativePath) async =>
      File(await resolveAbsolutePath(relativePath)).exists();
  @override
  Future<int> getAvailableDiskSpace() async => 1024 * 1024 * 1024;
  @override
  Future<int> getFileSize(String relativePath) async =>
      File(await resolveAbsolutePath(relativePath)).length();
  @override
  Future<String> getRootDirectory() async => root.path;
  @override
  Future<String> resolveAbsolutePath(String relativePath) async =>
      '${root.path}/$relativePath';
}

final class _AuthorizationSource implements DownloadDataSource {
  const _AuthorizationSource(this.bytes);
  final List<int> bytes;
  @override
  Future<DownloadAuthorization> fetchDownloadAuthorization({
    required String learnerId,
    required DownloadResourceType resourceType,
    required String resourceId,
    DownloadQuality quality = DownloadQuality.standard,
  }) async => DownloadAuthorization(
    resourceType: resourceType,
    resourceId: resourceId,
    courseId: 'course',
    title: 'Lesson',
    courseTitle: 'Course',
    remoteAssetId: 'asset',
    downloadUrl: 'https://media.example.test/asset.mp4?token=signed',
    downloadToken: 'signed',
    expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
    entitlementExpiresAt: DateTime.now().toUtc().add(const Duration(days: 1)),
    sizeBytes: bytes.length,
    checksumSha256: sha256.convert(bytes).toString(),
    assetVersion: 'v1',
    quality: quality,
    contentType: 'video/mp4',
    protectionPolicy: ContentProtectionPolicy.blockCaptureWhereSupported,
    subtitles: const [],
    isDownloadable: true,
  );
  @override
  Future<List<DownloadRevalidationResult>> revalidateDownloads({
    required String learnerId,
    required List<String> resourceIds,
  }) async => const [];
}

final class _ResponseAdapter implements HttpClientAdapter {
  const _ResponseAdapter(this.bytes, this.statusCode, {this.contentRange});
  final List<int> bytes;
  final int statusCode;
  final String? contentRange;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromBytes(
    bytes,
    statusCode,
    headers: {
      if (contentRange != null) 'content-range': [contentRange!],
    },
  );
  @override
  void close({bool force = false}) {}
}

void main() {
  test('a 200 response replaces a partial file instead of appending', () async {
    final root = await Directory.systemTemp.createTemp('download_resume_200');
    addTearDown(() => root.delete(recursive: true));
    final bytes = [1, 2, 3, 4, 5];
    final file = File('${root.path}/courses/course/resource_standard.mp4');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes.take(2).toList());

    final store = MemoryKeyValueStore();
    final files = _FileManager(root);
    final repository = DownloadRepositoryImpl(
      remote: _AuthorizationSource(bytes),
      taskStore: DownloadTaskStore(store),
      fileManager: files,
      preferencesStore: store,
    );
    final dio = Dio()
      ..httpClientAdapter = _ResponseAdapter(bytes, HttpStatus.ok);
    final manager = DownloadManager(
      repository: repository,
      fileManager: files,
      networkMonitor: _WifiMonitor(),
      dio: dio,
    );
    addTearDown(manager.dispose);

    final completed = manager.taskUpdates.firstWhere(
      (task) => task.isCompleted,
    );
    await manager.enqueueDownload(
      learnerId: 'learner',
      resourceType: DownloadResourceType.video,
      resourceId: 'resource',
      courseId: 'course',
      title: 'Lesson',
      courseTitle: 'Course',
    );
    await completed.timeout(const Duration(seconds: 2));
    expect(await file.readAsBytes(), bytes);
  });

  test('a mismatched 206 content range fails without completing', () async {
    final root = await Directory.systemTemp.createTemp('download_resume_206');
    addTearDown(() => root.delete(recursive: true));
    final bytes = [1, 2, 3, 4, 5];
    final file = File('${root.path}/courses/course/resource_standard.mp4');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes.take(2).toList());
    final store = MemoryKeyValueStore();
    final files = _FileManager(root);
    final repository = DownloadRepositoryImpl(
      remote: _AuthorizationSource(bytes),
      taskStore: DownloadTaskStore(store),
      fileManager: files,
      preferencesStore: store,
    );
    final dio = Dio()
      ..httpClientAdapter = const _ResponseAdapter(
        [3, 4, 5],
        HttpStatus.partialContent,
        contentRange: 'bytes 3-4/5',
      );
    final manager = DownloadManager(
      repository: repository,
      fileManager: files,
      networkMonitor: _WifiMonitor(),
      dio: dio,
    );
    addTearDown(manager.dispose);

    final failed = manager.taskUpdates.firstWhere((task) => task.isFailed);
    await manager.enqueueDownload(
      learnerId: 'learner',
      resourceType: DownloadResourceType.video,
      resourceId: 'resource',
      courseId: 'course',
      title: 'Lesson',
      courseTitle: 'Course',
    );
    final task = await failed.timeout(const Duration(seconds: 2));
    expect(task.failure?.reason, DownloadFailureReason.integrityFailure);
    expect(await file.readAsBytes(), bytes.take(2).toList());
  });
}
