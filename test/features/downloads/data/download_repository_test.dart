import 'package:flutter_test/flutter_test.dart';
import 'package:learning_platform/features/downloads/data/download_data_source.dart';
import 'package:learning_platform/features/downloads/data/download_file_manager.dart';
import 'package:learning_platform/features/downloads/data/download_repository_impl.dart';
import 'package:learning_platform/features/downloads/data/download_task_store.dart';
import 'package:learning_platform/features/downloads/data/foundation_download_data_source.dart';
import 'package:learning_platform/features/downloads/domain/download_network_policy.dart';
import 'package:learning_platform/features/downloads/domain/download_task.dart';

import '../../../helpers/memory_key_value_store.dart';

final class FakeFileManager implements DownloadFileManager {
  final Set<String> existingFiles = {};
  final Map<String, int> fileSizes = {};

  @override
  Future<String> getRootDirectory() async => '/sandbox/downloads';

  @override
  Future<String> resolveAbsolutePath(String relativePath) async =>
      '/sandbox/downloads/$relativePath';

  @override
  Future<bool> fileExists(String relativePath) async =>
      existingFiles.contains(relativePath);

  @override
  Future<int> getFileSize(String relativePath) async =>
      fileSizes[relativePath] ?? 0;

  @override
  Future<String> computeSha256(String relativePath) async => 'fake_sha256';

  @override
  Future<void> deleteFile(String relativePath) async {
    existingFiles.remove(relativePath);
    fileSizes.remove(relativePath);
  }

  @override
  Future<void> deleteDirectory(String relativePath) async {
    existingFiles.removeWhere((p) => p.startsWith(relativePath));
  }

  @override
  Future<int> getAvailableDiskSpace() async => 1024 * 1024 * 1024 * 10; // 10GB

  @override
  Future<void> ensureDirectoryExists(String directoryPath) async {}
}

