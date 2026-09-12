import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_platform/core/errors/app_failure.dart';
import 'package:learning_platform/features/assessments/application/assessment_state.dart';
import 'package:learning_platform/features/assessments/data/assessment_data_source.dart';
import 'package:learning_platform/features/assessments/domain/assessment_question.dart';
import 'package:learning_platform/features/assessments/domain/assessment_repository.dart';
import 'package:learning_platform/features/assessments/domain/assessment_submission.dart';

final class AssessmentController extends StateNotifier<AssessmentSessionState> {
  AssessmentController({
    required AssessmentRepository repository,
    required String assessmentId,
    required String learnerId,
    Future<void> Function(String assessmentId)? onPassed,
  }) : _repository = repository,
       _assessmentId = assessmentId,
       _learnerId = learnerId,
       _onPassed = onPassed,
       super(AssessmentSessionState.initial()) {
    unawaited(load());
  }

  final AssessmentRepository _repository;
  final String _assessmentId;
  final String _learnerId;
  final Future<void> Function(String assessmentId)? _onPassed;
  Timer? _timer;
  AssessmentSubmission? _pendingSubmission;
  Future<void>? _loadInFlight;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> load() {
    if (_loadInFlight case final active?) return active;
    final operation = _load();
    _loadInFlight = operation;
    return operation.whenComplete(() => _loadInFlight = null);
  }

