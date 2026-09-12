import 'package:flutter_test/flutter_test.dart';
import 'package:learning_platform/features/downloads/data/download_task_store.dart';
import 'package:learning_platform/features/downloads/domain/download_task.dart';

import '../../../helpers/memory_key_value_store.dart';

void main() {
  group('DownloadTaskStore Tests', () {
    late MemoryKeyValueStore memoryStore;
    late DownloadTaskStore store;

    final now = DateTime.utc(2026, 8, 31, 12, 0, 0);

    final task1 = DownloadTask(
      id: 'task_1',
      learnerId: 'learner_A',
      resourceType: DownloadResourceType.video,
      resourceId: 'res_1',
      courseId: 'course_1',
      title: 'Lesson 1',
      courseTitle: 'Course 1',
      remoteAssetId: 'asset_1',
      state: DownloadState.completed,
      bytesDownloaded: 1000,
      totalBytes: 1000,
      createdAt: now,
      updatedAt: now,
    );

    final task2 = DownloadTask(
      id: 'task_2',
      learnerId: 'learner_A',
      resourceType: DownloadResourceType.video,
      resourceId: 'res_2',
      courseId: 'course_1',
      title: 'Lesson 2',
      courseTitle: 'Course 1',
      remoteAssetId: 'asset_2',
      state: DownloadState.queued,
      bytesDownloaded: 0,
      totalBytes: 2000,
      createdAt: now,
      updatedAt: now.add(const Duration(seconds: 10)),
    );

    final taskLearnerB = DownloadTask(
      id: 'task_b1',
      learnerId: 'learner_B',
      resourceType: DownloadResourceType.video,
      resourceId: 'res_1',
      courseId: 'course_1',
      title: 'Lesson 1',
      courseTitle: 'Course 1',
      remoteAssetId: 'asset_1',
      state: DownloadState.completed,
      bytesDownloaded: 1000,
      totalBytes: 1000,
      createdAt: now,
      updatedAt: now,
    );

    setUp(() {
      memoryStore = MemoryKeyValueStore();
      store = DownloadTaskStore(memoryStore);
    });

    test('saves and retrieves tasks with learner isolation', () async {
      await store.save(task1);
      await store.save(task2);
      await store.save(taskLearnerB);

      final tasksA = await store.getAll('learner_A');
      expect(tasksA.length, 2);

      final tasksB = await store.getAll('learner_B');
      expect(tasksB.length, 1);
      expect(tasksB.first.id, 'task_b1');
    });

    test('retrieves task by resource ID and course ID', () async {
      await store.save(task1);
      await store.save(task2);

      final byResource = await store.getByResourceId('learner_A', 'res_1');
      expect(byResource?.id, 'task_1');

      final byCourse = await store.getByCourseId('learner_A', 'course_1');
      expect(byCourse.length, 2);
    });

    test('deletes individual task and reloads correctly', () async {
      await store.save(task1);
      await store.save(task2);

      await store.remove('learner_A', 'task_1');

      final remaining = await store.getAll('learner_A');
      expect(remaining.length, 1);
      expect(remaining.first.id, 'task_2');

      final deletedLookup = await store.getById('learner_A', 'task_1');
      expect(deletedLookup, isNull);
    });

    test('deletes all tasks for a course', () async {
      await store.save(task1);
      await store.save(task2);

      await store.removeForCourse('learner_A', 'course_1');

      final remaining = await store.getAll('learner_A');
      expect(remaining, isEmpty);
    });

    test('clears all tasks for learner', () async {
      await store.save(task1);
      await store.save(task2);

      await store.removeAll('learner_A');

      final remaining = await store.getAll('learner_A');
      expect(remaining, isEmpty);
    });

    test(
      'bounds task store to prevent unbounded growth while preserving active/completed tasks',
      () async {
        // Save 210 tasks (some failed/cancelled, some completed)
        for (var i = 0; i < 210; i++) {
          final t = DownloadTask(
            id: 'task_$i',
            learnerId: 'learner_bounded',
            resourceType: DownloadResourceType.video,
            resourceId: 'res_$i',
            courseId: 'course_1',
            title: 'Lesson $i',
            courseTitle: 'Course 1',
            remoteAssetId: 'asset_$i',
            state: i < 50
                ? DownloadState.completed
                : (i < 100 ? DownloadState.downloading : DownloadState.failed),
            bytesDownloaded: 100,
            totalBytes: 100,
            createdAt: now.add(Duration(minutes: i)),
            updatedAt: now.add(Duration(minutes: i)),
          );
          await store.save(t);
        }

        final tasks = await store.getAll('learner_bounded');
        // Pruned down to bound without dropping active/completed
        expect(tasks.length, lessThanOrEqualTo(201));
        final completedCount = tasks.where((t) => t.isCompleted).length;
        expect(completedCount, 50);
        final activeCount = tasks.where((t) => t.isActive).length;
        expect(activeCount, 50);
      },
    );
  });
}
