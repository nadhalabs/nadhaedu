import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nadha_cms/core/errors/result.dart';
import 'package:nadha_cms/features/cms/data/cms_repository.dart';
import 'package:nadha_cms/features/cms/domain/cms_course_detail.dart';

@immutable
final class CmsCourseEditorState {
  const CmsCourseEditorState({
    this.course,
    this.categories = const [],
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
    this.successMessage,
    this.isDirty = false,
    this.activeTab = 0,
  });

  final CmsCourseDetail? course;
  final List<CmsCategory> categories;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;
  final String? successMessage;
  final bool isDirty;
  final int activeTab;

  CmsCourseEditorState copyWith({
    CmsCourseDetail? course,
    List<CmsCategory>? categories,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    String? successMessage,
    bool? isDirty,
    int? activeTab,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return CmsCourseEditorState(
      course: course ?? this.course,
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess
          ? null
          : (successMessage ?? this.successMessage),
      isDirty: isDirty ?? this.isDirty,
      activeTab: activeTab ?? this.activeTab,
    );
  }
}

final class CmsCourseEditorController
    extends StateNotifier<CmsCourseEditorState> {
  CmsCourseEditorController({
    required CmsRepository repository,
    required String courseId,
  }) : _repository = repository,
       _courseId = courseId,
       super(const CmsCourseEditorState()) {
    unawaited(load());
  }

  final CmsRepository _repository;
  final String _courseId;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);

    final catsResult = await _repository.getCategories();
    final categories = switch (catsResult) {
      Success(value: final cats) => cats,
      Failure() => const <CmsCategory>[],
    };

    if (_courseId == 'new') {
      state = state.copyWith(
        isLoading: false,
        categories: categories,
        course: CmsCourseDetail(
          id: 'new',
          title: '',
          subtitle: '',
          description: '',
          level: 'allLevels',
          languageCode: 'en',
          policyKind: 'free',
          protectionPolicy: 'blockCaptureWhereSupported',
          status: 'draft',
          rating: 0,
          ratingCount: 0,
          durationSeconds: 0,
          learningOutcomes: const [],
          prerequisites: const [],
          categories: const [],
          tags: const [],
          modules: const [],
          assessments: const [],
          validation: CmsCourseValidation.empty,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      return;
    }

    final courseResult = await _repository.getCourseDetail(_courseId);
    state = switch (courseResult) {
      Success(value: final course) => state.copyWith(
        isLoading: false,
        course: course,
        categories: categories,
      ),
      Failure(failure: final f) => state.copyWith(
        isLoading: false,
        errorMessage: f.message,
        categories: categories,
      ),
    };
  }

  void setTab(int tabIndex) {
    state = state.copyWith(activeTab: tabIndex);
  }

  Future<bool> saveMetadata({
    Map<String, Object?> academic = const {},
    required String title,
    required String subtitle,
    required String description,
    required String level,
    required String languageCode,
    required String policyKind,
    required String protectionPolicy,
    String? requiredTier,
    required List<String> categoryIds,
    required List<String> tags,
    required List<String> learningOutcomes,
    required List<String> prerequisites,
  }) async {
    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );

    final payload = {
      ...academic,
      'title': title.trim(),
      'subtitle': subtitle.trim(),
      'description': description.trim(),
      'level': level,
      'languageCode': languageCode,
      'policyKind': policyKind,
      'protectionPolicy': protectionPolicy,
      if (requiredTier != null && requiredTier.isNotEmpty)
        'requiredTier': requiredTier,
      'categoryIds': categoryIds,
      'tags': tags,
      'learningOutcomes': learningOutcomes,
      'prerequisites': prerequisites,
    };

    final result = state.course?.id == 'new' || state.course == null
        ? await _repository.createCourse(payload)
        : await _repository.updateCourse(state.course!.id, payload);

    return switch (result) {
      Success(value: final course) => () {
        state = state.copyWith(
          isSaving: false,
          course: course,
          isDirty: false,
          successMessage: 'Course saved successfully.',
        );
        return true;
      }(),
      Failure(failure: final f) => () {
        state = state.copyWith(isSaving: false, errorMessage: f.message);
        return false;
      }(),
    };
  }

  Future<bool> addModule(String title, {String policyKind = 'inherit'}) async {
    final course = state.course;
    if (course == null || course.id == 'new') return false;

    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );
    final result = await _repository.createModule(
      course.id,
      title: title,
      policyKind: policyKind,
    );

