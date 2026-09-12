import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_platform/core/errors/result.dart';
import 'package:learning_platform/features/content_catalog/domain/catalog_repository.dart';
import 'package:learning_platform/features/content_catalog/domain/course.dart';
import 'package:learning_platform/features/learning_progress/domain/learning_progress.dart';
import 'package:learning_platform/features/learning_progress/domain/learning_repository.dart';

final class LearningState {
  const LearningState({
    this.course,
    this.outline,
    this.progress,
    this.selectedLessonId,
    this.isLoading = false,
    this.isSyncing = false,
    this.isCompleting = false,
    this.courseProgressFraction = 0,
    this.errorMessage,
  });
  final Course? course;
  final CourseOutlineIndex? outline;
  final CourseProgress? progress;
  final String? selectedLessonId;
  final bool isLoading;
  final bool isSyncing;
  final bool isCompleting;
  final double courseProgressFraction;
  final String? errorMessage;

  Lesson? get selectedLesson => switch ((outline, selectedLessonId)) {
    (final outline?, final id?) => outline.lesson(id),
    _ => null,
  };

  LearningState copyWith({
    Course? course,
    CourseOutlineIndex? outline,
    CourseProgress? progress,
    String? selectedLessonId,
    bool? isLoading,
    bool? isSyncing,
    bool? isCompleting,
    double? courseProgressFraction,
    String? errorMessage,
    bool clearError = false,
  }) => LearningState(
    course: course ?? this.course,
    outline: outline ?? this.outline,
    progress: progress ?? this.progress,
    selectedLessonId: selectedLessonId ?? this.selectedLessonId,
    isLoading: isLoading ?? this.isLoading,
    isSyncing: isSyncing ?? this.isSyncing,
    isCompleting: isCompleting ?? this.isCompleting,
    courseProgressFraction:
        courseProgressFraction ?? this.courseProgressFraction,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
  );
}

final class LearningController extends StateNotifier<LearningState> {
  LearningController({
    required CatalogRepository catalogRepository,
    required LearningRepository learningRepository,
    required String courseId,
    String? initialLessonId,
  }) : _catalogRepository = catalogRepository,
       _learningRepository = learningRepository,
       _courseId = courseId,
       _initialLessonId = initialLessonId,
       super(const LearningState());

  static const syncInterval = Duration(seconds: 30);
  final CatalogRepository _catalogRepository;
  final LearningRepository _learningRepository;
  final String _courseId;
  final String? _initialLessonId;
  Timer? _syncTimer;

