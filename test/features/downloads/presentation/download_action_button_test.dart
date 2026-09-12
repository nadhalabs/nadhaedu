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
import 'package:learning_platform/features/downloads/presentation/widgets/download_action_button.dart';

import '../../../helpers/memory_key_value_store.dart';
import '../application/download_manager_test.dart';

void main() {
  group('DownloadActionButton Widget Tests', () {
    late MemoryKeyValueStore memoryStore;
    late DownloadTaskStore taskStore;
    late TestFileManager fileManager;
    late FakeTestNetworkMonitor networkMonitor;
    late DownloadRepositoryImpl repository;
    late DownloadManager downloadManager;
    late DownloadController downloadController;

    final now = DateTime.now().toUtc();

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
        learnerId: 'learner_button_test',
      );
      await downloadController.loadTasks();
    });

    tearDown(() {
      downloadManager.dispose();
    });

    testWidgets('renders download icon initially and enqueues on click', (
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
            currentLearnerIdProvider.overrideWithValue('learner_button_test'),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DownloadActionButton(
                resourceId: 'res_btn_1',
                courseId: 'c1',
                title: 'Lesson 1',
                courseTitle: 'Course 1',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final dlIcon = find.byIcon(Icons.download_outlined);
      expect(dlIcon, findsOneWidget);

      await tester.tap(dlIcon);
      await tester.pump();

      // State becomes active or queued
      final task = await repository.getTaskByResourceId(
        'learner_button_test',
        'res_btn_1',
      );
      expect(task, isNotNull);
    });

    testWidgets(
      'renders completed state and opens bottom sheet options on tap',
      (tester) async {
        fileManager.files.add('courses/c1/res_comp.mp4');

        final task = DownloadTask(
          id: 't_comp',
          learnerId: 'learner_button_test',
          resourceType: DownloadResourceType.video,
          resourceId: 'res_comp',
          courseId: 'c1',
          title: 'Completed Lesson',
          courseTitle: 'Course 1',
          remoteAssetId: 'a1',
          state: DownloadState.completed,
          bytesDownloaded: 5000,
          totalBytes: 5000,
          createdAt: now,
          updatedAt: now,
          localRelativePath: 'courses/c1/res_comp.mp4',
          entitlementExpiresAt: now.add(const Duration(days: 5)),
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
              currentLearnerIdProvider.overrideWithValue('learner_button_test'),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: DownloadActionButton(
                  resourceId: 'res_comp',
                  courseId: 'c1',
                  title: 'Completed Lesson',
                  courseTitle: 'Course 1',
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final doneIcon = find.byIcon(Icons.download_done);
        expect(doneIcon, findsOneWidget);

        await tester.tap(doneIcon);
        await tester.pumpAndSettle();

        expect(find.text('Completed Lesson'), findsOneWidget);
        expect(find.text('Delete download'), findsOneWidget);
      },
    );
  });
}