void main() {
  group('DownloadRepositoryImpl Tests', () {
    late MemoryKeyValueStore memoryStore;
    late DownloadTaskStore taskStore;
    late FakeFileManager fileManager;
    late DownloadDataSource remoteDataSource;
    late DownloadRepositoryImpl repository;

    final now = DateTime.utc(2026, 8, 31, 12, 0, 0);

    setUp(() {
      memoryStore = MemoryKeyValueStore();
      taskStore = DownloadTaskStore(memoryStore);
      fileManager = FakeFileManager();
      remoteDataSource = const FoundationDownloadDataSource();
      repository = DownloadRepositoryImpl(
        remote: remoteDataSource,
        taskStore: taskStore,
        fileManager: fileManager,
        preferencesStore: memoryStore,
      );
    });

    test('validates tasks and detects missing local files', () async {
      final task = DownloadTask(
        id: 'task_complete',
        learnerId: 'learner_1',
        resourceType: DownloadResourceType.video,
        resourceId: 'res_1',
        courseId: 'course_1',
        title: 'Lesson 1',
        courseTitle: 'Course 1',
        remoteAssetId: 'asset_1',
        state: DownloadState.completed,
        bytesDownloaded: 5000,
        totalBytes: 5000,
        createdAt: now,
        updatedAt: now,
        localRelativePath: 'courses/course_1/res_1.mp4',
      );

      await repository.saveTask(task);

      // 1. Without file on disk, task is marked as failed due to missing file
      final tasksMissing = await repository.getAllTasks('learner_1');
      expect(tasksMissing.first.state, DownloadState.failed);
      expect(
        tasksMissing.first.failure?.reason,
        DownloadFailureReason.integrityFailure,
      );

      // 2. Add file to file manager, save task as completed again
      fileManager.existingFiles.add('courses/course_1/res_1.mp4');
      fileManager.fileSizes['courses/course_1/res_1.mp4'] = 5000;
      await repository.saveTask(task);

      final tasksPresent = await repository.getAllTasks('learner_1');
      expect(tasksPresent.first.state, DownloadState.completed);
    });

    test('computes storage summary accurately', () async {
      fileManager.existingFiles.add('courses/c1/r1.mp4');
      fileManager.existingFiles.add('courses/c1/r2.mp4');
      fileManager.existingFiles.add('courses/c2/r3.mp4');

      final task1 = DownloadTask(
        id: 't1',
        learnerId: 'learner_1',
        resourceType: DownloadResourceType.video,
        resourceId: 'r1',
        courseId: 'c1',
        title: 'L1',
        courseTitle: 'Course One',
        remoteAssetId: 'a1',
        state: DownloadState.completed,
        bytesDownloaded: 10 * 1024 * 1024,
        totalBytes: 10 * 1024 * 1024,
        createdAt: now,
        updatedAt: now,
        localRelativePath: 'courses/c1/r1.mp4',
      );

      final task2 = DownloadTask(
        id: 't2',
        learnerId: 'learner_1',
        resourceType: DownloadResourceType.video,
        resourceId: 'r2',
        courseId: 'c1',
        title: 'L2',
        courseTitle: 'Course One',
        remoteAssetId: 'a2',
        state: DownloadState.completed,
        bytesDownloaded: 15 * 1024 * 1024,
        totalBytes: 15 * 1024 * 1024,
        createdAt: now,
        updatedAt: now,
        localRelativePath: 'courses/c1/r2.mp4',
      );

      final task3 = DownloadTask(
        id: 't3',
        learnerId: 'learner_1',
        resourceType: DownloadResourceType.video,
        resourceId: 'r3',
        courseId: 'c2',
        title: 'L3',
        courseTitle: 'Course Two',
        remoteAssetId: 'a3',
        state: DownloadState.completed,
        bytesDownloaded: 20 * 1024 * 1024,
        totalBytes: 20 * 1024 * 1024,
        createdAt: now,
        updatedAt: now,
        localRelativePath: 'courses/c2/r3.mp4',
      );

      await repository.saveTask(task1);
      await repository.saveTask(task2);
      await repository.saveTask(task3);

      final summary = await repository.getStorageSummary('learner_1');

      expect(summary.totalBytesUsed, 45 * 1024 * 1024);
      expect(summary.completedTasksCount, 3);
      expect(summary.courses.length, 2);

      final course1Summary = summary.courses.firstWhere(
        (c) => c.courseId == 'c1',
      );
      expect(course1Summary.bytesUsed, 25 * 1024 * 1024);
      expect(course1Summary.taskCount, 2);
    });

    test('persists and loads network policy', () async {
      final defaultPolicy = await repository.getNetworkPolicy();
      expect(defaultPolicy.preference, NetworkDownloadPreference.wifiOnly);

      const customPolicy = DownloadNetworkPolicy(
        preference: NetworkDownloadPreference.allowCellular,
        warnOnLargeCellular: false,
        maxCellularSizeBytes: 100 * 1024 * 1024,
      );

      await repository.setNetworkPolicy(customPolicy);
      final loaded = await repository.getNetworkPolicy();

      expect(loaded.preference, NetworkDownloadPreference.allowCellular);
      expect(loaded.warnOnLargeCellular, isFalse);
      expect(loaded.maxCellularSizeBytes, 100 * 1024 * 1024);
    });

    test('revalidates downloads and updates task entitlements', () async {
      final task = DownloadTask(
        id: 'task_exp',
        learnerId: 'learner_1',
        resourceType: DownloadResourceType.video,
        resourceId: 'res_exp',
        courseId: 'course_1',
        title: 'Expiring Lesson',
        courseTitle: 'Course 1',
        remoteAssetId: 'asset_exp',
        state: DownloadState.expired,
        bytesDownloaded: 100,
        totalBytes: 100,
        createdAt: now,
        updatedAt: now,
        entitlementExpiresAt: now.subtract(const Duration(days: 1)),
      );

      await repository.saveTask(task);

      final results = await repository.revalidateDownloads(
        learnerId: 'learner_1',
        resourceIds: ['res_exp'],
      );

      expect(results.length, 1);
      final updated = await repository.getTask('learner_1', 'task_exp');
      expect(updated?.entitlementExpiresAt, isNotNull);
      expect(updated?.isOfflineEntitlementValid, isTrue);
    });
  });
}
