import 'package:learning_platform/features/assessments/data/assessment_data_source.dart';
import 'package:learning_platform/features/assessments/domain/assessment.dart';
import 'package:learning_platform/features/assessments/domain/assessment_attempt.dart';
import 'package:learning_platform/features/assessments/domain/assessment_question.dart';
import 'package:learning_platform/features/assessments/domain/assessment_result.dart';
import 'package:learning_platform/features/assessments/domain/assessment_session.dart';
import 'package:learning_platform/features/assessments/domain/assessment_submission.dart';

final class FoundationAssessmentDataSource implements AssessmentDataSource {
  FoundationAssessmentDataSource({DateTime Function()? clock})
    : _clock = clock ?? _utcNow {
    _seedAssessments();
  }

  final DateTime Function() _clock;

  final Map<String, Assessment> _assessments = {};
  final Map<String, Map<String, _ServerQuestionRubric>> _rubrics = {};
  final Map<String, List<AssessmentAttempt>> _attemptsByLearnerAssessment = {};
  final Map<String, AssessmentResult> _submissionIdempotencyStore = {};
  final Map<String, _DevelopmentAttemptSession> _activeAttempts = {};
  final Map<String, AssessmentResult> _resultsByAttemptId = {};

  void _seedAssessments() {
    // Assessment 1: Comprehensive Foundations Assessment
    const q1Id = 'q-foundations-1';
    const q2Id = 'q-foundations-2';
    const q3Id = 'q-foundations-3';
    const q4Id = 'q-foundations-4';

    final foundationsAssessment = Assessment(
      summary: const AssessmentSummary(
        id: 'quiz-foundations-1',
        courseId: 'course-1',
        title: 'Foundations & Architecture Knowledge Check',
        description:
            'Test your comprehension of clean architecture, separation of concerns, and unidirectional data flow.',
        questionCount: 4,
        passingScorePercentage: 75,
        timeLimit: Duration(minutes: 10),
        maxAttempts: 3,
      ),
      questions: const [
        SingleChoiceQuestion(
          id: q1Id,
          prompt:
              'In clean architecture, which layer is responsible for pure business rules and domain entities with no framework dependencies?',
          options: [
            QuestionOption(
              id: 'opt-1',
              text: 'Presentation Layer',
              hint: 'Handles UI widgets',
            ),
            QuestionOption(
              id: 'opt-2',
              text: 'Domain Layer',
              hint: 'Core business models and contracts',
            ),
            QuestionOption(
              id: 'opt-3',
              text: 'Data Layer',
              hint: 'APIs and persistence',
            ),
            QuestionOption(
              id: 'opt-4',
              text: 'Application Layer',
              hint: 'Use-case state orchestration',
            ),
          ],
          points: 1,
        ),
        MultipleChoiceQuestion(
          id: q2Id,
          prompt:
              'Which of the following are characteristics of server-authoritative assessment architecture? (Select all that apply)',
          options: [
            QuestionOption(
              id: 'opt-2a',
              text:
                  'Answer keys are never transmitted to the client application',
            ),
            QuestionOption(
              id: 'opt-2b',
              text: 'Client widgets perform final grading before sync',
            ),
            QuestionOption(
              id: 'opt-2c',
              text:
                  'Submissions include idempotency tokens to prevent duplicate scoring',
            ),
            QuestionOption(
              id: 'opt-2d',
              text:
                  'Attempt limits and duration limits are enforced server-side',
            ),
          ],
          minSelections: 1,
          points: 2,
        ),
        TrueFalseQuestion(
          id: q3Id,
          prompt:
              'A certificate should be automatically generated on the client as soon as local progress indicates 100%.',
          points: 1,
        ),
        TextResponseQuestion(
          id: q4Id,
          prompt:
              'Explain why access evaluation should be centralized rather than checking entitlements directly in UI widgets.',
          placeholder:
              'Discuss maintainability, security, and consistent policy evaluation...',
          minWords: 3,
          points: 2,
        ),
      ],
      instructions: const [
        'Read each question carefully before submitting your answer.',
        'You have a 10-minute time limit for this assessment.',
        'A passing score of 75% or higher is required.',
        'You have up to 3 attempts to pass.',
      ],
      updatedAt: DateTime.utc(2026, 1, 1),
    );

    _registerAssessment(
      foundationsAssessment,
      rubric: {
        q1Id: const _ServerQuestionRubric(
          questionId: q1Id,
          correctOptionIds: {'opt-2'},
          explanation:
              'The domain layer defines pure business models and contracts with no Flutter or external library dependencies.',
        ),
        q2Id: const _ServerQuestionRubric(
          questionId: q2Id,
          correctOptionIds: {'opt-2a', 'opt-2c', 'opt-2d'},
          explanation:
              'Server-authoritative architecture ensures answer keys remain hidden, submissions are idempotent, and attempt limits are enforced by backend services.',
        ),
        q3Id: const _ServerQuestionRubric(
          questionId: q3Id,
          correctBooleanValue: false,
          explanation:
              'Certificate eligibility must remain server-authoritative to verify identity, assessment pass records, and entitlement policies before issuing a verifiable credential.',
        ),
        q4Id: const _ServerQuestionRubric(
          questionId: q4Id,
          requiredKeywords: [
            'maintain',
            'secur',
            'policy',
            'consist',
            'rule',
            'logic',
            'central',
          ],
          explanation:
              'Centralizing access evaluation eliminates duplicate entitlement logic in widgets, enforces consistent policy hierarchy, and protects against unauthorized access.',
        ),
      },
    );
  }

