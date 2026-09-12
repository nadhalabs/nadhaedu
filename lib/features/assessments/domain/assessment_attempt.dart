final class AssessmentAttempt {
  const AssessmentAttempt({
    required this.attemptId,
    required this.assessmentId,
    required this.learnerId,
    required this.attemptNumber,
    required this.score,
    required this.maxScore,
    required this.percentage,
    required this.isPassed,
    required this.startedAt,
    required this.submittedAt,
    required this.duration,
  });

  final String attemptId;
  final String assessmentId;
  final String learnerId;
  final int attemptNumber;
  final int score;
  final int maxScore;
  final double percentage;
  final bool isPassed;
  final DateTime startedAt;
  final DateTime submittedAt;
  final Duration duration;
}

final class AssessmentAttemptSummary {
  const AssessmentAttemptSummary({
    required this.assessmentId,
    required this.totalAttempts,
    required this.maxAttempts,
    required this.remainingAttempts,
    required this.hasPassed,
    required this.highestScore,
    required this.highestPercentage,
    required this.attempts,
  });

  factory AssessmentAttemptSummary.empty(
    String assessmentId, {
    int maxAttempts = 3,
  }) => AssessmentAttemptSummary(
    assessmentId: assessmentId,
    totalAttempts: 0,
    maxAttempts: maxAttempts,
    remainingAttempts: maxAttempts,
    hasPassed: false,
    highestScore: 0,
    highestPercentage: 0,
    attempts: const [],
  );

  final String assessmentId;
  final int totalAttempts;
  final int maxAttempts;
  final int remainingAttempts;
  final bool hasPassed;
  final int highestScore;
  final double highestPercentage;
  final List<AssessmentAttempt> attempts;

  bool get canAttempt => remainingAttempts > 0;
  AssessmentAttempt? get latestAttempt =>
      attempts.isEmpty ? null : attempts.last;
}
