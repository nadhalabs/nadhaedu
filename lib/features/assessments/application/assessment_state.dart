import 'package:learning_platform/core/errors/app_failure.dart';
import 'package:learning_platform/features/assessments/domain/assessment.dart';
import 'package:learning_platform/features/assessments/domain/assessment_attempt.dart';
import 'package:learning_platform/features/assessments/domain/assessment_question.dart';
import 'package:learning_platform/features/assessments/domain/assessment_result.dart';
import 'package:learning_platform/features/assessments/domain/assessment_submission.dart';

enum AssessmentLifecycle {
  loading,
  intro,
  starting,
  taking,
  submitting,
  completed,
  error,
}

final class AssessmentSessionState {
  const AssessmentSessionState({
    required this.status,
    this.assessment,
    this.attemptSummary,
    this.currentQuestionIndex = 0,
    this.answers = const {},
    this.markedForReview = const {},
    this.timeRemaining,
    this.result,
    this.failure,
    this.attemptId,
    this.idempotencyKey,
    this.startedAt,
    this.expiresAt,
    this.serverClockOffset = Duration.zero,
  });

  factory AssessmentSessionState.initial() =>
      const AssessmentSessionState(status: AssessmentLifecycle.loading);

  final AssessmentLifecycle status;
  final Assessment? assessment;
  final AssessmentAttemptSummary? attemptSummary;
  final int currentQuestionIndex;
  final Map<String, QuestionAnswer> answers;
  final Set<String> markedForReview;
  final Duration? timeRemaining;
  final AssessmentResult? result;
  final AppFailure? failure;
  final String? attemptId;
  final String? idempotencyKey;
  final DateTime? startedAt;
  final DateTime? expiresAt;
  final Duration serverClockOffset;

  bool get isLoading => status == AssessmentLifecycle.loading;
  bool get isIntro => status == AssessmentLifecycle.intro;
  bool get isTaking => status == AssessmentLifecycle.taking;
  bool get isSubmitting => status == AssessmentLifecycle.submitting;
  bool get isCompleted => status == AssessmentLifecycle.completed;
  bool get isError => status == AssessmentLifecycle.error;

  int get totalQuestions => assessment?.questions.length ?? 0;
  Question? get currentQuestion =>
      assessment != null &&
          currentQuestionIndex >= 0 &&
          currentQuestionIndex < assessment!.questions.length
      ? assessment!.questions[currentQuestionIndex]
      : null;

  bool get isFirstQuestion => currentQuestionIndex == 0;
  bool get isLastQuestion =>
      assessment != null &&
      currentQuestionIndex == assessment!.questions.length - 1;

  int get answeredCount =>
      answers.values.where((answer) => answer.isAnswered).length;

  bool isQuestionAnswered(String questionId) =>
      answers[questionId]?.isAnswered ?? false;

  bool isQuestionMarked(String questionId) =>
      markedForReview.contains(questionId);

  AssessmentSessionState copyWith({
    AssessmentLifecycle? status,
    Assessment? assessment,
    AssessmentAttemptSummary? attemptSummary,
    int? currentQuestionIndex,
    Map<String, QuestionAnswer>? answers,
    Set<String>? markedForReview,
    Duration? timeRemaining,
    AssessmentResult? result,
    AppFailure? failure,
    String? attemptId,
    String? idempotencyKey,
    DateTime? startedAt,
    DateTime? expiresAt,
    Duration? serverClockOffset,
  }) => AssessmentSessionState(
    status: status ?? this.status,
    assessment: assessment ?? this.assessment,
    attemptSummary: attemptSummary ?? this.attemptSummary,
    currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
    answers: answers ?? this.answers,
    markedForReview: markedForReview ?? this.markedForReview,
    timeRemaining: timeRemaining ?? this.timeRemaining,
    result: result ?? this.result,
    failure: failure ?? this.failure,
    attemptId: attemptId ?? this.attemptId,
    idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    startedAt: startedAt ?? this.startedAt,
    expiresAt: expiresAt ?? this.expiresAt,
    serverClockOffset: serverClockOffset ?? this.serverClockOffset,
  );
}