  void _registerAssessment(
    Assessment assessment, {
    required Map<String, _ServerQuestionRubric> rubric,
  }) {
    _assessments[assessment.id] = assessment;
    _rubrics[assessment.id] = rubric;
  }

  Assessment _getOrCreateDynamicAssessment(String assessmentId) {
    if (_assessments.containsKey(assessmentId)) {
      return _assessments[assessmentId]!;
    }

    // Dynamic generation for any catalog quiz (e.g. quiz-0-4, quiz-1-4)
    final q1 = 'q-$assessmentId-1';
    final q2 = 'q-$assessmentId-2';
    final q3 = 'q-$assessmentId-3';
    final q4 = 'q-$assessmentId-4';

    final dynamicAssessment = Assessment(
      summary: AssessmentSummary(
        id: assessmentId,
        courseId:
            'course-${assessmentId.split('-').length > 1 ? assessmentId.split('-')[1] : '1'}',
        title: 'Module Knowledge Assessment',
        description:
            'Demonstrate your mastery of concepts covered in this module.',
        questionCount: 4,
        passingScorePercentage: 70,
        timeLimit: const Duration(minutes: 15),
        maxAttempts: 3,
      ),
      questions: [
        SingleChoiceQuestion(
          id: q1,
          prompt:
              'What is the primary benefit of immutability in state management?',
          options: const [
            QuestionOption(
              id: 'opt-a',
              text: 'Predictable state transitions and easy change detection',
            ),
            QuestionOption(id: 'opt-b', text: 'Higher memory consumption'),
            QuestionOption(id: 'opt-c', text: 'Direct in-place mutations'),
            QuestionOption(id: 'opt-d', text: 'Automatic network caching'),
          ],
          points: 1,
        ),
        MultipleChoiceQuestion(
          id: q2,
          prompt:
              'Which layers should have no direct dependency on Flutter widgets?',
          options: const [
            QuestionOption(id: 'opt-2a', text: 'Domain layer'),
            QuestionOption(
              id: 'opt-2b',
              text: 'Data layer (contracts & repositories)',
            ),
            QuestionOption(id: 'opt-2c', text: 'Presentation widget builders'),
          ],
          minSelections: 1,
          points: 2,
        ),
        TrueFalseQuestion(
          id: q3,
          prompt:
              'Unidirectional data flow simplifies debugging by making state mutations traceable.',
          points: 1,
        ),
        TextResponseQuestion(
          id: q4,
          prompt:
              'Summarize how offline-first data synchronization handles conflicts.',
          placeholder:
              'Describe server baseline revisions and local mutation replay...',
          minWords: 3,
          points: 2,
        ),
      ],
      instructions: const [
        'Answer all questions to complete the module checkpoint.',
        'Passing score is 70%.',
        'You have 15 minutes to complete this attempt.',
      ],
      updatedAt: DateTime.utc(2026, 1, 1),
    );

    _registerAssessment(
      dynamicAssessment,
      rubric: {
        q1: const _ServerQuestionRubric(
          questionId: 'q-dyn-1',
          correctOptionIds: {'opt-a'},
          explanation:
              'Immutable data models ensure predictable unidirectional state flow.',
        ),
        q2: const _ServerQuestionRubric(
          questionId: 'q-dyn-2',
          correctOptionIds: {'opt-2a', 'opt-2b'},
          explanation:
              'Domain and data layers remain decoupled from Flutter presentation frameworks.',
        ),
        q3: const _ServerQuestionRubric(
          questionId: 'q-dyn-3',
          correctBooleanValue: true,
          explanation:
              'Unidirectional data flow creates a single source of truth.',
        ),
        q4: const _ServerQuestionRubric(
          questionId: 'q-dyn-4',
          requiredKeywords: [
            'server',
            'replay',
            'revis',
            'mutat',
            'sync',
            'order',
            'base',
          ],
          explanation:
              'The server baseline revision is updated while unacknowledged local mutations are replayed in order.',
        ),
      },
    );

    return dynamicAssessment;
  }

