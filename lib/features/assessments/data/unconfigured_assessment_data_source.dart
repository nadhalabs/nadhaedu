import 'package:learning_platform/features/assessments/data/assessment_data_source.dart';
import 'package:learning_platform/features/assessments/domain/assessment.dart';
import 'package:learning_platform/features/assessments/domain/assessment_attempt.dart';
import 'package:learning_platform/features/assessments/domain/assessment_result.dart';
import 'package:learning_platform/features/assessments/domain/assessment_session.dart';
import 'package:learning_platform/features/assessments/domain/assessment_submission.dart';

final class UnconfiguredAssessmentDataSource implements AssessmentDataSource {
  const UnconfiguredAssessmentDataSource();

  @override
  Future<AssessmentAttemptSession> startAttempt(
    String assessmentId, {
    required String learnerId,
  }) async {
    throw const AssessmentDataException(
      AssessmentDataErrorKind.unconfigured,
      'Assessment service is not configured for this environment.',
    );
  }

  @override
  Future<Assessment> fetchAssessment(String assessmentId) async {
    throw const AssessmentDataException(
      AssessmentDataErrorKind.unconfigured,
      'Assessment service is not configured for this environment.',
    );
  }

  @override
  Future<AssessmentAttemptSummary> fetchAttemptSummary(
    String assessmentId, {
    required String learnerId,
  }) async {
    throw const AssessmentDataException(
      AssessmentDataErrorKind.unconfigured,
      'Assessment service is not configured for this environment.',
    );
  }

  @override
  Future<AssessmentResult> submitAssessment(
    AssessmentSubmission submission, {
    required String learnerId,
  }) async {
    throw const AssessmentDataException(
      AssessmentDataErrorKind.unconfigured,
      'Assessment service is not configured for this environment.',
    );
  }
}
