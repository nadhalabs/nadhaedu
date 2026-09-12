import 'package:learning_platform/features/assessments/domain/assessment.dart';
import 'package:learning_platform/features/assessments/domain/assessment_attempt.dart';
import 'package:learning_platform/features/assessments/domain/assessment_result.dart';
import 'package:learning_platform/features/assessments/domain/assessment_session.dart';
import 'package:learning_platform/features/assessments/domain/assessment_submission.dart';

abstract interface class AssessmentRepository {
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
