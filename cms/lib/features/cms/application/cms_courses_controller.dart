import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nadha_cms/core/errors/result.dart';
import 'package:nadha_cms/features/cms/data/cms_repository.dart';
import 'package:nadha_cms/features/cms/domain/cms_course.dart';

@immutable
final class CmsCoursesState {
  const CmsCoursesState({
    this.academic = const {},
    this.isLoading = false,
    this.isUpdating = false,
    this.courses = const [],
    this.selectedFilter = 'all',
    this.searchQuery = '',
    this.errorMessage,
    this.successMessage,
  });

  final bool isLoading;
  final Map<String, Object?> academic;
  final bool isUpdating;
  final List<CmsCourseSummary> courses;
  final String selectedFilter;
  final String searchQuery;
  final String? errorMessage;
  final String? successMessage;

  List<CmsCourseSummary> get filteredCourses {
    var list = courses;
    list = list
        .where(
          (c) => academic.entries.every(
            (e) => e.value == null || c.academic[e.key] == e.value,
          ),
        )
        .toList();
    if (selectedFilter != 'all') {
      list = list.where((c) => c.status == selectedFilter).toList();
    }
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      list = list
          .where(
            (c) =>
                c.title.toLowerCase().contains(q) ||
                c.subtitle.toLowerCase().contains(q),
          )
          .toList();
    }
    return list;
  }

  CmsCoursesState copyWith({
    Map<String, Object?>? academic,
    bool? isLoading,
    bool? isUpdating,
    List<CmsCourseSummary>? courses,
    String? selectedFilter,
    String? searchQuery,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) => CmsCoursesState(
    academic: academic ?? this.academic,
    isLoading: isLoading ?? this.isLoading,
    isUpdating: isUpdating ?? this.isUpdating,
    courses: courses ?? this.courses,
    selectedFilter: selectedFilter ?? this.selectedFilter,
    searchQuery: searchQuery ?? this.searchQuery,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    successMessage: clearSuccess
        ? null
        : (successMessage ?? this.successMessage),
  );
}

final class CmsCoursesController extends StateNotifier<CmsCoursesState> {
  CmsCoursesController({required CmsRepository repository})
    : _repository = repository,
      super(const CmsCoursesState(isLoading: true)) {
    unawaited(load());
  }

  final CmsRepository _repository;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final collected = <CmsCourseSummary>[];
    Result<List<CmsCourseSummary>> result;
    var page = 1;
    while (true) {
      result = await _repository.getCourses(pageSize: 100, page: page++);
      if (!mounted) return;
      if (result case Success(value: final rows)) {
        collected.addAll(rows);
        if (rows.length < 100) {
          result = Success(collected);
          break;
        }
      } else {
        break;
      }
    }
    state = switch (result) {
      Success(value: final items) => state.copyWith(
        isLoading: false,
        courses: items,
        clearError: true,
      ),
      Failure(failure: final failure) => state.copyWith(
        isLoading: false,
        errorMessage: failure.message,
      ),
    };
  }

  void setFilter(String filter) {
    state = state.copyWith(selectedFilter: filter);
  }

  void setAcademic(Map<String, Object?> value) {
    state = state.copyWith(academic: value);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  Future<bool> updateStatus({
    required String courseId,
    required String status,
    String? reason,
  }) async {
    state = state.copyWith(
      isUpdating: true,
      clearError: true,
      clearSuccess: true,
    );
    final result = await _repository.updateCourseStatus(
      courseId: courseId,
      status: status,
      reason: reason,
    );
    return switch (result) {
      Success(value: final updated) => () {
        final updatedList = state.courses.map((c) {
          return c.id == updated.id ? updated : c;
        }).toList();
        state = state.copyWith(
          isUpdating: false,
          courses: updatedList,
          successMessage:
              'Course "${updated.title}" status changed to $status.',
        );
        return true;
      }(),
      Failure(failure: final failure) => () {
        state = state.copyWith(
          isUpdating: false,
          errorMessage: failure.message,
        );
        return false;
      }(),
    };
  }
}
