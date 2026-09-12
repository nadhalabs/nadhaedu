import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_platform/bootstrap/providers.dart';
import 'package:learning_platform/config/app_environment.dart';
import 'package:learning_platform/core/errors/result.dart';
import 'package:learning_platform/features/academic/academic_profile.dart';
import 'package:learning_platform/features/authentication/application/auth_providers.dart';
import 'package:learning_platform/features/content_catalog/application/catalog_providers.dart';
import 'package:learning_platform/features/content_catalog/domain/course.dart';
import 'package:learning_platform/features/entitlements/application/entitlement_providers.dart';
import 'package:learning_platform/features/learning_progress/application/learning_controller.dart';
import 'package:learning_platform/features/learning_progress/data/foundation_learning_data_source.dart';
import 'package:learning_platform/features/learning_progress/data/learning_data_source.dart';
import 'package:learning_platform/features/learning_progress/data/learning_repository_impl.dart';
import 'package:learning_platform/features/learning_progress/data/remote_learning_data_source.dart';
import 'package:learning_platform/features/learning_progress/domain/learning_progress.dart';
import 'package:learning_platform/features/learning_progress/domain/learning_repository.dart';

final learningDataSourceProvider = Provider<LearningDataSource>(
  (ref) => switch (ref.watch(appConfigProvider).environment) {
    AppEnvironment.development => FoundationLearningDataSource(
      entitlementDataSource: ref.watch(entitlementDataSourceProvider),
    ),
    AppEnvironment.staging || AppEnvironment.production =>
      RemoteLearningDataSource(ref.watch(apiClientProvider)),
  },
);

final learningRepositoryProvider = Provider<LearningRepository>((ref) {
  final learnerId = ref.watch(
    authControllerProvider.select((state) => state.session?.identity.id),
  );
  if (learnerId == null) {
    throw StateError('An authenticated learner is required.');
  }
  return LearningRepositoryImpl(
    remote: ref.watch(learningDataSourceProvider),
    localStore: ref.watch(keyValueStoreProvider),
    learnerId: learnerId,
  );
});

final learningControllerProvider = StateNotifierProvider.autoDispose
    .family<
      LearningController,
      LearningState,
      ({String courseId, String? lessonId})
    >((ref, args) {
      final controller = LearningController(
        catalogRepository: ref.watch(catalogRepositoryProvider),
        learningRepository: ref.watch(learningRepositoryProvider),
        courseId: args.courseId,
        initialLessonId: args.lessonId,
      );
      unawaited(controller.load());
      return controller;
    });

final learningHistoryProvider =
    FutureProvider.autoDispose<List<LearningHistoryEntry>>((ref) {
      return ref.watch(learningRepositoryProvider).getHistory();
    });

final class LearningHistoryViewItem {
  const LearningHistoryViewItem({
    required this.entry,
    required this.courseTitle,
    required this.lessonTitle,
  });
  final LearningHistoryEntry entry;
  final String courseTitle;
  final String lessonTitle;
}

final learningHistoryViewProvider =
    FutureProvider.autoDispose<List<LearningHistoryViewItem>>((ref) async {
      ref.watch(academicContextKeyProvider);
      final profile = await ref.watch(academicProfileProvider.future);
      final catalogRepository = ref.watch(catalogRepositoryProvider);
      final entries = await ref
          .watch(learningRepositoryProvider)
          .getHistory(limit: 100);
      final courseIds = entries.map((item) => item.courseId).toSet();
      final results = await Future.wait([
        for (final courseId in courseIds) catalogRepository.getCourse(courseId),
      ]);
      final courses = <String, Course>{};
      for (final result in results) {
        if (result case Success<Course>(value: final course)) {
          if (profile != null &&
              (course.summary.curriculumId != profile.curriculumId ||
                  course.summary.standardId != profile.standardId ||
                  course.summary.streamId != profile.streamId)) {
            continue;
          }
          courses[course.summary.id] = course;
        }
      }
      final outlines = {
        for (final entry in courses.entries)
          entry.key: CourseOutlineIndex.fromCourse(entry.value),
      };
      return [
        for (final entry in entries)
          if (courses[entry.courseId] case final course?)
            LearningHistoryViewItem(
              entry: entry,
              courseTitle: course.summary.title,
              lessonTitle:
                  outlines[course.summary.id]?.lesson(entry.lessonId)?.title ??
                  'Lesson',
            ),
      ];
    });
