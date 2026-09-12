import 'package:flutter_test/flutter_test.dart';
import 'package:learning_platform/features/learning_progress/data/foundation_learning_data_source.dart';
import 'package:learning_platform/features/learning_progress/data/learning_repository_impl.dart';

import '../../../helpers/memory_key_value_store.dart';

void main() {
  test(
    'persists offline-first progress and synchronizes idempotently',
    () async {
      final remote = FoundationLearningDataSource();
      final store = MemoryKeyValueStore();
      final repository = LearningRepositoryImpl(
        remote: remote,
        localStore: store,
        learnerId: 'learner-1',
      );
      final occurredAt = DateTime.utc(2026, 8, 31);

      await repository.recordPosition(
        courseId: 'course-1',
        lessonId: 'lesson-1',
        position: const Duration(seconds: 45),
        duration: const Duration(minutes: 2),
        occurredAt: occurredAt,
      );
      final firstSync = await repository.synchronize('course-1');
      final secondSync = await repository.synchronize('course-1');

      expect(
        firstSync.lessons['lesson-1']?.position,
        const Duration(seconds: 45),
      );
      expect(
        secondSync.lessons['lesson-1']?.position,
        const Duration(seconds: 45),
      );
      expect(secondSync.serverRevision, firstSync.serverRevision);
      expect(store.values.keys.single, 'learning.progress.v1.learner-1');
    },
  );
}
