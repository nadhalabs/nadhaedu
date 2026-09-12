import 'package:flutter_test/flutter_test.dart';
import 'package:learning_platform/features/assessments/application/assessment_controller.dart';
import 'package:learning_platform/features/assessments/application/assessment_state.dart';
import 'package:learning_platform/features/assessments/data/assessment_repository_impl.dart';
import 'package:learning_platform/features/assessments/data/foundation_assessment_data_source.dart';
import 'package:learning_platform/features/assessments/domain/assessment_submission.dart';

void main() {
  group('AssessmentController Lifecycle and Orchestration', () {
    late FoundationAssessmentDataSource dataSource;
    late AssessmentRepositoryImpl repository;
    const assessmentId = 'quiz-foundations-1';
    const learnerId = 'controller-test-learner';

    setUp(() {
      dataSource = FoundationAssessmentDataSource();
      repository = AssessmentRepositoryImpl(dataSource: dataSource);
    });

    test('initializes and loads assessment into intro state', () async {
      final controller = AssessmentController(
        repository: repository,
        assessmentId: assessmentId,
        learnerId: learnerId,
      );

      await controller.load();

      expect(controller.state.status, AssessmentLifecycle.intro);
      expect(controller.state.assessment?.id, assessmentId);
      expect(controller.state.attemptSummary?.canAttempt, isTrue);
      controller.dispose();
    });

    test(
      'startAssessment initializes taking state with all questions prepared',
      () async {
        final controller = AssessmentController(
          repository: repository,
          assessmentId: assessmentId,
          learnerId: learnerId,
        );

        await controller.load();
        await controller.startAssessment();

        expect(controller.state.status, AssessmentLifecycle.taking);
        expect(controller.state.currentQuestionIndex, 0);
        expect(controller.state.answers.length, 4);
        expect(controller.state.answeredCount, 0);
        expect(controller.state.attemptId, isNotNull);
        expect(controller.state.idempotencyKey, isNotNull);
        controller.dispose();
      },
    );

    test(
      'answering all 4 question types updates state and answered count',
      () async {
        final controller = AssessmentController(
          repository: repository,
          assessmentId: assessmentId,
          learnerId: learnerId,
        );

        await controller.load();
        await controller.startAssessment();

        // Q1: Single choice
        controller.selectSingleChoice('q-foundations-1', 'opt-2');
        expect(controller.state.answeredCount, 1);
        final a1 =
            controller.state.answers['q-foundations-1'] as SingleChoiceAnswer;
        expect(a1.selectedOptionId, 'opt-2');

        // Q2: Multiple choice toggle
        controller.toggleMultipleChoice('q-foundations-2', 'opt-2a');
        controller.toggleMultipleChoice('q-foundations-2', 'opt-2c');
        controller.toggleMultipleChoice('q-foundations-2', 'opt-2d');
        expect(controller.state.answeredCount, 2);
        final a2 =
            controller.state.answers['q-foundations-2'] as MultipleChoiceAnswer;
        expect(a2.selectedOptionIds, {'opt-2a', 'opt-2c', 'opt-2d'});

        // Q3: True/False
        controller.setTrueFalse('q-foundations-3', false);
        expect(controller.state.answeredCount, 3);
        final a3 =
            controller.state.answers['q-foundations-3'] as TrueFalseAnswer;
        expect(a3.selectedValue, isFalse);

        // Q4: Text response
        controller.setTextResponse(
          'q-foundations-4',
          'Centralized access evaluation maintains security policy.',
        );
        expect(controller.state.answeredCount, 4);
        final a4 =
            controller.state.answers['q-foundations-4'] as TextResponseAnswer;
        expect(a4.textContent.isNotEmpty, isTrue);

        controller.dispose();
      },
    );

    test('navigates questions and toggles review flag', () async {
      final controller = AssessmentController(
        repository: repository,
        assessmentId: assessmentId,
        learnerId: learnerId,
      );

      await controller.load();
      await controller.startAssessment();

      expect(controller.state.isFirstQuestion, isTrue);
      expect(controller.state.isLastQuestion, isFalse);

      controller.nextQuestion();
      expect(controller.state.currentQuestionIndex, 1);

      controller.toggleMarkForReview('q-foundations-2');
      expect(controller.state.isQuestionMarked('q-foundations-2'), isTrue);

      controller.toggleMarkForReview('q-foundations-2');
      expect(controller.state.isQuestionMarked('q-foundations-2'), isFalse);

      controller.goToQuestion(3);
      expect(controller.state.currentQuestionIndex, 3);
      expect(controller.state.isLastQuestion, isTrue);

      controller.previousQuestion();
      expect(controller.state.currentQuestionIndex, 2);

      controller.dispose();
    });

    test(
      'submitting passing answers invokes onPassed and completes session',
      () async {
        var passedCallbackCalled = false;
        final controller = AssessmentController(
          repository: repository,
          assessmentId: assessmentId,
          learnerId: learnerId,
          onPassed: (id) async {
            passedCallbackCalled = true;
          },
        );

        await controller.load();
        await controller.startAssessment();

        controller.selectSingleChoice('q-foundations-1', 'opt-2');
        controller.toggleMultipleChoice('q-foundations-2', 'opt-2a');
        controller.toggleMultipleChoice('q-foundations-2', 'opt-2c');
        controller.toggleMultipleChoice('q-foundations-2', 'opt-2d');
        controller.setTrueFalse('q-foundations-3', false);
        controller.setTextResponse(
          'q-foundations-4',
          'Centralized security evaluation across features.',
        );

        await controller.submit();

        expect(controller.state.status, AssessmentLifecycle.completed);
        expect(controller.state.result?.isPassed, isTrue);
        expect(controller.state.result?.percentage, 100.0);
        expect(passedCallbackCalled, isTrue);

        controller.dispose();
      },
    );
  });
}
