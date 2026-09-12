import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_platform/features/learning_progress/data/foundation_learning_data_source.dart';
import 'package:learning_platform/features/learning_progress/data/learning_data_source.dart';
import 'package:learning_platform/features/learning_progress/data/learning_repository_impl.dart';
import 'package:learning_platform/features/learning_progress/domain/learning_progress.dart';
import 'package:learning_platform/features/learning_progress/domain/playback_source.dart';
import '../../../helpers/memory_key_value_store.dart';

class DelayedSource implements LearningDataSource {
  final delegate = FoundationLearningDataSource();
  Completer<void>? gate;
  final entered = Completer<void>();
  final batchSizes = <int>[];
  @override
  Future<CourseProgress> fetchProgress(String learnerId, String courseId) =>
      delegate.fetchProgress(learnerId, courseId);
  @override
  Future<PlaybackSource> fetchPlaybackSource(
    String learnerId,
    String assetId,
  ) => delegate.fetchPlaybackSource(learnerId, assetId);
  @override
  Future<ProgressSyncResult> synchronizeProgress(
    String learnerId,
    String courseId,
    List<ProgressMutation> mutations,
  ) async {
    batchSizes.add(mutations.length);
    if (!entered.isCompleted) entered.complete();
    await gate?.future;
    return delegate.synchronizeProgress(learnerId, courseId, mutations);
  }
}

Future<CourseProgress> complete(
  LearningRepositoryImpl repository,
  String lesson,
) => repository.setCompleted(
  courseId: 'course',
  lessonId: lesson,
  completed: true,
  position: Duration.zero,
  duration: const Duration(minutes: 1),
  occurredAt: DateTime.now().toUtc(),
);
void main() {
  test('parallel local writes preserve every completion', () async {
    final source = DelayedSource();
    final repository = LearningRepositoryImpl(
      remote: source,
      localStore: MemoryKeyValueStore(),
      learnerId: 'learner',
    );
    await Future.wait([
      for (var i = 0; i < 20; i++) complete(repository, 'lesson-$i'),
    ]);
    final progress = await repository.synchronize('course');
    expect(progress.lessons.length, 20);
    expect(progress.lessons.values.every((lesson) => lesson.completed), isTrue);
  });
  test(
    'sync merge preserves mutations recorded while network request is pending',
    () async {
      final source = DelayedSource()..gate = Completer<void>();
      final repository = LearningRepositoryImpl(
        remote: source,
        localStore: MemoryKeyValueStore(),
        learnerId: 'learner',
      );
      await complete(repository, 'first');
      final pending = repository.synchronize('course');
      await source.entered.future;
      await complete(repository, 'second');
      source.gate!.complete();
      final merged = await pending;
      expect(merged.lessons['second']?.completed, isTrue);
      await repository.synchronize('course');
      final server = await source.fetchProgress('learner', 'course');
      expect(server.lessons.length, 2);
    },
  );
  test(
    'large outboxes use bounded server batches without dropping completions',
    () async {
      final source = DelayedSource();
      final repository = LearningRepositoryImpl(
        remote: source,
        localStore: MemoryKeyValueStore(),
        learnerId: 'learner',
      );
      for (var i = 0; i < 105; i++) {
        await complete(repository, 'lesson-$i');
      }
      await repository.synchronize('course');
      await repository.synchronize('course');
      expect(source.batchSizes, [100, 5]);
      expect(
        (await source.fetchProgress('learner', 'course')).lessons.length,
        105,
      );
    },
  );
}
