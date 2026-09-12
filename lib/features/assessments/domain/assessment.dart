import 'package:learning_platform/features/assessments/domain/assessment_question.dart';

final class AssessmentSummary {
  const AssessmentSummary({
    required this.id,
    required this.courseId,
    required this.title,
    required this.description,
    required this.questionCount,
    required this.passingScorePercentage,
    this.timeLimit,
    this.maxAttempts = 3,
  });

  final String id;
  final String courseId;
  final String title;
  final String description;
  final int questionCount;
  final int passingScorePercentage;
  final Duration? timeLimit;
  final int maxAttempts;

  bool get isTimed => timeLimit != null && timeLimit! > Duration.zero;
}

final class Assessment {
  const Assessment({
    required this.summary,
    required this.questions,
    required this.instructions,
    required this.updatedAt,
  });

  final AssessmentSummary summary;
  final List<Question> questions;
  final List<String> instructions;
  final DateTime updatedAt;

  String get id => summary.id;
  String get courseId => summary.courseId;
  String get title => summary.title;
  String get description => summary.description;
  int get questionCount => questions.length;
  int get passingScorePercentage => summary.passingScorePercentage;
  Duration? get timeLimit => summary.timeLimit;
  int get maxAttempts => summary.maxAttempts;
  bool get isTimed => summary.isTimed;

  int get totalPoints => questions.fold(0, (sum, q) => sum + q.points);
}
