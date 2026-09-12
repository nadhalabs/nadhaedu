import 'package:flutter_test/flutter_test.dart';
import 'package:learning_platform/features/assessments/data/assessment_data_source.dart';
import 'package:learning_platform/features/assessments/data/foundation_assessment_data_source.dart';
import 'package:learning_platform/features/assessments/domain/assessment_submission.dart';

void main() {
  group('FoundationAssessmentDataSource development fixture', () {
    late FoundationAssessmentDataSource dataSource;
    const learnerId = 'test-learner-123';
    const assessmentId = 'quiz-foundations-1';

    setUp(() {
      dataSource = FoundationAssessmentDataSource();
    });

    test(
      'fetchAssessment returns questions without exposing answer keys or rubrics',
      () async {
        final assessment = await dataSource.fetchAssessment(assessmentId);

        expect(assessment.id, assessmentId);
        expect(assessment.questions.length, 4);
        expect(assessment.totalPoints, 6);
        expect(assessment.passingScorePercentage, 75);
      },
    );

    test('evaluates passing submission accurately with explanations', () async {
      final now = DateTime.now().toUtc();
      final session = await dataSource.startAttempt(
        assessmentId,
        learnerId: learnerId,
      );
      final submission = AssessmentSubmission(
        assessmentId: assessmentId,
        attemptId: session.attemptId,
        durationTaken: const Duration(minutes: 5),
        answers: const {
          'q-foundations-1': SingleChoiceAnswer(
            questionId: 'q-foundations-1',
            selectedOptionId: 'opt-2', // Correct
          ),
          'q-foundations-2': MultipleChoiceAnswer(
            questionId: 'q-foundations-2',
            selectedOptionIds: {
              'opt-2a',
              'opt-2c',
              'opt-2d',
            }, // Correct exact match
          ),
          'q-foundations-3': TrueFalseAnswer(
            questionId: 'q-foundations-3',
            selectedValue: false, // Correct
          ),
          'q-foundations-4': TextResponseAnswer(
            questionId: 'q-foundations-4',
            textContent:
                'Centralized access evaluation maintains consistent security policies across all features.', // Correct
          ),
        },
        idempotencyKey: 'idem-pass-1',
        submittedAt: now,
      );

      final result = await dataSource.submitAssessment(
        submission,
        learnerId: learnerId,
      );

      expect(result.isPassed, isTrue);
      expect(result.earnedScore, 6);
      expect(result.maxScore, 6);
      expect(result.percentage, 100.0);
      expect(result.questionResults.every((q) => q.isCorrect), isTrue);
      expect(
        result.questionResults.every((q) => q.explanation != null),
        isTrue,
      );

      final summary = await dataSource.fetchAttemptSummary(
        assessmentId,
        learnerId: learnerId,
      );
      expect(summary.totalAttempts, 1);
      expect(summary.hasPassed, isTrue);
      expect(summary.remainingAttempts, 2);
    });

    test(
      'evaluates failing submission and returns diagnostic explanations',
      () async {
        final now = DateTime.now().toUtc();
        final session = await dataSource.startAttempt(
          assessmentId,
          learnerId: learnerId,
        );
        final submission = AssessmentSubmission(
          assessmentId: assessmentId,
          attemptId: session.attemptId,
          durationTaken: const Duration(minutes: 3),
          answers: const {
            'q-foundations-1': SingleChoiceAnswer(
              questionId: 'q-foundations-1',
              selectedOptionId: 'opt-1', // Incorrect
            ),
            'q-foundations-2': MultipleChoiceAnswer(
              questionId: 'q-foundations-2',
              selectedOptionIds: {'opt-2b'}, // Incorrect
            ),
            'q-foundations-3': TrueFalseAnswer(
              questionId: 'q-foundations-3',
              selectedValue: true, // Incorrect
            ),
            'q-foundations-4': TextResponseAnswer(
              questionId: 'q-foundations-4',
              textContent: 'No idea', // Insufficient
            ),
          },
          idempotencyKey: 'idem-fail-1',
          submittedAt: now,
        );

        final result = await dataSource.submitAssessment(
          submission,
          learnerId: learnerId,
        );

        expect(result.isPassed, isFalse);
        expect(result.earnedScore, 0);
        expect(result.percentage, 0.0);
        expect(result.questionResults.every((q) => !q.isCorrect), isTrue);
      },
    );

    test(
      'submission idempotency returns cached result without consuming extra attempts',
      () async {
        final now = DateTime.now().toUtc();
        final session = await dataSource.startAttempt(
          assessmentId,
          learnerId: learnerId,
        );
        final submission = AssessmentSubmission(
          assessmentId: assessmentId,
          attemptId: session.attemptId,
          durationTaken: const Duration(minutes: 2),
          answers: const {
            'q-foundations-1': SingleChoiceAnswer(
              questionId: 'q-foundations-1',
              selectedOptionId: 'opt-2',
            ),
          },
          idempotencyKey: 'same-idempotency-token-123',
          submittedAt: now,
        );

        final result1 = await dataSource.submitAssessment(
          submission,
          learnerId: learnerId,
        );
        final result2 = await dataSource.submitAssessment(
          submission,
          learnerId: learnerId,
        );

        expect(identical(result1, result2), isTrue);

        final summary = await dataSource.fetchAttemptSummary(
          assessmentId,
          learnerId: learnerId,
        );
        expect(summary.totalAttempts, 1);
      },
    );

    test(
      'enforces max attempt limit and throws attemptLimitExceeded',
      () async {
        final now = DateTime.now().toUtc();

        for (var i = 1; i <= 3; i++) {
          final session = await dataSource.startAttempt(
            assessmentId,
            learnerId: learnerId,
          );
          final submission = AssessmentSubmission(
            assessmentId: assessmentId,
            attemptId: session.attemptId,
            durationTaken: const Duration(minutes: 1),
            answers: const {},
            idempotencyKey: 'key-$i',
            submittedAt: now.add(Duration(minutes: i)),
          );
          await dataSource.submitAssessment(submission, learnerId: learnerId);
        }

        final summary = await dataSource.fetchAttemptSummary(
          assessmentId,
          learnerId: learnerId,
        );
        expect(summary.totalAttempts, 3);
        expect(summary.canAttempt, isFalse);
        expect(summary.remainingAttempts, 0);

        expect(
          () => dataSource.startAttempt(assessmentId, learnerId: learnerId),
          throwsA(
            isA<AssessmentDataException>().having(
              (e) => e.kind,
              'kind',
              AssessmentDataErrorKind.attemptLimitExceeded,
            ),
          ),
        );
      },
    );

    test('rejects submissions without a server-issued attempt', () async {
      final submission = AssessmentSubmission(
        assessmentId: assessmentId,
        attemptId: 'forged-attempt',
        durationTaken: const Duration(seconds: 1),
        answers: const {},
        idempotencyKey: 'forged-key',
        submittedAt: DateTime.utc(2026),
      );

      expect(
        () => dataSource.submitAssessment(submission, learnerId: learnerId),
        throwsA(
          isA<AssessmentDataException>().having(
            (error) => error.kind,
            'kind',
            AssessmentDataErrorKind.forbidden,
          ),
        ),
      );
    });

    test(
      'rejects a second submission for one attempt with a new key',
      () async {
        final session = await dataSource.startAttempt(
          assessmentId,
          learnerId: learnerId,
        );
        final first = AssessmentSubmission(
          assessmentId: assessmentId,
          attemptId: session.attemptId,
          durationTaken: const Duration(seconds: 1),
          answers: const {},
          idempotencyKey: 'first-key',
          submittedAt: session.startedAt,
        );
        await dataSource.submitAssessment(first, learnerId: learnerId);

        final second = AssessmentSubmission(
          assessmentId: assessmentId,
          attemptId: session.attemptId,
          durationTaken: const Duration(seconds: 1),
          answers: const {},
          idempotencyKey: 'second-key',
          submittedAt: session.startedAt,
        );
        expect(
          () => dataSource.submitAssessment(second, learnerId: learnerId),
          throwsA(
            isA<AssessmentDataException>().having(
              (error) => error.kind,
              'kind',
              AssessmentDataErrorKind.conflict,
            ),
          ),
        );
      },
    );

    test('rejects an expired authoritative attempt', () async {
      var now = DateTime.utc(2026, 1, 1, 12);
      final timedSource = FoundationAssessmentDataSource(clock: () => now);
      final session = await timedSource.startAttempt(
        assessmentId,
        learnerId: learnerId,
      );
      now = now.add(const Duration(minutes: 11));

      final submission = AssessmentSubmission(
        assessmentId: assessmentId,
        attemptId: session.attemptId,
        durationTaken: const Duration(minutes: 11),
        answers: const {},
        idempotencyKey: 'expired-key',
        submittedAt: now,
      );
      expect(
        () => timedSource.submitAssessment(submission, learnerId: learnerId),
        throwsA(
          isA<AssessmentDataException>().having(
            (error) => error.kind,
            'kind',
            AssessmentDataErrorKind.attemptExpired,
          ),
        ),
      );
    });

    test('does not create attempts for guest identities', () {
      expect(
        () => dataSource.startAttempt(assessmentId, learnerId: 'guest-learner'),
        throwsA(
          isA<AssessmentDataException>().having(
            (error) => error.kind,
            'kind',
            AssessmentDataErrorKind.unauthenticated,
          ),
        ),
      );
    });
  });
}
