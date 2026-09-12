import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_platform/features/assessments/application/assessment_controller.dart';
import 'package:learning_platform/features/assessments/application/assessment_state.dart';
import 'package:learning_platform/features/assessments/data/foundation_assessment_data_source.dart';
import 'package:learning_platform/features/assessments/domain/assessment.dart';
import 'package:learning_platform/features/assessments/domain/assessment_attempt.dart';
import 'package:learning_platform/features/assessments/domain/assessment_repository.dart';
import 'package:learning_platform/features/assessments/domain/assessment_result.dart';
import 'package:learning_platform/features/assessments/domain/assessment_session.dart';
import 'package:learning_platform/features/assessments/domain/assessment_submission.dart';

class ControlledRepository implements AssessmentRepository {
  final source = FoundationAssessmentDataSource();
  Completer<void>? startGate;
  Completer<void>? submitGate;
  int starts = 0;
  bool failNextSubmission = false;
  bool failSummaryAfterSubmission = false;
  bool accepted = false;
  final submissions = <AssessmentSubmission>[];
  @override
  Future<Assessment> fetchAssessment(String id) => source.fetchAssessment(id);
  @override
  Future<AssessmentAttemptSummary> fetchAttemptSummary(
    String id, {
    required String learnerId,
  }) {
    if (accepted && failSummaryAfterSubmission) {
      throw StateError('summary unavailable');
    }
    return source.fetchAttemptSummary(id, learnerId: learnerId);
  }

  @override
  Future<AssessmentAttemptSession> startAttempt(
    String id, {
    required String learnerId,
  }) async {
    starts++;
    await startGate?.future;
    return source.startAttempt(id, learnerId: learnerId);
  }

  @override
  Future<AssessmentResult> submitAssessment(
    AssessmentSubmission submission, {
    required String learnerId,
  }) async {
    submissions.add(submission);
    await submitGate?.future;
    if (failNextSubmission) {
      failNextSubmission = false;
      throw StateError('offline');
    }
    final result = await source.submitAssessment(
      submission,
      learnerId: learnerId,
    );
    accepted = true;
    return result;
  }
}

AssessmentController controller(ControlledRepository repository) =>
    AssessmentController(
      repository: repository,
      assessmentId: 'quiz-foundations-1',
      learnerId: 'learner',
    );

void main() {
  test(
    'rapid start taps allocate a single attempt and expose starting state',
    () async {
      final repository = ControlledRepository()..startGate = Completer<void>();
      final subject = controller(repository);
      await subject.load();
      final first = subject.startAssessment();
      final second = subject.startAssessment();
      expect(subject.state.status, AssessmentLifecycle.starting);
      expect(repository.starts, 1);
      repository.startGate!.complete();
      await Future.wait([first, second]);
      expect(subject.state.isTaking, isTrue);
      subject.dispose();
    },
  );
  test(
    'rapid submission taps send once; retry preserves exact payload and answers',
    () async {
      final repository = ControlledRepository()
        ..submitGate = Completer<void>()
        ..failNextSubmission = true;
      final subject = controller(repository);
      await subject.load();
      await subject.startAssessment();
      subject.selectSingleChoice('q-foundations-1', 'opt-2');
      final first = subject.submit();
      final second = subject.submit();
      subject.selectSingleChoice('q-foundations-1', 'opt-1');
      expect(repository.submissions.length, 1);
      repository.submitGate!.complete();
      await Future.wait([first, second]);
      expect(subject.state.isError, isTrue);
      await subject.retry();
      expect(repository.submissions.length, 2);
      expect(
        identical(repository.submissions.first, repository.submissions.last),
        isTrue,
      );
      expect(
        (repository.submissions.last.answers['q-foundations-1']
                as SingleChoiceAnswer)
            .selectedOptionId,
        'opt-2',
      );
      expect(subject.state.isCompleted, isTrue);
      subject.dispose();
    },
  );
  test('summary refresh failure cannot discard an accepted result', () async {
    final repository = ControlledRepository()
      ..failSummaryAfterSubmission = true;
    final subject = controller(repository);
    await subject.load();
    await subject.startAssessment();
    await subject.submit();
    expect(subject.state.isCompleted, isTrue);
    expect(subject.state.result, isNotNull);
    subject.dispose();
  });
  test('leaving while attempt starts does not write disposed state', () async {
    final repository = ControlledRepository()..startGate = Completer<void>();
    final subject = controller(repository);
    await subject.load();
    final pending = subject.startAssessment();
    subject.dispose();
    repository.startGate!.complete();
    await expectLater(pending, completes);
  });
}