  bool get hasPrevious =>
      state.selectedLessonId != null &&
      state.outline?.previous(state.selectedLessonId!) != null;
  bool get hasNext =>
      state.selectedLessonId != null &&
      state.outline?.next(state.selectedLessonId!) != null;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final courseResult = await _catalogRepository.getCourse(_courseId);
    if (!mounted) return;
    switch (courseResult) {
      case Failure<Course>(failure: final failure):
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
      case Success<Course>(value: final course):
        try {
          final outline = CourseOutlineIndex.fromCourse(course);
          final progress = await _learningRepository.loadProgress(_courseId);
          if (!mounted) return;
          final requested = _initialLessonId == null
              ? null
              : outline.lesson(_initialLessonId);
          final selected =
              requested ??
              CourseProgressCalculator.resumeLesson(outline, progress);
          state = LearningState(
            course: course,
            outline: outline,
            progress: progress,
            selectedLessonId: selected?.id,
            courseProgressFraction: CourseProgressCalculator.fraction(
              outline,
              progress,
            ),
          );
        } on Object {
          if (!mounted) return;
          state = state.copyWith(
            isLoading: false,
            errorMessage: 'Learning progress is temporarily unavailable.',
          );
        }
    }
  }

  void selectLesson(String lessonId) {
    if (!mounted || state.outline?.lesson(lessonId) == null) return;
    state = state.copyWith(selectedLessonId: lessonId, clearError: true);
  }

  void selectPrevious() {
    final id = state.selectedLessonId;
    if (id == null) return;
    final lesson = state.outline?.previous(id);
    if (lesson != null) selectLesson(lesson.id);
  }

  void selectNext() {
    final id = state.selectedLessonId;
    if (id == null) return;
    final lesson = state.outline?.next(id);
    if (lesson != null) selectLesson(lesson.id);
  }

  Future<void> recordPosition(
    Duration position,
    Duration duration, {
    String? lessonId,
  }) async {
    if (!mounted) return;
    final lesson = lessonId == null
        ? state.selectedLesson
        : state.outline?.lesson(lessonId);
    if (lesson == null) return;
    try {
      final progress = await _learningRepository.recordPosition(
        courseId: _courseId,
        lessonId: lesson.id,
        position: position,
        duration: duration,
        occurredAt: DateTime.now().toUtc(),
      );
      if (mounted) {
        state = state.copyWith(
          progress: progress,
          courseProgressFraction: CourseProgressCalculator.fraction(
            state.outline!,
            progress,
          ),
        );
      }
      if (mounted) _scheduleSync();
    } on Object {
      if (mounted) {
        state = state.copyWith(
          errorMessage: 'We couldn’t save your place. Reconnect and try again.',
        );
      }
    }
  }

  Future<void> toggleCompleted() async {
    if (!mounted || state.isCompleting) return;
    final lesson = state.selectedLesson;
    final progress = state.progress;
    if (lesson == null ||
        progress == null ||
        (!lesson.hasContentItems && lesson.content is QuizLessonContent)) {
      return;
    }
    final current = progress.lessons[lesson.id];
    if (current?.completed ?? false) return;
    const completed = true;
    state = state.copyWith(isCompleting: true, clearError: true);
    try {
      final updated = await _learningRepository.setCompleted(
        courseId: _courseId,
        lessonId: lesson.id,
        completed: completed,
        position: current?.position ?? Duration.zero,
        duration: current?.duration ?? lesson.estimatedDuration,
        occurredAt: DateTime.now().toUtc(),
      );
      if (mounted) {
        state = state.copyWith(
          progress: updated,
          courseProgressFraction: CourseProgressCalculator.fraction(
            state.outline!,
            updated,
          ),
        );
      }
      if (mounted) _scheduleSync();
    } on Object {
      if (mounted) {
        state = state.copyWith(
          errorMessage: 'We couldn’t save that step. Please try again.',
        );
      }
    } finally {
      if (mounted) state = state.copyWith(isCompleting: false);
    }
  }

  void _scheduleSync() {
    _syncTimer ??= Timer(syncInterval, () {
      _syncTimer = null;
      unawaited(synchronize());
    });
  }

  Future<void> synchronize() async {
    if (!mounted || state.isSyncing || state.outline == null) return;
    state = state.copyWith(isSyncing: true);
    try {
      final progress = await _learningRepository.synchronize(_courseId);
      if (mounted) {
        state = state.copyWith(
          progress: progress,
          courseProgressFraction: CourseProgressCalculator.fraction(
            state.outline!,
            progress,
          ),
          isSyncing: false,
          clearError: true,
        );
      }
    } on Object {
      if (mounted) {
        state = state.copyWith(
          isSyncing: false,
          errorMessage:
              'Saved on this device. Reconnect to sync your progress.',
        );
      }
    }
  }

  /// Refreshes progress after a server-side operation such as an accepted
  /// assessment submission. It never manufactures completion locally.
  Future<void> refreshAuthoritativeProgress() async {
    try {
      final progress = await _learningRepository.loadProgress(_courseId);
      if (mounted) {
        state = state.copyWith(
          progress: progress,
          courseProgressFraction: CourseProgressCalculator.fraction(
            state.outline!,
            progress,
          ),
        );
      }
    } on Object {
      // The accepted server result remains authoritative; a later refresh will
      // reconcile presentation state after transient failures.
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    // Flush the repository without mutating a disposed controller.
    unawaited(
      _learningRepository
          .synchronize(_courseId)
          .then<void>((_) {}, onError: (Object _, StackTrace _) {}),
    );
    super.dispose();
  }
}
