import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:learning_platform/core/errors/app_failure.dart';
import 'package:learning_platform/core/errors/result.dart';
import 'package:learning_platform/features/content_catalog/domain/catalog_repository.dart';
import 'package:learning_platform/features/content_catalog/domain/course.dart';

final class CourseDetailState {
  const CourseDetailState({this.course, this.failure, this.isLoading = false});
  final Course? course;
  final AppFailure? failure;
  final bool isLoading;
}

final class CourseDetailController extends StateNotifier<CourseDetailState> {
  CourseDetailController(this._repository, this._courseId)
    : super(const CourseDetailState());

  final CatalogRepository _repository;
  final String _courseId;

  Future<void> load() async {
    state = CourseDetailState(course: state.course, isLoading: true);
    final result = await _repository.getCourse(_courseId);
    switch (result) {
      case Success<Course>(value: final course):
        state = CourseDetailState(course: course);
        await _repository.recordRecentlyViewed(_courseId);
      case Failure<Course>(failure: final failure):
        state = CourseDetailState(course: state.course, failure: failure);
    }
  }
}
