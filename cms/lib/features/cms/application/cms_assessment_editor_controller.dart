import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nadha_cms/core/errors/result.dart';
import 'package:nadha_cms/features/cms/data/cms_repository.dart';
import 'package:nadha_cms/features/cms/domain/cms_assessment.dart';

@immutable
final class CmsAssessmentEditorState {
  const CmsAssessmentEditorState({
    this.assessment,
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
    this.successMessage,
    this.isDirty = false,
  });

  final CmsAssessmentDetail? assessment;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;
  final String? successMessage;
  final bool isDirty;

  CmsAssessmentEditorState copyWith({
    CmsAssessmentDetail? assessment,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    String? successMessage,
    bool? isDirty,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return CmsAssessmentEditorState(
      assessment: assessment ?? this.assessment,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess
          ? null
          : (successMessage ?? this.successMessage),
      isDirty: isDirty ?? this.isDirty,
    );
  }
}

final class CmsAssessmentEditorController
    extends StateNotifier<CmsAssessmentEditorState> {
  CmsAssessmentEditorController({
    required CmsRepository repository,
    required String assessmentId,
    String? courseId,
  }) : _repository = repository,
       _assessmentId = assessmentId,
       _courseId = courseId,
       super(const CmsAssessmentEditorState()) {
    unawaited(load());
  }

  final CmsRepository _repository;
  final String _assessmentId;
  final String? _courseId;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);

    if (_assessmentId == 'new') {
      state = state.copyWith(
        isLoading: false,
        assessment: CmsAssessmentDetail(
          id: 'new',
          courseId: _courseId ?? '',
          title: '',
          description: '',
          instructions: const [],
          passingPercentage: 70,
          timeLimitSeconds: 1800,
          maxAttempts: 3,
          requiredForCertificate: true,
          protectionPolicy: 'blockCaptureWhereSupported',
          status: 'draft',
          questions: const [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      return;
    }

    final result = await _repository.getAssessmentDetail(_assessmentId);
    state = switch (result) {
      Success(value: final a) => state.copyWith(
        isLoading: false,
        assessment: a,
      ),
      Failure(failure: final f) => state.copyWith(
        isLoading: false,
        errorMessage: f.message,
      ),
    };
  }

  Future<bool> saveAssessment({
    required String title,
    required String description,
    required List<String> instructions,
    required int passingPercentage,
    int? timeLimitSeconds,
    required int maxAttempts,
    required bool requiredForCertificate,
    required String protectionPolicy,
    required String status,
  }) async {
    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );

    final payload = {
      'title': title.trim(),
      'description': description.trim(),
      'instructions': instructions,
      'passingPercentage': passingPercentage,
      'timeLimitSeconds': ?timeLimitSeconds,
      'maxAttempts': maxAttempts,
      'requiredForCertificate': requiredForCertificate,
      'protectionPolicy': protectionPolicy,
      'status': status,
    };

    final result = state.assessment?.id == 'new' || state.assessment == null
        ? await _repository.createAssessment(
            state.assessment?.courseId ?? _courseId ?? '',
            payload,
          )
        : await _repository.updateAssessment(state.assessment!.id, payload);

    return switch (result) {
      Success(value: final updated) => () {
        state = state.copyWith(
          isSaving: false,
          assessment: updated,
          successMessage: 'Assessment settings saved.',
        );
        return true;
      }(),
      Failure(failure: final f) => () {
        state = state.copyWith(isSaving: false, errorMessage: f.message);
        return false;
      }(),
    };
  }

  Future<bool> addQuestion(Map<String, Object?> payload) async {
    final assessment = state.assessment;
    if (assessment == null || assessment.id == 'new') return false;

    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );
    final result = await _repository.createQuestion(assessment.id, payload);

    return switch (result) {
      Success() => () async {
        await load();
        state = state.copyWith(
          isSaving: false,
          successMessage: 'Question added.',
        );
        return true;
      }(),
      Failure(failure: final f) => () {
        state = state.copyWith(isSaving: false, errorMessage: f.message);
        return false;
      }(),
    };
  }

  Future<bool> updateQuestion(
    String questionId,
    Map<String, Object?> payload,
  ) async {
    final assessment = state.assessment;
    if (assessment == null) return false;

    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );
    final result = await _repository.updateQuestion(
      assessment.id,
      questionId,
      payload,
    );

    return switch (result) {
      Success() => () async {
        await load();
        state = state.copyWith(
          isSaving: false,
          successMessage: 'Question updated.',
        );
        return true;
      }(),
      Failure(failure: final f) => () {
        state = state.copyWith(isSaving: false, errorMessage: f.message);
        return false;
      }(),
    };
  }

  Future<bool> deleteQuestion(String questionId) async {
    final assessment = state.assessment;
    if (assessment == null) return false;

    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );
    final result = await _repository.deleteQuestion(assessment.id, questionId);

    return switch (result) {
      Success() => () async {
        await load();
        state = state.copyWith(
          isSaving: false,
          successMessage: 'Question removed.',
        );
        return true;
      }(),
      Failure(failure: final f) => () {
        state = state.copyWith(isSaving: false, errorMessage: f.message);
        return false;
      }(),
    };
  }

  Future<bool> reorderQuestions(int oldIndex, int newIndex) async {
    final assessment = state.assessment;
    if (assessment == null) return false;

    final qList = List<CmsQuestionDetail>.from(assessment.questions);
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = qList.removeAt(oldIndex);
    qList.insert(newIndex, item);

    final questionIds = qList.map((q) => q.id).toList();
    final result = await _repository.reorderQuestions(
      assessment.id,
      questionIds,
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
}
