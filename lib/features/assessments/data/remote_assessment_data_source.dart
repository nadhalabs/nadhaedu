import 'package:learning_platform/core/errors/result.dart';
import 'package:learning_platform/core/networking/api_client.dart';
import 'package:learning_platform/features/assessments/data/assessment_data_source.dart';
import 'package:learning_platform/features/assessments/domain/assessment.dart';
import 'package:learning_platform/features/assessments/domain/assessment_attempt.dart';
import 'package:learning_platform/features/assessments/domain/assessment_question.dart';
import 'package:learning_platform/features/assessments/domain/assessment_result.dart';
import 'package:learning_platform/features/assessments/domain/assessment_session.dart';
import 'package:learning_platform/features/assessments/domain/assessment_submission.dart';

final class RemoteAssessmentDataSource implements AssessmentDataSource {
  const RemoteAssessmentDataSource(this._client);

  final ApiClient _client;

  String _assessmentPath(String id) =>
      '/api/v1/assessments/${Uri.encodeComponent(id)}';

  @override
  Future<Assessment> fetchAssessment(String assessmentId) async =>
      _decodeAssessment(await _get(_assessmentPath(assessmentId)));

  @override
  Future<AssessmentAttemptSummary> fetchAttemptSummary(
    String assessmentId, {
    required String learnerId,
  }) async => _decodeAttemptSummary(
    await _get('${_assessmentPath(assessmentId)}/attempts/summary'),
  );

  @override
  Future<AssessmentAttemptSession> startAttempt(
    String assessmentId, {
    required String learnerId,
  }) async => _decodeAttemptSession(
    await _post('${_assessmentPath(assessmentId)}/attempts'),
  );

  @override
  Future<AssessmentResult> submitAssessment(
    AssessmentSubmission submission, {
    required String learnerId,
  }) async => _decodeResult(
    await _post(
      '${_assessmentPath(submission.assessmentId)}/attempts/${Uri.encodeComponent(submission.attemptId)}/submission',
      body: _submissionToJson(submission),
      headers: {'Idempotency-Key': submission.idempotencyKey},
    ),
  );

  Future<Map<String, Object?>> _get(String path) async {
    return switch (await _client.get(path)) {
      Success(value: final value) => value,
      Failure(failure: final failure) => throw AssessmentDataException(
        AssessmentDataErrorKind.network,
        failure.message,
      ),
    };
  }

  Future<Map<String, Object?>> _post(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, Object?> headers = const {},
  }) async {
    return switch (await _client.post(path, body: body, headers: headers)) {
      Success(value: final value) => value,
      Failure(failure: final failure) => throw AssessmentDataException(
        AssessmentDataErrorKind.network,
        failure.message,
      ),
    };
  }
}

Assessment _decodeAssessment(Map<String, Object?> json) {
  final summaryJson = _map(json, 'summary');
  final questions = _list(json, 'questions')
      .map((value) => _decodeQuestion(value as Map<String, Object?>))
      .toList(growable: false);
  return Assessment(
    summary: AssessmentSummary(
      id: _string(summaryJson, 'id'),
      courseId: _string(summaryJson, 'courseId'),
      title: _string(summaryJson, 'title'),
      description: _string(summaryJson, 'description'),
      questionCount: _integer(summaryJson, 'questionCount'),
      passingScorePercentage: _integer(summaryJson, 'passingScorePercentage'),
      timeLimit: summaryJson['timeLimitSeconds'] == null
          ? null
          : Duration(seconds: _integer(summaryJson, 'timeLimitSeconds')),
      maxAttempts: _integer(summaryJson, 'maxAttempts'),
    ),
    questions: questions,
    instructions: _list(json, 'instructions').cast<String>(),
    updatedAt: DateTime.parse(_string(json, 'updatedAt')).toUtc(),
  );
}

Question _decodeQuestion(Map<String, Object?> json) {
  final common = (
    id: _string(json, 'id'),
    prompt: _string(json, 'prompt'),
    points: _integer(json, 'points'),
  );
  final options = (json['options'] as List<Object?>? ?? const [])
      .map((value) => value! as Map<String, Object?>)
      .map(
        (value) => QuestionOption(
          id: _string(value, 'id'),
          text: _string(value, 'text'),
          hint: value['hint'] as String?,
        ),
      )
      .toList(growable: false);
  return switch (_string(json, 'type')) {
    'singleChoice' => SingleChoiceQuestion(
      id: common.id,
      prompt: common.prompt,
      points: common.points,
      options: options,
    ),
    'multipleChoice' => MultipleChoiceQuestion(
      id: common.id,
      prompt: common.prompt,
      points: common.points,
      options: options,
      minSelections: (json['minSelections'] as int?) ?? 1,
      maxSelections: json['maxSelections'] as int?,
    ),
    'trueFalse' => TrueFalseQuestion(
      id: common.id,
      prompt: common.prompt,
      points: common.points,
    ),
    'textResponse' => TextResponseQuestion(
      id: common.id,
      prompt: common.prompt,
      points: common.points,
      placeholder:
          (json['placeholder'] as String?) ?? 'Type your response here...',
      minWords: (json['minWords'] as int?) ?? 1,
      maxWords: (json['maxWords'] as int?) ?? 500,
    ),
    final type => throw FormatException('Unsupported question type: $type'),
  };
}

