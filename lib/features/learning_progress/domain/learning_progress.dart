import 'package:learning_platform/features/content_catalog/domain/course.dart';

final class LessonProgress {
  const LessonProgress({
    required this.lessonId,
    required this.position,
    required this.duration,
    required this.completed,
    required this.updatedAt,
  });

  final String lessonId;
  final Duration position;
  final Duration duration;
  final bool completed;
  final DateTime updatedAt;

  double get fraction => completed
      ? 1
      : duration.inMilliseconds <= 0
      ? 0
      : (position.inMilliseconds / duration.inMilliseconds).clamp(0, 1);

  LessonProgress copyWith({
    Duration? position,
    Duration? duration,
    bool? completed,
    DateTime? updatedAt,
  }) => LessonProgress(
    lessonId: lessonId,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    completed: completed ?? this.completed,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

final class CourseProgress {
  CourseProgress({
    required this.courseId,
    required Map<String, LessonProgress> lessons,
    required this.serverRevision,
    required this.updatedAt,
  }) : lessons = Map.unmodifiable(lessons);

  factory CourseProgress.empty(String courseId) => CourseProgress(
    courseId: courseId,
    lessons: const {},
    serverRevision: 0,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );

  final String courseId;
  final Map<String, LessonProgress> lessons;
  final int serverRevision;
  final DateTime updatedAt;

  CourseProgress copyWith({
    Map<String, LessonProgress>? lessons,
    int? serverRevision,
    DateTime? updatedAt,
  }) => CourseProgress(
    courseId: courseId,
    lessons: lessons ?? this.lessons,
    serverRevision: serverRevision ?? this.serverRevision,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

enum ProgressMutationKind { position, completion }

final class ProgressMutation {
  const ProgressMutation({
    required this.id,
    required this.courseId,
    required this.lessonId,
    required this.kind,
    required this.position,
    required this.duration,
    required this.completed,
    required this.occurredAt,
    required this.baseRevision,
  });

  final String id;
  final String courseId;
  final String lessonId;
  final ProgressMutationKind kind;
  final Duration position;
  final Duration duration;
  final bool completed;
  final DateTime occurredAt;
  final int baseRevision;
}

final class LearningHistoryEntry {
  const LearningHistoryEntry({
    required this.courseId,
    required this.lessonId,
    required this.visitedAt,
  });
  final String courseId;
  final String lessonId;
  final DateTime visitedAt;
}

/// Precomputes navigation and lookup once, avoiding repeated course scans in UI.
final class CourseOutlineIndex {
  CourseOutlineIndex._({
    required this.lessons,
    required this.moduleByLessonId,
    required this.indexByLessonId,
  });

  factory CourseOutlineIndex.fromCourse(Course course) {
    final modules = [...course.modules]
      ..sort((a, b) => a.position.compareTo(b.position));
    final lessons = <Lesson>[];
    final moduleByLessonId = <String, CourseModule>{};
    for (final module in modules) {
      final ordered = [...module.lessons]
        ..sort((a, b) => a.position.compareTo(b.position));
      for (final lesson in ordered) {
        if (moduleByLessonId.containsKey(lesson.id)) {
          throw ArgumentError.value(lesson.id, 'lesson.id', 'Duplicate ID');
        }
        lessons.add(lesson);
        moduleByLessonId[lesson.id] = module;
      }
    }
    return CourseOutlineIndex._(
      lessons: List.unmodifiable(lessons),
      moduleByLessonId: Map.unmodifiable(moduleByLessonId),
      indexByLessonId: Map.unmodifiable({
        for (var index = 0; index < lessons.length; index++)
          lessons[index].id: index,
      }),
    );
  }

  final List<Lesson> lessons;
  final Map<String, CourseModule> moduleByLessonId;
  final Map<String, int> indexByLessonId;

  Lesson? lesson(String id) => switch (indexByLessonId[id]) {
    final index? => lessons[index],
    null => null,
  };
  Lesson? previous(String id) => switch (indexByLessonId[id]) {
    final index? when index > 0 => lessons[index - 1],
    _ => null,
  };
  Lesson? next(String id) => switch (indexByLessonId[id]) {
    final index? when index + 1 < lessons.length => lessons[index + 1],
    _ => null,
  };
}

abstract final class CourseProgressCalculator {
  static double fraction(CourseOutlineIndex outline, CourseProgress progress) {
    if (outline.lessons.isEmpty) return 0;
    var completed = 0;
    for (final lesson in outline.lessons) {
      if (progress.lessons[lesson.id]?.completed ?? false) completed++;
    }
    return completed / outline.lessons.length;
  }

  static Lesson? resumeLesson(
    CourseOutlineIndex outline,
    CourseProgress progress,
  ) {
    LessonProgress? latest;
    for (final value in progress.lessons.values) {
      if (!value.completed && value.position > Duration.zero) {
        if (latest == null || value.updatedAt.isAfter(latest.updatedAt)) {
          latest = value;
        }
      }
    }
    if (latest != null) return outline.lesson(latest.lessonId);
    for (final lesson in outline.lessons) {
      if (!(progress.lessons[lesson.id]?.completed ?? false)) return lesson;
    }
    return outline.lessons.firstOrNull;
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

abstract final class ProgressReconciler {
  /// Server state is the baseline. Unacknowledged local mutations are replayed
  /// in event order; completion is monotonic unless the server accepts an
  /// explicit completion mutation that changes it.
  static CourseProgress reconcile(
    CourseProgress server,
    Iterable<ProgressMutation> pending,
  ) {
    final lessons = Map<String, LessonProgress>.of(server.lessons);
    final ordered = [...pending]
      ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    var updatedAt = server.updatedAt;
    for (final mutation in ordered) {
      if (mutation.courseId != server.courseId) {
        continue;
      }
      final current = lessons[mutation.lessonId];
      final completed = mutation.kind == ProgressMutationKind.completion
          ? mutation.completed
          : (current?.completed ?? false);
      lessons[mutation.lessonId] = LessonProgress(
        lessonId: mutation.lessonId,
        position: completed ? mutation.duration : mutation.position,
        duration: mutation.duration,
        completed: completed,
        updatedAt: mutation.occurredAt,
      );
      if (mutation.occurredAt.isAfter(updatedAt)) {
        updatedAt = mutation.occurredAt;
      }
    }
    return server.copyWith(lessons: lessons, updatedAt: updatedAt);
  }
}