  @override
  Future<Assessment> fetchAssessment(String assessmentId) async {
    return _getOrCreateDynamicAssessment(assessmentId);
  }

  @override
  Future<AssessmentAttemptSummary> fetchAttemptSummary(
    String assessmentId, {
    required String learnerId,
  }) async {
    final assessment = _getOrCreateDynamicAssessment(assessmentId);
    final key = '$learnerId:$assessmentId';
    final attempts = _attemptsByLearnerAssessment[key] ?? const [];

    final total = attempts.length;
    final remaining = (assessment.maxAttempts - total).clamp(
      0,
      assessment.maxAttempts,
    );
    final hasPassed = attempts.any((a) => a.isPassed);
    var highestScore = 0;
    var highestPercentage = 0.0;

    for (final a in attempts) {
      if (a.score > highestScore) highestScore = a.score;
      if (a.percentage > highestPercentage) highestPercentage = a.percentage;
    }

    return AssessmentAttemptSummary(
      assessmentId: assessmentId,
      totalAttempts: total,
      maxAttempts: assessment.maxAttempts,
      remainingAttempts: remaining,
      hasPassed: hasPassed,
      highestScore: highestScore,
      highestPercentage: highestPercentage,
      attempts: List.unmodifiable(attempts),
    );
  }

  @override
  Future<AssessmentAttemptSession> startAttempt(
    String assessmentId, {
    required String learnerId,
  }) async {
    if (learnerId.isEmpty || learnerId == 'guest-learner') {
      throw const AssessmentDataException(
        AssessmentDataErrorKind.unauthenticated,
        'Authentication is required to start an assessment.',
      );
    }
    final assessment = _getOrCreateDynamicAssessment(assessmentId);
    final summary = await fetchAttemptSummary(
      assessmentId,
      learnerId: learnerId,
    );
    if (!summary.canAttempt) {
      throw const AssessmentDataException(
        AssessmentDataErrorKind.attemptLimitExceeded,
        'Maximum assessment attempts reached.',
      );
    }
    final now = _clock().toUtc();
    final attemptId =
        'development-attempt-${now.microsecondsSinceEpoch}-${summary.totalAttempts + 1}';
    final session = AssessmentAttemptSession(
      attemptId: attemptId,
      assessmentId: assessmentId,
      startedAt: now,
      serverNow: now,
      expiresAt: assessment.timeLimit == null
          ? null
          : now.add(assessment.timeLimit!),
      attemptNumber: summary.totalAttempts + 1,
    );
    _activeAttempts[attemptId] = _DevelopmentAttemptSession(
      learnerId: learnerId,
      value: session,
    );
    return session;
  }

