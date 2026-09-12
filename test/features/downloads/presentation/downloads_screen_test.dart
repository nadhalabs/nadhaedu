import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_platform/bootstrap/providers.dart';
import 'package:learning_platform/config/branding_config.dart';
import 'package:learning_platform/core/connectivity/network_monitor.dart';
import 'package:learning_platform/features/downloads/application/download_controller.dart';
import 'package:learning_platform/features/downloads/application/download_manager.dart';
import 'package:learning_platform/features/downloads/application/download_providers.dart';
import 'package:learning_platform/features/downloads/data/download_repository_impl.dart';
import 'package:learning_platform/features/downloads/data/download_task_store.dart';

import 'package:learning_platform/features/downloads/data/foundation_download_data_source.dart';
import 'package:learning_platform/features/downloads/domain/download_task.dart';
import 'package:learning_platform/features/downloads/presentation/downloads_screen.dart';

import '../../../helpers/memory_key_value_store.dart';
import '../application/download_manager_test.dart';

void main() {
  group('DownloadsScreen Widget Tests', () {
    late MemoryKeyValueStore memoryStore;
    late DownloadTaskStore taskStore;
    late TestFileManager fileManager;
    late FakeTestNetworkMonitor networkMonitor;
    late DownloadRepositoryImpl repository;
    late DownloadManager downloadManager;
    late DownloadController downloadController;

    final now = DateTime.utc(2026, 8, 31, 12, 0, 0);

    setUp(() async {
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
      );
      downloadController = DownloadController(
        repository: repository,
        downloadManager: downloadManager,
        learnerId: 'learner_screen_test',
      );
      await downloadController.loadTasks();
    });

    tearDown(() {
      downloadManager.dispose();
    });

    testWidgets('displays empty state when there are no downloads', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            brandingConfigProvider.overrideWithValue(
              const BrandingConfig(displayName: 'Test Platform'),
            ),
            downloadRepositoryProvider.overrideWithValue(repository),
            downloadManagerProvider.overrideWithValue(downloadManager),
            downloadControllerProvider.overrideWith(
              (ref) => downloadController,
            ),
            currentLearnerIdProvider.overrideWithValue('learner_screen_test'),
          ],
          child: const MaterialApp(home: DownloadsScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No downloaded content'), findsOneWidget);
      expect(find.byIcon(Icons.download_outlined), findsOneWidget);
    });

    testWidgets(
      'renders storage card, active downloads, and completed courses',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        fileManager.files.add('courses/c1/r1.mp4');

        final completedTask = DownloadTask(
          id: 't_comp',
          learnerId: 'learner_screen_test',
          resourceType: DownloadResourceType.video,
          resourceId: 'r1',
          courseId: 'c1',
          title: 'Completed Lesson',
          courseTitle: 'Architecture Mastery',
          remoteAssetId: 'a1',
          state: DownloadState.completed,
          bytesDownloaded: 25 * 1024 * 1024,
          totalBytes: 25 * 1024 * 1024,
          createdAt: now,
          updatedAt: now,
          localRelativePath: 'courses/c1/r1.mp4',
          entitlementExpiresAt: now.add(const Duration(days: 7)),
        );

        final activeTask = DownloadTask(
          id: 't_act',
          learnerId: 'learner_screen_test',
          resourceType: DownloadResourceType.video,
          resourceId: 'r2',
          courseId: 'c1',
          title: 'Downloading Lesson',
          courseTitle: 'Architecture Mastery',
          remoteAssetId: 'a2',
          state: DownloadState.downloading,
          bytesDownloaded: 10 * 1024 * 1024,
          totalBytes: 20 * 1024 * 1024,
          createdAt: now,
          updatedAt: now,
        );

        await repository.saveTask(completedTask);
        await repository.saveTask(activeTask);
        await downloadController.loadTasks();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              brandingConfigProvider.overrideWithValue(
                const BrandingConfig(displayName: 'Test Platform'),
              ),
              downloadRepositoryProvider.overrideWithValue(repository),
              downloadManagerProvider.overrideWithValue(downloadManager),
              downloadControllerProvider.overrideWith(
                (ref) => downloadController,
              ),
              currentLearnerIdProvider.overrideWithValue('learner_screen_test'),
            ],
            child: const MaterialApp(home: DownloadsScreen()),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Device Storage'), findsOneWidget);
        expect(find.text('Download over Wi-Fi only'), findsOneWidget);
        expect(find.text('In Progress (1)'), findsOneWidget);
        expect(find.text('Downloading Lesson'), findsOneWidget);
        expect(find.text('Downloaded Courses'), findsOneWidget);
        expect(find.text('Architecture Mastery'), findsWidgets);
      },
    );

    testWidgets('shows confirmation dialog on clear all downloads', (
      tester,
    ) async {
      final task = DownloadTask(
        id: 't_to_clear',
        learnerId: 'learner_screen_test',
        resourceType: DownloadResourceType.video,
        resourceId: 'r1',
        courseId: 'c1',
        title: 'Some Lesson',
        courseTitle: 'Some Course',
        remoteAssetId: 'a1',
        state: DownloadState.completed,
        bytesDownloaded: 1024,
        totalBytes: 1024,
        createdAt: now,
        updatedAt: now,
      );
      await repository.saveTask(task);
      await downloadController.loadTasks();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            brandingConfigProvider.overrideWithValue(
              const BrandingConfig(displayName: 'Test Platform'),
            ),
            downloadRepositoryProvider.overrideWithValue(repository),
            downloadManagerProvider.overrideWithValue(downloadManager),
            downloadControllerProvider.overrideWith(
              (ref) => downloadController,
            ),
            currentLearnerIdProvider.overrideWithValue('learner_screen_test'),
          ],
          child: const MaterialApp(home: DownloadsScreen()),
        ),
      );

      await tester.pumpAndSettle();

      final clearButton = find.byIcon(Icons.delete_sweep_outlined);
      expect(clearButton, findsOneWidget);
      await tester.tap(clearButton);
      await tester.pumpAndSettle();

      expect(find.text('Clear all downloads?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Clear All'), findsOneWidget);
    });
  });
}
