import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:learning_platform/core/errors/app_failure.dart';
import 'package:learning_platform/core/errors/result.dart';
import 'package:learning_platform/features/content_catalog/domain/catalog_repository.dart';
import 'package:learning_platform/features/content_catalog/domain/course.dart';

final class BookmarksState {
  const BookmarksState({
    this.ids = const {},
    this.courses = const [],
    this.failure,
    this.isLoading = false,
  });
  final Set<String> ids;
  final List<CourseSummary> courses;
  final AppFailure? failure;
  final bool isLoading;
}

final class BookmarksController extends StateNotifier<BookmarksState> {
  BookmarksController(this._repository) : super(const BookmarksState());
  final CatalogRepository _repository;

  Future<void> load() async {
    state = BookmarksState(
      ids: state.ids,
      courses: state.courses,
      isLoading: true,
    );
    final result = await _repository.getBookmarkedCourses();
    if (!mounted) return;
    switch (result) {
      case Success<List<CourseSummary>>(value: final courses):
        state = BookmarksState(
          ids: courses.map((course) => course.id).toSet(),
          courses: courses,
        );
      case Failure<List<CourseSummary>>(failure: final failure):
        state = BookmarksState(
          ids: state.ids,
          courses: state.courses,
          failure: failure,
        );
    }
  }

  Future<void> toggle(String courseId) async {
    final wasBookmarked = state.ids.contains(courseId);
    final result = await _repository.setBookmarked(
      courseId,
      bookmarked: !wasBookmarked,
    );
    if (!mounted) return;
    switch (result) {
      case Success<void>():
        final ids = {...state.ids};
        wasBookmarked ? ids.remove(courseId) : ids.add(courseId);
        state = BookmarksState(
          ids: ids,
          courses: state.courses
              .where((course) => ids.contains(course.id))
              .toList(growable: false),
        );
      case Failure<void>(failure: final failure):
        state = BookmarksState(
          ids: state.ids,
          courses: state.courses,
          failure: failure,
        );
    }
  }
}