  Future<void> _load() async {
    if (!mounted || state.isTaking || state.isSubmitting) return;
    state = state.copyWith(status: AssessmentLifecycle.loading);
    try {
      final assessment = await _repository.fetchAssessment(_assessmentId);
      final summary = await _repository.fetchAttemptSummary(
        _assessmentId,
        learnerId: _learnerId,
      );
      if (!mounted) return;
      state = state.copyWith(
        status: AssessmentLifecycle.intro,
        assessment: assessment,
        attemptSummary: summary,
      );
    } on AssessmentDataException catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        status: AssessmentLifecycle.error,
        failure: UnexpectedFailure(
          code: e.kind.name,
          message: e.message,
          cause: e,
        ),
      );
    } on Object catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        status: AssessmentLifecycle.error,
        failure: UnexpectedFailure(
          code: 'assessment_load_error',
          message: 'Unable to load assessment.',
          cause: e,
        ),
      );
    }
  }

  Future<void> startAssessment() async {
    final assessment = state.assessment;
    if (!mounted ||
        assessment == null ||
        state.status == AssessmentLifecycle.starting ||
        state.isTaking ||
        state.isSubmitting ||
        _pendingSubmission != null && !state.isCompleted) {
      return;
    }

    final summary = state.attemptSummary;
    if (summary != null && !summary.canAttempt) {
      return;
    }

    state = state.copyWith(status: AssessmentLifecycle.starting);
    try {
      final session = await _repository.startAttempt(
        _assessmentId,
        learnerId: _learnerId,
      );
      if (!mounted) return;
      _pendingSubmission = null;
      final receivedAt = DateTime.now().toUtc();
      final serverClockOffset = session.serverNow.difference(receivedAt);

      final initialAnswers = <String, QuestionAnswer>{};
      for (final q in assessment.questions) {
        switch (q) {
          case SingleChoiceQuestion():
            initialAnswers[q.id] = SingleChoiceAnswer(
              questionId: q.id,
              selectedOptionId: null,
            );
          case MultipleChoiceQuestion():
            initialAnswers[q.id] = MultipleChoiceAnswer(
              questionId: q.id,
              selectedOptionIds: const {},
            );
          case TrueFalseQuestion():
            initialAnswers[q.id] = TrueFalseAnswer(
              questionId: q.id,
              selectedValue: null,
            );
          case TextResponseQuestion():
            initialAnswers[q.id] = TextResponseAnswer(
              questionId: q.id,
              textContent: '',
            );
        }
      }

      state = state.copyWith(
        status: AssessmentLifecycle.taking,
        currentQuestionIndex: 0,
        answers: initialAnswers,
        markedForReview: const {},
        timeRemaining: session.expiresAt == null
            ? null
            : _remainingUntil(session.expiresAt!, serverClockOffset),
        attemptId: session.attemptId,
        idempotencyKey: 'submit-${session.attemptId}',
        startedAt: session.startedAt,
        expiresAt: session.expiresAt,
        serverClockOffset: serverClockOffset,
        result: null,
      );

      _startTimerIfNeeded();
    } on Object catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        status: AssessmentLifecycle.error,
        failure: UnexpectedFailure(
          code: 'assessment_start_error',
          message: 'Unable to start assessment.',
          cause: e,
        ),
      );
    }
  }

  Duration _remainingUntil(DateTime expiresAt, Duration serverClockOffset) {
    final serverNow = DateTime.now().toUtc().add(serverClockOffset);
    final remaining = expiresAt.difference(serverNow);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  void _startTimerIfNeeded() {
    _timer?.cancel();
    if (state.assessment?.isTimed ?? false) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        final remaining = state.expiresAt == null
            ? state.timeRemaining
            : _remainingUntil(state.expiresAt!, state.serverClockOffset);
        if (remaining == null) return;
        if (remaining <= Duration.zero) {
          _timer?.cancel();
          state = state.copyWith(timeRemaining: Duration.zero);
          unawaited(submit());
        } else {
          state = state.copyWith(timeRemaining: remaining);
        }
      });
    }
  }

  void resynchronizeTimer() {
    final expiresAt = state.expiresAt;
    if (!state.isTaking || expiresAt == null) return;
    final remaining = _remainingUntil(expiresAt, state.serverClockOffset);
    state = state.copyWith(timeRemaining: remaining);
    if (remaining == Duration.zero) unawaited(submit());
  }

  void selectSingleChoice(String questionId, String optionId) {
    if (!state.isTaking) return;
    final updated = Map<String, QuestionAnswer>.from(state.answers);
    updated[questionId] = SingleChoiceAnswer(
      questionId: questionId,
      selectedOptionId: optionId,
    );
    state = state.copyWith(answers: updated);
  }

  void toggleMultipleChoice(String questionId, String optionId) {
    if (!state.isTaking) return;
    final updated = Map<String, QuestionAnswer>.from(state.answers);
    final current = updated[questionId];
    final currentSet = current is MultipleChoiceAnswer
        ? Set<String>.from(current.selectedOptionIds)
        : <String>{};

    if (currentSet.contains(optionId)) {
      currentSet.remove(optionId);
    } else {
      currentSet.add(optionId);
    }

    updated[questionId] = MultipleChoiceAnswer(
      questionId: questionId,
      selectedOptionIds: currentSet,
    );
    state = state.copyWith(answers: updated);
  }

  void setTrueFalse(String questionId, bool value) {
    if (!state.isTaking) return;
    final updated = Map<String, QuestionAnswer>.from(state.answers);
    updated[questionId] = TrueFalseAnswer(
      questionId: questionId,
      selectedValue: value,
    );
    state = state.copyWith(answers: updated);
  }

  void setTextResponse(String questionId, String text) {
    if (!state.isTaking) return;
    final updated = Map<String, QuestionAnswer>.from(state.answers);
    updated[questionId] = TextResponseAnswer(
      questionId: questionId,
      textContent: text,
    );
    state = state.copyWith(answers: updated);
  }

  void toggleMarkForReview(String questionId) {
    if (!mounted || !state.isTaking) return;
    final marked = Set<String>.from(state.markedForReview);
    if (marked.contains(questionId)) {
      marked.remove(questionId);
    } else {
      marked.add(questionId);
    }
    state = state.copyWith(markedForReview: marked);
  }

  void goToQuestion(int index) {
    if (!mounted || !state.isTaking) return;
    if (state.assessment == null) return;
    if (index >= 0 && index < state.assessment!.questions.length) {
      state = state.copyWith(currentQuestionIndex: index);
    }
  }

  void nextQuestion() {
    if (!mounted || !state.isTaking) return;
    if (state.assessment == null) return;
    if (state.currentQuestionIndex + 1 < state.assessment!.questions.length) {
      state = state.copyWith(
        currentQuestionIndex: state.currentQuestionIndex + 1,
      );
    }
  }

  void previousQuestion() {
    if (!mounted || !state.isTaking) return;
    if (state.currentQuestionIndex > 0) {
      state = state.copyWith(
        currentQuestionIndex: state.currentQuestionIndex - 1,
      );
    }
  }

  Future<void> retry() => _pendingSubmission != null ? submit() : load();

  Future<void> submit() async {
    if (!mounted ||
        state.isSubmitting ||
        state.isCompleted ||
        state.attemptId == null ||
        (!state.isTaking && _pendingSubmission == null)) {
      return;
    }
    _timer?.cancel();
    final submittedAt = DateTime.now().toUtc();
    // Retry exactly the same immutable payload, including its original timestamp.
    _pendingSubmission ??= AssessmentSubmission(
      assessmentId: _assessmentId,
      attemptId: state.attemptId!,
      durationTaken: submittedAt.difference(state.startedAt ?? submittedAt),
      answers: Map.unmodifiable(state.answers),
      idempotencyKey: state.idempotencyKey!,
      submittedAt: submittedAt,
    );
    state = state.copyWith(status: AssessmentLifecycle.submitting);
    try {
      final result = await _repository.submitAssessment(
        _pendingSubmission!,
        learnerId: _learnerId,
      );
      if (!mounted) return;
      state = state.copyWith(
        status: AssessmentLifecycle.completed,
        result: result,
      );
      // Secondary refreshes must never turn an accepted result into a failed submission.
      try {
        final summary = await _repository.fetchAttemptSummary(
          _assessmentId,
          learnerId: _learnerId,
        );
        if (mounted) state = state.copyWith(attemptSummary: summary);
      } on Object {
        /* Keep the accepted result. */
      }
      if (result.isPassed && _onPassed != null) {
        try {
          await _onPassed(_assessmentId);
        } on Object {
          /* Reconcile later. */
        }
      }
    } on Object catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        status: AssessmentLifecycle.error,
        failure: UnexpectedFailure(
          code: 'assessment_submission_error',
          message:
              'Your answers are saved for this session. Reconnect and try sending them again.',
          cause: e,
        ),
      );
    }
  }

  Future<void> retake() async {
    final summary = state.attemptSummary;
    if (summary != null && summary.canAttempt) {
      await startAssessment();
    }
  }
}
