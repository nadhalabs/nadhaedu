import 'package:learning_platform/features/assessments/domain/assessment.dart';
import 'package:learning_platform/features/assessments/domain/assessment_attempt.dart';
import 'package:learning_platform/features/assessments/domain/assessment_result.dart';
import 'package:learning_platform/features/assessments/domain/assessment_session.dart';
import 'package:learning_platform/features/assessments/domain/assessment_submission.dart';

enum AssessmentDataErrorKind {
  notFound,
  attemptLimitExceeded,
  unconfigured,
  network,
  evaluationFailed,
  unauthenticated,
  forbidden,
  attemptExpired,
  conflict,
}

final class AssessmentDataException implements Exception {
  const AssessmentDataException(this.kind, this.message);
  final AssessmentDataErrorKind kind;
  final String message;

  @override
  String toString() => 'AssessmentDataException($kind, $message)';
}

abstract interface class AssessmentDataSource {
  Future<Assessment> fetchAssessment(String assessmentId);

  Future<AssessmentAttemptSummary> fetchAttemptSummary(
    String assessmentId, {
    required String learnerId,
  });

  Future<AssessmentAttemptSession> startAttempt(
    String assessmentId, {
    required String learnerId,
  });

  Future<AssessmentResult> submitAssessment(
    AssessmentSubmission submission, {
    required String learnerId,
  });
}