AssessmentAttemptSession _decodeAttemptSession(Map<String, Object?> json) =>
    AssessmentAttemptSession(
      attemptId: _string(json, 'attemptId'),
      assessmentId: _string(json, 'assessmentId'),
      startedAt: DateTime.parse(_string(json, 'startedAt')).toUtc(),
      serverNow: DateTime.parse(_string(json, 'serverNow')).toUtc(),
      expiresAt: json['expiresAt'] == null
          ? null
          : DateTime.parse(json['expiresAt']! as String).toUtc(),
      attemptNumber: _integer(json, 'attemptNumber'),
    );

AssessmentAttemptSummary _decodeAttemptSummary(Map<String, Object?> json) =>
    AssessmentAttemptSummary(
      assessmentId: _string(json, 'assessmentId'),
      totalAttempts: _integer(json, 'totalAttempts'),
      maxAttempts: _integer(json, 'maxAttempts'),
      remainingAttempts: _integer(json, 'remainingAttempts'),
      hasPassed: _boolean(json, 'hasPassed'),
      highestScore: _integer(json, 'highestScore'),
      highestPercentage: _number(json, 'highestPercentage'),
      attempts: _list(json, 'attempts')
          .map((value) => value! as Map<String, Object?>)
          .map(_decodeAttempt)
          .toList(growable: false),
    );

AssessmentAttempt _decodeAttempt(Map<String, Object?> json) =>
    AssessmentAttempt(
      attemptId: _string(json, 'attemptId'),
      assessmentId: _string(json, 'assessmentId'),
      learnerId: _string(json, 'learnerId'),
      attemptNumber: _integer(json, 'attemptNumber'),
      score: _integer(json, 'score'),
      maxScore: _integer(json, 'maxScore'),
      percentage: _number(json, 'percentage'),
      isPassed: _boolean(json, 'isPassed'),
      startedAt: DateTime.parse(_string(json, 'startedAt')).toUtc(),
      submittedAt: DateTime.parse(_string(json, 'submittedAt')).toUtc(),
      duration: Duration(seconds: _integer(json, 'durationSeconds')),
    );

AssessmentResult _decodeResult(Map<String, Object?> json) => AssessmentResult(
  assessmentId: _string(json, 'assessmentId'),
  attemptId: _string(json, 'attemptId'),
  earnedScore: _integer(json, 'earnedScore'),
  maxScore: _integer(json, 'maxScore'),
  percentage: _number(json, 'percentage'),
  isPassed: _boolean(json, 'isPassed'),
  passingPercentage: _integer(json, 'passingPercentage'),
  durationTaken: Duration(seconds: _integer(json, 'durationSeconds')),
  submittedAt: DateTime.parse(_string(json, 'submittedAt')).toUtc(),
  questionResults: _list(json, 'questionResults')
      .map((value) => value! as Map<String, Object?>)
      .map(
        (value) => QuestionResult(
          questionId: _string(value, 'questionId'),
          isCorrect: _boolean(value, 'isCorrect'),
          earnedPoints: _integer(value, 'earnedPoints'),
          maxPoints: _integer(value, 'maxPoints'),
          explanation: value['explanation'] as String?,
          feedback: value['feedback'] as String?,
        ),
      )
      .toList(growable: false),
  feedbackSummary: _string(json, 'feedbackSummary'),
);

Map<String, Object?> _submissionToJson(AssessmentSubmission value) => {
  'attemptId': value.attemptId,
  'answers': [for (final answer in value.answers.values) _answerToJson(answer)],
};

Map<String, Object?> _answerToJson(QuestionAnswer answer) => switch (answer) {
  SingleChoiceAnswer() => {
    'questionId': answer.questionId,
    'type': 'singleChoice',
    'selectedOptionId': answer.selectedOptionId,
  },
  MultipleChoiceAnswer() => {
    'questionId': answer.questionId,
    'type': 'multipleChoice',
    'selectedOptionIds': answer.selectedOptionIds.toList(growable: false),
  },
  TrueFalseAnswer() => {
    'questionId': answer.questionId,
    'type': 'trueFalse',
    'selectedValue': answer.selectedValue,
  },
  TextResponseAnswer() => {
    'questionId': answer.questionId,
    'type': 'textResponse',
    'textContent': answer.textContent,
  },
};

Map<String, Object?> _map(Map<String, Object?> json, String key) =>
    json[key]! as Map<String, Object?>;
List<Object?> _list(Map<String, Object?> json, String key) =>
    json[key]! as List<Object?>;
String _string(Map<String, Object?> json, String key) => json[key]! as String;
int _integer(Map<String, Object?> json, String key) => json[key]! as int;
double _number(Map<String, Object?> json, String key) =>
    (json[key]! as num).toDouble();
bool _boolean(Map<String, Object?> json, String key) => json[key]! as bool;