    return switch (result) {
      Success() => () async {
        await load();
        state = state.copyWith(
          isSaving: false,
          successMessage: 'Curriculum section added.',
        );
        return true;
      }(),
      Failure(failure: final f) => () {
        state = state.copyWith(isSaving: false, errorMessage: f.message);
        return false;
      }(),
    };
  }

  Future<bool> updateModule(
    String moduleId, {
    String? title,
    String? policyKind,
  }) async {
    final course = state.course;
    if (course == null) return false;

    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );
    final result = await _repository.updateModule(
      course.id,
      moduleId,
      title: title,
      policyKind: policyKind,
    );

    return switch (result) {
      Success() => () async {
        await load();
        state = state.copyWith(
          isSaving: false,
          successMessage: 'Section updated.',
        );
        return true;
      }(),
      Failure(failure: final f) => () {
        state = state.copyWith(isSaving: false, errorMessage: f.message);
        return false;
      }(),
    };
  }

  Future<bool> deleteModule(String moduleId) async {
    final course = state.course;
    if (course == null) return false;

    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );
    final result = await _repository.deleteModule(course.id, moduleId);

    return switch (result) {
      Success() => () async {
        await load();
        state = state.copyWith(
          isSaving: false,
          successMessage: 'Section removed.',
        );
        return true;
      }(),
      Failure(failure: final f) => () {
        state = state.copyWith(isSaving: false, errorMessage: f.message);
        return false;
      }(),
    };
  }

  Future<bool> reorderModules(int oldIndex, int newIndex) async {
    final course = state.course;
    if (course == null) return false;

    final moduleList = List<CmsModuleDetail>.from(course.modules);
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = moduleList.removeAt(oldIndex);
    moduleList.insert(newIndex, item);

    final moduleIds = moduleList.map((m) => m.id).toList();
    final result = await _repository.reorderModules(course.id, moduleIds);

    return switch (result) {
      Success() => () async {
        await load();
        return true;
      }(),
      Failure(failure: final f) => () {
        state = state.copyWith(errorMessage: f.message);
        return false;
      }(),
    };
  }

  Future<bool> addLesson(String moduleId, Map<String, Object?> payload) async {
    final course = state.course;
    if (course == null) return false;

    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );
    final result = await _repository.createLesson(course.id, moduleId, payload);

    return switch (result) {
      Success() => () async {
        await load();
        state = state.copyWith(
          isSaving: false,
          successMessage: 'Lesson added successfully.',
        );
        return true;
      }(),
      Failure(failure: final f) => () {
        state = state.copyWith(isSaving: false, errorMessage: f.message);
        return false;
      }(),
    };
  }

  Future<bool> updateLesson(
    String moduleId,
    String lessonId,
    Map<String, Object?> payload,
  ) async {
    final course = state.course;
    if (course == null) return false;

    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );
    final result = await _repository.updateLesson(
      course.id,
      moduleId,
      lessonId,
      payload,
    );

    return switch (result) {
      Success() => () async {
        await load();
        state = state.copyWith(
          isSaving: false,
          successMessage: 'Lesson updated.',
        );
        return true;
      }(),
      Failure(failure: final f) => () {
        state = state.copyWith(isSaving: false, errorMessage: f.message);
        return false;
      }(),
    };
  }

  Future<bool> deleteLesson(String moduleId, String lessonId) async {
    final course = state.course;
    if (course == null) return false;

    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );
    final result = await _repository.deleteLesson(
      course.id,
      moduleId,
      lessonId,
    );

    return switch (result) {
      Success() => () async {
        await load();
        state = state.copyWith(
          isSaving: false,
          successMessage: 'Lesson removed.',
        );
        return true;
      }(),
      Failure(failure: final f) => () {
        state = state.copyWith(isSaving: false, errorMessage: f.message);
        return false;
      }(),
    };
  }

  Future<bool> reorderLessons(
    String moduleId,
    int oldIndex,
    int newIndex,
  ) async {
    final course = state.course;
    if (course == null) return false;

    final module = course.modules.firstWhere((m) => m.id == moduleId);
    final lessonList = List<CmsLessonDetail>.from(module.lessons);
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = lessonList.removeAt(oldIndex);
    lessonList.insert(newIndex, item);

    final lessonIds = lessonList.map((l) => l.id).toList();
    final result = await _repository.reorderLessons(
      course.id,
      moduleId,
      lessonIds,
    );

    return switch (result) {
      Success() => () async {
        await load();
        return true;
      }(),
      Failure(failure: final f) => () {
        state = state.copyWith(errorMessage: f.message);
        return false;
      }(),
    };
  }

  Future<bool> publish({String? reason}) async {
    final course = state.course;
    if (course == null) return false;

    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );
    final result = await _repository.publishCourse(course.id, reason: reason);

    return switch (result) {
      Success(value: final updated) => () {
        state = state.copyWith(
          isSaving: false,
          course: updated,
          successMessage: 'Course published successfully!',
        );
        return true;
      }(),
      Failure(failure: final f) => () {
        state = state.copyWith(isSaving: false, errorMessage: f.message);
        return false;
      }(),
    };
  }

  Future<bool> unpublish({String? reason}) async {
    final course = state.course;
    if (course == null) return false;

    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );
    final result = await _repository.unpublishCourse(course.id, reason: reason);

    return switch (result) {
      Success(value: final updated) => () {
        state = state.copyWith(
          isSaving: false,
          course: updated,
          successMessage: 'Course unpublished to draft.',
        );
        return true;
      }(),
      Failure(failure: final f) => () {
        state = state.copyWith(isSaving: false, errorMessage: f.message);
        return false;
      }(),
    };
  }

  Future<bool> deleteCourse({String? reason}) async {
    final course = state.course;
    if (course == null) return false;

    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );
    final result = await _repository.deleteCourse(course.id, reason: reason);

    return switch (result) {
      Success() => () {
        state = state.copyWith(isSaving: false);
        return true;
      }(),
      Failure(failure: final f) => () {
        state = state.copyWith(isSaving: false, errorMessage: f.message);
        return false;
      }(),
    };
  }
}
