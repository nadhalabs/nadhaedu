import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:learning_platform/core/connectivity/network_monitor.dart';
import 'package:learning_platform/features/downloads/application/download_manager.dart';
import 'package:learning_platform/features/downloads/data/download_file_manager.dart';
import 'package:learning_platform/features/downloads/data/download_repository_impl.dart';
import 'package:learning_platform/features/downloads/data/download_task_store.dart';
import 'package:learning_platform/features/downloads/data/foundation_download_data_source.dart';
import 'package:learning_platform/features/downloads/domain/download_task.dart';

import '../../../helpers/memory_key_value_store.dart';

final class FakeTestNetworkMonitor implements NetworkMonitor {
  FakeTestNetworkMonitor([this._status = NetworkStatus.wifi]);
  NetworkStatus _status;

  final StreamController<NetworkStatus> _controller =
      StreamController<NetworkStatus>.broadcast();

  void setStatus(NetworkStatus s) {
    _status = s;
    _controller.add(s);
  }

  @override
  Stream<NetworkStatus> get status => _controller.stream;

  @override
  Future<NetworkStatus> currentStatus() async => _status;
}

final class TestFileManager implements DownloadFileManager {
  TestFileManager()
    : _tempDir = Directory.systemTemp.createTempSync('nadha_dl_test');

  final Directory _tempDir;
  int availableDisk = 1024 * 1024 * 1024 * 10; // 10 GB
  final Set<String> files = {};

  @override
  Future<String> getRootDirectory() async => _tempDir.path;

  @override
  Future<String> resolveAbsolutePath(String relativePath) async =>
      '${_tempDir.path}/$relativePath';

  @override
  Future<bool> fileExists(String relativePath) async =>
      files.contains(relativePath);

  @override
  Future<int> getFileSize(String relativePath) async => 1024;

  @override
  Future<String> computeSha256(String relativePath) async => 'mock_sha';

  @override
  Future<void> deleteFile(String relativePath) async {
    files.remove(relativePath);
  }

  @override
  Future<void> deleteDirectory(String relativePath) async {
    files.removeWhere((f) => f.startsWith(relativePath));
  }

  @override
  Future<int> getAvailableDiskSpace() async => availableDisk;

  @override
  Future<void> ensureDirectoryExists(String directoryPath) async {
    final dir = Directory(directoryPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  void dispose() {
    try {
      if (_tempDir.existsSync()) {
        _tempDir.deleteSync(recursive: true);
      }
    } on Object catch (_) {}
  }
}

void main() {
  group('DownloadManager Lifecycle Tests', () {
    late MemoryKeyValueStore memoryStore;
    late DownloadTaskStore taskStore;
    late TestFileManager fileManager;
    late FakeTestNetworkMonitor networkMonitor;
    late DownloadRepositoryImpl repository;
    late DownloadManager downloadManager;

    setUp(() {
      memoryStore = MemoryKeyValueStore();
      taskStore = DownloadTaskStore(memoryStore);
      fileManager = TestFileManager();
      networkMonitor = FakeTestNetworkMonitor(NetworkStatus.wifi);
      repository = DownloadRepositoryImpl(
        remote: const FoundationDownloadDataSource(),
        taskStore: taskStore,
        fileManager: fileManager,
        preferencesStore: memoryStore,
      );
      downloadManager = DownloadManager(
        repository: repository,
        fileManager: fileManager,
        networkMonitor: networkMonitor,
        maxConcurrentDownloads: 2,
      );
    });

    tearDown(() {
      downloadManager.dispose();
      fileManager.dispose();
    });

    test('enqueues download and creates queued task', () async {
      final task = await downloadManager.enqueueDownload(
        learnerId: 'user_1',
        resourceType: DownloadResourceType.video,
        resourceId: 'res_123',
        courseId: 'course_abc',
        title: 'Getting Started',
        courseTitle: 'Flutter 101',
      );

      expect(task.id, contains('res_123'));
      expect(task.title, 'Getting Started');
      expect(
        task.state,
        isIn([
          DownloadState.queued,
          DownloadState.preparing,
          DownloadState.failed,
        ]),
      );
    });

    test('pauses and resumes download task', () async {
      final task = await downloadManager.enqueueDownload(
        learnerId: 'user_1',
        resourceType: DownloadResourceType.video,
        resourceId: 'res_pause',
        courseId: 'course_abc',
        title: 'Pause Test',
        courseTitle: 'Flutter 101',
      );

      await downloadManager.pauseDownload('user_1', task.id);
      final pausedTask = await repository.getTask('user_1', task.id);
      expect(
        pausedTask?.state,
        isIn([DownloadState.paused, DownloadState.failed]),
      );

      await downloadManager.resumeDownload('user_1', task.id);
      final resumedTask = await repository.getTask('user_1', task.id);
      expect(
        resumedTask?.state,
        isIn([
          DownloadState.queued,
          DownloadState.preparing,
          DownloadState.failed,
        ]),
      );
    });

    test('cancels and cleans up download task', () async {
      final task = await downloadManager.enqueueDownload(
        learnerId: 'user_1',
        resourceType: DownloadResourceType.video,
        resourceId: 'res_cancel',
        courseId: 'course_abc',
        title: 'Cancel Test',
        courseTitle: 'Flutter 101',
      );

      await downloadManager.cancelDownload('user_1', task.id);
      final cancelledTask = await repository.getTask('user_1', task.id);
      expect(cancelledTask?.state, DownloadState.cancelled);
    });

    test('fails download immediately when network is offline', () async {
      networkMonitor.setStatus(NetworkStatus.offline);

      final task = await downloadManager.enqueueDownload(
        learnerId: 'user_1',
        resourceType: DownloadResourceType.video,
        resourceId: 'res_offline',
        courseId: 'course_abc',
        title: 'Offline Test',
        courseTitle: 'Flutter 101',
      );

      // Wait briefly for execution cycle
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final failedTask = await repository.getTask('user_1', task.id);
      expect(failedTask?.state, DownloadState.failed);
      expect(
        failedTask?.failure?.reason,
        DownloadFailureReason.networkUnavailable,
      );
    });

    test('Wi-Fi-only policy blocks cellular downloads', () async {
      networkMonitor.setStatus(NetworkStatus.cellular);

      final task = await downloadManager.enqueueDownload(
        learnerId: 'user_1',
        resourceType: DownloadResourceType.video,
        resourceId: 'res_cellular',
        courseId: 'course_abc',
        title: 'Cellular Test',
        courseTitle: 'Flutter 101',
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final failedTask = await repository.getTask('user_1', task.id);
      expect(failedTask?.state, DownloadState.failed);
      expect(
        failedTask?.failure?.message,
        'Download is waiting for a Wi-Fi connection.',
      );
    });

    test('fails download when disk space is insufficient', () async {
      fileManager.availableDisk = 1024 * 1024; // Only 1MB available

      final task = await downloadManager.enqueueDownload(
        learnerId: 'user_1',
        resourceType: DownloadResourceType.video,
        resourceId: 'res_nospace',
        courseId: 'course_abc',
        title: 'Disk Test',
        courseTitle: 'Flutter 101',
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      final failedTask = await repository.getTask('user_1', task.id);
      expect(failedTask?.state, DownloadState.failed);
      expect(
        failedTask?.failure?.reason,
        DownloadFailureReason.insufficientStorage,
      );
      expect(failedTask?.failure?.retryable, isFalse);
    });
  });
}
