final class QuestionResult {
  const QuestionResult({
    required this.questionId,
    required this.isCorrect,
    required this.earnedPoints,
    required this.maxPoints,
    this.correctOptionIds,
    this.correctBooleanValue,
    this.explanation,
    this.feedback,
  });

  final String questionId;
  final bool isCorrect;
  final int earnedPoints;
  final int maxPoints;
  final Set<String>? correctOptionIds;
  final bool? correctBooleanValue;
  final String? explanation;
  final String? feedback;
}

final class AssessmentResult {
  const AssessmentResult({
    required this.assessmentId,
    required this.attemptId,
    required this.earnedScore,
    required this.maxScore,
    required this.percentage,
    required this.isPassed,
    required this.passingPercentage,
    required this.durationTaken,
    required this.submittedAt,
    required this.questionResults,
    required this.feedbackSummary,
  });

  final String assessmentId;
  final String attemptId;
  final int earnedScore;
  final int maxScore;
  final double percentage;
  final bool isPassed;
  final int passingPercentage;
  final Duration durationTaken;
  final DateTime submittedAt;
  final List<QuestionResult> questionResults;
  final String feedbackSummary;

  int get correctCount =>
      questionResults.where((result) => result.isCorrect).length;
  int get totalCount => questionResults.length;
}
