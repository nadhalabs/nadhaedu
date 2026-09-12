import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_platform/bootstrap/providers.dart';
import 'package:learning_platform/config/app_environment.dart';
import 'package:learning_platform/features/assessments/application/assessment_controller.dart';
import 'package:learning_platform/features/assessments/application/assessment_state.dart';
import 'package:learning_platform/features/assessments/data/assessment_data_source.dart';
import 'package:learning_platform/features/assessments/data/assessment_repository_impl.dart';
import 'package:learning_platform/features/assessments/data/foundation_assessment_data_source.dart';
import 'package:learning_platform/features/assessments/data/remote_assessment_data_source.dart';
import 'package:learning_platform/features/assessments/domain/assessment_attempt.dart';
import 'package:learning_platform/features/assessments/domain/assessment_repository.dart';
import 'package:learning_platform/features/authentication/application/auth_providers.dart';

final assessmentDataSourceProvider = Provider<AssessmentDataSource>(
  (ref) => switch (ref.watch(appConfigProvider).environment) {
    AppEnvironment.development => FoundationAssessmentDataSource(),
    AppEnvironment.staging || AppEnvironment.production =>
      RemoteAssessmentDataSource(ref.watch(apiClientProvider)),
  },
);

final assessmentRepositoryProvider = Provider<AssessmentRepository>((ref) {
  return AssessmentRepositoryImpl(
    dataSource: ref.watch(assessmentDataSourceProvider),
  );
});

final assessmentControllerProvider = StateNotifierProvider.autoDispose
    .family<AssessmentController, AssessmentSessionState, String>((
      ref,
      assessmentId,
    ) {
      final learnerId =
          ref.watch(authControllerProvider).session?.identity.id ??
          'guest-learner';
      return AssessmentController(
        repository: ref.watch(assessmentRepositoryProvider),
        assessmentId: assessmentId,
        learnerId: learnerId,
      );
    });

final assessmentAttemptSummaryProvider = FutureProvider.autoDispose
    .family<AssessmentAttemptSummary, String>((ref, assessmentId) {
      final learnerId =
          ref.watch(authControllerProvider).session?.identity.id ??
          'guest-learner';
      return ref
          .watch(assessmentRepositoryProvider)
          .fetchAttemptSummary(assessmentId, learnerId: learnerId);
    });