  @override
  Future<AssessmentResult> submitAssessment(
    AssessmentSubmission submission, {
    required String learnerId,
  }) async {
    final idempotencyKey =
        '$learnerId:${submission.assessmentId}:${submission.idempotencyKey}';
    if (_submissionIdempotencyStore.containsKey(idempotencyKey)) {
      return _submissionIdempotencyStore[idempotencyKey]!;
    }

    final existingAttemptResult = _resultsByAttemptId[submission.attemptId];
    if (existingAttemptResult != null) {
      throw const AssessmentDataException(
        AssessmentDataErrorKind.conflict,
        'This assessment attempt has already been submitted.',
      );
    }
    final attemptSession = _activeAttempts[submission.attemptId];
    if (attemptSession == null ||
        attemptSession.learnerId != learnerId ||
        attemptSession.value.assessmentId != submission.assessmentId) {
      throw const AssessmentDataException(
        AssessmentDataErrorKind.forbidden,
        'The assessment attempt is not valid for this learner.',
      );
    }
    final expiresAt = attemptSession.value.expiresAt;
    if (expiresAt != null && _clock().toUtc().isAfter(expiresAt)) {
      throw const AssessmentDataException(
        AssessmentDataErrorKind.attemptExpired,
        'The assessment attempt has expired.',
      );
    }

    final assessment = _getOrCreateDynamicAssessment(submission.assessmentId);
    final rubric = _rubrics[submission.assessmentId]!;
    final attemptsKey = '$learnerId:${submission.assessmentId}';
    final previousAttempts = _attemptsByLearnerAssessment[attemptsKey] ?? [];

    if (previousAttempts.length >= assessment.maxAttempts) {
      throw const AssessmentDataException(
        AssessmentDataErrorKind.attemptLimitExceeded,
        'Maximum assessment attempts reached.',
      );
    }

    var earnedScore = 0;
    final maxScore = assessment.totalPoints;
    final questionResults = <QuestionResult>[];

    for (final question in assessment.questions) {
      final qRubric = rubric[question.id];
      final answer = submission.answers[question.id];

      var isCorrect = false;
      var earnedPoints = 0;
      String? feedback;

      if (qRubric != null && answer != null) {
        switch (answer) {
          case SingleChoiceAnswer(selectedOptionId: final optId):
            isCorrect =
                optId != null && qRubric.correctOptionIds.contains(optId);
            earnedPoints = isCorrect ? question.points : 0;
            feedback = isCorrect
                ? 'Correct choice.'
                : 'Incorrect option selected.';

          case MultipleChoiceAnswer(selectedOptionIds: final optIds):
            final expected = qRubric.correctOptionIds;
            final isExact =
                optIds.length == expected.length &&
                optIds.containsAll(expected);
            isCorrect = isExact;
            earnedPoints = isCorrect ? question.points : 0;
            feedback = isCorrect
                ? 'All correct options selected.'
                : 'Did not match all required options.';

          case TrueFalseAnswer(selectedValue: final val):
            isCorrect = val != null && val == qRubric.correctBooleanValue;
            earnedPoints = isCorrect ? question.points : 0;
            feedback = isCorrect ? 'Correct!' : 'Incorrect response.';

          case TextResponseAnswer(textContent: final text):
            final trimmed = text.trim();
            final words = trimmed
                .split(RegExp(r'\s+'))
                .where((w) => w.isNotEmpty)
                .length;
            final matchesKeywords =
                qRubric.requiredKeywords.isEmpty ||
                qRubric.requiredKeywords.any(
                  (kw) => trimmed.toLowerCase().contains(kw.toLowerCase()),
                );
            isCorrect =
                words >= (question as TextResponseQuestion).minWords &&
                matchesKeywords;
            earnedPoints = isCorrect ? question.points : 0;
            feedback = isCorrect
                ? 'Substantive response provided.'
                : 'Response lacked key concepts or minimum length.';
        }
      }

      earnedScore += earnedPoints;
      questionResults.add(
        QuestionResult(
          questionId: question.id,
          isCorrect: isCorrect,
          earnedPoints: earnedPoints,
          maxPoints: question.points,
          correctOptionIds: qRubric?.correctOptionIds,
          correctBooleanValue: qRubric?.correctBooleanValue,
          explanation: qRubric?.explanation,
          feedback: feedback,
        ),
      );
    }

    final percentage = maxScore <= 0 ? 0.0 : (earnedScore / maxScore) * 100;
    final isPassed = percentage >= assessment.passingScorePercentage;

    final result = AssessmentResult(
      assessmentId: submission.assessmentId,
      attemptId: submission.attemptId,
      earnedScore: earnedScore,
      maxScore: maxScore,
      percentage: percentage,
      isPassed: isPassed,
      passingPercentage: assessment.passingScorePercentage,
      durationTaken: submission.durationTaken,
      submittedAt: submission.submittedAt,
      questionResults: List.unmodifiable(questionResults),
      feedbackSummary: isPassed
          ? 'Congratulations! You passed the assessment.'
          : 'You did not achieve the required passing score. Review the explanations below.',
    );

    final attempt = AssessmentAttempt(
      attemptId: submission.attemptId,
      assessmentId: submission.assessmentId,
      learnerId: learnerId,
      attemptNumber: previousAttempts.length + 1,
      score: earnedScore,
      maxScore: maxScore,
      percentage: percentage,
      isPassed: isPassed,
      startedAt: submission.submittedAt.subtract(submission.durationTaken),
      submittedAt: submission.submittedAt,
      duration: submission.durationTaken,
    );

    _attemptsByLearnerAssessment[attemptsKey] = [...previousAttempts, attempt];
    _submissionIdempotencyStore[idempotencyKey] = result;
    _resultsByAttemptId[submission.attemptId] = result;
    _activeAttempts.remove(submission.attemptId);

    return result;
  }
}

DateTime _utcNow() => DateTime.now().toUtc();

final class _DevelopmentAttemptSession {
  const _DevelopmentAttemptSession({
    required this.learnerId,
    required this.value,
  });

  final String learnerId;
  final AssessmentAttemptSession value;
}

final class _ServerQuestionRubric {
  const _ServerQuestionRubric({
    required this.questionId,
    this.correctOptionIds = const {},
    this.correctBooleanValue,
    this.requiredKeywords = const [],
    this.explanation,
  });

  final String questionId;
  final Set<String> correctOptionIds;
  final bool? correctBooleanValue;
  final List<String> requiredKeywords;
  final String? explanation;
}
