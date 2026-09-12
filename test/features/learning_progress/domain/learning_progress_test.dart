import 'package:flutter_test/flutter_test.dart';
import 'package:learning_platform/features/content_catalog/data/foundation_catalog_data_source.dart';
import 'package:learning_platform/features/learning_progress/domain/learning_progress.dart';

void main() {
  group('CourseProgressCalculator', () {
    test('uses the precomputed outline and completed lesson count', () async {
      final course = await FoundationCatalogDataSource().fetchCourse(
        'course-1',
      );
      final outline = CourseOutlineIndex.fromCourse(course);
      final now = DateTime.utc(2026, 8, 31);
      final progress = CourseProgress(
        courseId: course.summary.id,
        serverRevision: 2,
        updatedAt: now,
        lessons: {
          outline.lessons[0].id: LessonProgress(
            lessonId: outline.lessons[0].id,
            position: const Duration(minutes: 8),
            duration: const Duration(minutes: 8),
            completed: true,
            updatedAt: now,
          ),
        },
      );

      expect(
        CourseProgressCalculator.fraction(outline, progress),
        closeTo(1 / 7, 0.001),
      );
      expect(
        CourseProgressCalculator.resumeLesson(outline, progress)?.id,
        outline.lessons[1].id,
      );
      expect(outline.next(outline.lessons.first.id)?.id, outline.lessons[1].id);
      expect(outline.previous(outline.lessons.first.id), isNull);
    });
  });

  group('ProgressReconciler', () {
    test('keeps server baseline and replays pending mutations in order', () {
      final serverTime = DateTime.utc(2026, 8, 31, 10);
      final server = CourseProgress(
        courseId: 'course-1',
        serverRevision: 8,
        updatedAt: serverTime,
        lessons: {
          'lesson-1': LessonProgress(
            lessonId: 'lesson-1',
            position: const Duration(seconds: 30),
            duration: const Duration(minutes: 2),
            completed: false,
            updatedAt: serverTime,
          ),
        },
      );
      final pending = [
        ProgressMutation(
          id: 'mutation-2',
          courseId: 'course-1',
          lessonId: 'lesson-1',
          kind: ProgressMutationKind.completion,
          position: const Duration(seconds: 90),
          duration: const Duration(minutes: 2),
          completed: true,
          occurredAt: serverTime.add(const Duration(minutes: 2)),
          baseRevision: 7,
        ),
        ProgressMutation(
          id: 'mutation-1',
          courseId: 'course-1',
          lessonId: 'lesson-1',
          kind: ProgressMutationKind.position,
          position: const Duration(seconds: 90),
          duration: const Duration(minutes: 2),
          completed: false,
          occurredAt: serverTime.add(const Duration(minutes: 1)),
          baseRevision: 7,
        ),
      ];

      final result = ProgressReconciler.reconcile(server, pending);

      expect(result.serverRevision, 8);
      expect(result.lessons['lesson-1']?.completed, isTrue);
      expect(result.lessons['lesson-1']?.position, const Duration(minutes: 2));
    });

    test('ignores mutations belonging to another course', () {
      final server = CourseProgress.empty('course-1');
      final result = ProgressReconciler.reconcile(server, [
        ProgressMutation(
          id: 'foreign',
          courseId: 'course-2',
          lessonId: 'lesson-1',
          kind: ProgressMutationKind.position,
          position: const Duration(seconds: 5),
          duration: const Duration(minutes: 1),
          completed: false,
          occurredAt: DateTime.utc(2026),
          baseRevision: 0,
        ),
      ]);
      expect(result.lessons, isEmpty);
    });
  });
}
