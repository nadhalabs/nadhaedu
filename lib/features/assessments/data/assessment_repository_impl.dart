import 'package:learning_platform/features/assessments/data/assessment_data_source.dart';
import 'package:learning_platform/features/assessments/domain/assessment.dart';
import 'package:learning_platform/features/assessments/domain/assessment_attempt.dart';
import 'package:learning_platform/features/assessments/domain/assessment_repository.dart';
import 'package:learning_platform/features/assessments/domain/assessment_result.dart';
import 'package:learning_platform/features/assessments/domain/assessment_session.dart';
import 'package:learning_platform/features/assessments/domain/assessment_submission.dart';

final class AssessmentRepositoryImpl implements AssessmentRepository {
  AssessmentRepositoryImpl({required AssessmentDataSource dataSource})
    : _dataSource = dataSource;

  final AssessmentDataSource _dataSource;
  final Map<String, Assessment> _assessmentCache = {};

  @override
  Future<Assessment> fetchAssessment(String assessmentId) async {
    if (_assessmentCache.containsKey(assessmentId)) {
      return _assessmentCache[assessmentId]!;
    }
    final assessment = await _dataSource.fetchAssessment(assessmentId);
    _assessmentCache[assessmentId] = assessment;
    return assessment;
  }

  @override
  Future<AssessmentAttemptSummary> fetchAttemptSummary(
    String assessmentId, {
    required String learnerId,
  }) {
    return _dataSource.fetchAttemptSummary(assessmentId, learnerId: learnerId);
  }

  @override
  Future<AssessmentAttemptSession> startAttempt(
    String assessmentId, {
    required String learnerId,
  }) => _dataSource.startAttempt(assessmentId, learnerId: learnerId);

  @override
  Future<AssessmentResult> submitAssessment(
    AssessmentSubmission submission, {
    required String learnerId,
  }) {
    return _dataSource.submitAssessment(submission, learnerId: learnerId);
  }
}
