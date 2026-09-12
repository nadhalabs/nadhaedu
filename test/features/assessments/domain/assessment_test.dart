import 'package:flutter_test/flutter_test.dart';
import 'package:learning_platform/features/assessments/domain/assessment.dart';
import 'package:learning_platform/features/assessments/domain/assessment_attempt.dart';
import 'package:learning_platform/features/assessments/domain/assessment_question.dart';
import 'package:learning_platform/features/assessments/domain/assessment_result.dart';
import 'package:learning_platform/features/assessments/domain/assessment_submission.dart';

void main() {
  group('Assessment Domain Models', () {
    test(
      'Question hierarchy models correct types without leaking answer keys',
      () {
        const q1 = SingleChoiceQuestion(
          id: 'q1',
          prompt: 'Select one',
          options: [
            QuestionOption(id: 'opt1', text: 'Option 1'),
            QuestionOption(id: 'opt2', text: 'Option 2'),
          ],
          points: 2,
        );

        const q2 = MultipleChoiceQuestion(
          id: 'q2',
          prompt: 'Select multiple',
          options: [
            QuestionOption(id: 'optA', text: 'Option A'),
            QuestionOption(id: 'optB', text: 'Option B'),
          ],
          minSelections: 2,
          points: 3,
        );

        const q3 = TrueFalseQuestion(
          id: 'q3',
          prompt: 'Is this true?',
          points: 1,
        );

        const q4 = TextResponseQuestion(
          id: 'q4',
          prompt: 'Explain concept',
          minWords: 5,
          points: 4,
        );

        expect(q1.type, QuestionType.singleChoice);
        expect(q1.points, 2);
        expect(q1.options.length, 2);

        expect(q2.type, QuestionType.multipleChoice);
        expect(q2.minSelections, 2);
        expect(q2.points, 3);

        expect(q3.type, QuestionType.trueFalse);
        expect(q3.points, 1);

        expect(q4.type, QuestionType.textResponse);
        expect(q4.minWords, 5);
        expect(q4.points, 4);
      },
    );

    test('QuestionAnswer hierarchy correctly reports answered state', () {
      const scAnswerEmpty = SingleChoiceAnswer(
        questionId: 'q1',
        selectedOptionId: null,
      );
      const scAnswerFilled = SingleChoiceAnswer(
        questionId: 'q1',
        selectedOptionId: 'opt1',
      );
      expect(scAnswerEmpty.isAnswered, isFalse);
      expect(scAnswerFilled.isAnswered, isTrue);

      const mcAnswerEmpty = MultipleChoiceAnswer(
        questionId: 'q2',
        selectedOptionIds: {},
      );
      const mcAnswerFilled = MultipleChoiceAnswer(
        questionId: 'q2',
        selectedOptionIds: {'optA', 'optB'},
      );
      expect(mcAnswerEmpty.isAnswered, isFalse);
      expect(mcAnswerFilled.isAnswered, isTrue);

      const tfAnswerEmpty = TrueFalseAnswer(
        questionId: 'q3',
        selectedValue: null,
      );
      const tfAnswerFilled = TrueFalseAnswer(
        questionId: 'q3',
        selectedValue: true,
      );
      expect(tfAnswerEmpty.isAnswered, isFalse);
      expect(tfAnswerFilled.isAnswered, isTrue);

      const textAnswerEmpty = TextResponseAnswer(
        questionId: 'q4',
        textContent: '   ',
      );
      const textAnswerFilled = TextResponseAnswer(
        questionId: 'q4',
        textContent: 'Valid answer',
      );
      expect(textAnswerEmpty.isAnswered, isFalse);
      expect(textAnswerFilled.isAnswered, isTrue);
    });

    test(
      'AssessmentSummary computes isTimed and question points correctly',
      () {
        final summary = const AssessmentSummary(
          id: 'quiz-1',
          courseId: 'course-1',
          title: 'Quiz Title',
          description: 'Quiz Description',
          questionCount: 2,
          passingScorePercentage: 80,
          timeLimit: Duration(minutes: 10),
          maxAttempts: 3,
        );

        final assessment = Assessment(
          summary: summary,
          questions: const [
            TrueFalseQuestion(id: 'q1', prompt: 'Prompt 1', points: 3),
            TrueFalseQuestion(id: 'q2', prompt: 'Prompt 2', points: 2),
          ],
          instructions: const ['Instruction 1'],
          updatedAt: DateTime.utc(2026, 1, 1),
        );

        expect(summary.isTimed, isTrue);
        expect(assessment.totalPoints, 5);
        expect(assessment.isTimed, isTrue);
        expect(assessment.passingScorePercentage, 80);
      },
    );

    test('AssessmentResult computes totals and passing status', () {
      final now = DateTime.now().toUtc();
      final result = AssessmentResult(
        assessmentId: 'quiz-1',
        attemptId: 'att-1',
        earnedScore: 8,
        maxScore: 10,
        percentage: 80.0,
        isPassed: true,
        passingPercentage: 75,
        durationTaken: const Duration(minutes: 4),
        submittedAt: now,
        questionResults: const [
          QuestionResult(
            questionId: 'q1',
            isCorrect: true,
            earnedPoints: 5,
            maxPoints: 5,
            explanation: 'Correct explanation',
          ),
          QuestionResult(
            questionId: 'q2',
            isCorrect: false,
            earnedPoints: 3,
            maxPoints: 5,
            explanation: 'Partial explanation',
          ),
        ],
        feedbackSummary: 'Passed!',
      );

      expect(result.isPassed, isTrue);
      expect(result.correctCount, 1);
      expect(result.totalCount, 2);
    });

    test(
      'AssessmentAttemptSummary calculates remaining attempts and highest score',
      () {
        final now = DateTime.now().toUtc();
        final attempt1 = AssessmentAttempt(
          attemptId: 'att-1',
          assessmentId: 'quiz-1',
          learnerId: 'learner-1',
          attemptNumber: 1,
          score: 6,
          maxScore: 10,
          percentage: 60.0,
          isPassed: false,
          startedAt: now.subtract(const Duration(minutes: 10)),
          submittedAt: now.subtract(const Duration(minutes: 5)),
          duration: const Duration(minutes: 5),
        );

        final attempt2 = AssessmentAttempt(
          attemptId: 'att-2',
          assessmentId: 'quiz-1',
          learnerId: 'learner-1',
          attemptNumber: 2,
          score: 9,
          maxScore: 10,
          percentage: 90.0,
          isPassed: true,
          startedAt: now.subtract(const Duration(minutes: 4)),
          submittedAt: now,
          duration: const Duration(minutes: 4),
        );

        final summary = AssessmentAttemptSummary(
          assessmentId: 'quiz-1',
          totalAttempts: 2,
          maxAttempts: 3,
          remainingAttempts: 1,
          hasPassed: true,
          highestScore: 9,
          highestPercentage: 90.0,
          attempts: [attempt1, attempt2],
        );

        expect(summary.canAttempt, isTrue);
        expect(summary.remainingAttempts, 1);
        expect(summary.highestScore, 9);
        expect(summary.highestPercentage, 90.0);
        expect(summary.latestAttempt?.attemptId, 'att-2');
      },
    );
  });
}
