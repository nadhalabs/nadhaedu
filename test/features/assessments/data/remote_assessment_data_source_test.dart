import 'package:flutter_test/flutter_test.dart';
import 'package:learning_platform/core/errors/result.dart';
import 'package:learning_platform/core/networking/api_client.dart';
import 'package:learning_platform/features/assessments/data/remote_assessment_data_source.dart';
import 'package:learning_platform/features/assessments/domain/assessment_submission.dart';

void main() {
  test(
    'starts a server attempt and submits with an idempotency header',
    () async {
      final client = _RecordingApiClient();
      final source = RemoteAssessmentDataSource(client);

      final session = await source.startAttempt(
        'assessment/unsafe id',
        learnerId: 'learner-1',
      );
      expect(session.attemptId, 'attempt-1');
      expect(
        client.lastPath,
        '/api/v1/assessments/assessment%2Funsafe%20id/attempts',
      );

      final result = await source.submitAssessment(
        AssessmentSubmission(
          assessmentId: 'assessment/unsafe id',
          attemptId: session.attemptId,
          durationTaken: const Duration(seconds: 2),
          answers: const {
            'q1': SingleChoiceAnswer(
              questionId: 'q1',
              selectedOptionId: 'option-2',
            ),
          },
          idempotencyKey: 'stable-key',
          submittedAt: DateTime.utc(2026),
        ),
        learnerId: 'learner-1',
      );

      expect(result.isPassed, isTrue);
      expect(client.lastHeaders, {'Idempotency-Key': 'stable-key'});
      expect(client.lastBody?['attemptId'], 'attempt-1');
      expect(client.lastBody, isNot(contains('learnerId')));
    },
  );
}

final class _RecordingApiClient implements ApiClient {
  String? lastPath;
  Map<String, Object?>? lastBody;
  Map<String, Object?>? lastHeaders;

  @override
  Future<Result<Map<String, Object?>>> get(
    String path, {
    Map<String, Object?> query = const {},
    bool authenticated = true,
  }) async => throw UnimplementedError();

  @override
  Future<Result<Map<String, Object?>>> post(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, Object?> headers = const {},
    bool authenticated = true,
  }) async {
    lastPath = path;
    lastBody = body;
    lastHeaders = headers;
    if (path.endsWith('/attempts')) {
      return Success({
        'attemptId': 'attempt-1',
        'assessmentId': 'assessment/unsafe id',
        'startedAt': '2026-01-01T00:00:00Z',
        'serverNow': '2026-01-01T00:00:00Z',
        'expiresAt': '2026-01-01T00:10:00Z',
        'attemptNumber': 1,
      });
    }
    return Success({
      'assessmentId': 'assessment/unsafe id',
      'attemptId': 'attempt-1',
      'earnedScore': 1,
      'maxScore': 1,
      'percentage': 100,
      'isPassed': true,
      'passingPercentage': 70,
      'durationSeconds': 2,
      'submittedAt': '2026-01-01T00:00:02Z',
      'questionResults': <Object?>[],
      'feedbackSummary': 'Passed',
    });
  }

  @override
  Future<Result<Map<String, Object?>>> put(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, Object?> headers = const {},
    bool authenticated = true,
  }) async => throw UnimplementedError();

  @override
  Future<Result<Map<String, Object?>>> delete(
    String path, {
    Map<String, Object?> query = const {},
    Map<String, Object?> headers = const {},
    bool authenticated = true,
  }) async => throw UnimplementedError();
}
