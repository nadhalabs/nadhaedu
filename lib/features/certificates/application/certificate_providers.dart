import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_platform/bootstrap/providers.dart';
import 'package:learning_platform/config/app_environment.dart';
import 'package:learning_platform/features/assessments/application/assessment_providers.dart';
import 'package:learning_platform/features/authentication/application/auth_providers.dart';
import 'package:learning_platform/features/certificates/data/certificate_data_source.dart';
import 'package:learning_platform/features/certificates/data/certificate_repository_impl.dart';
import 'package:learning_platform/features/certificates/data/foundation_certificate_data_source.dart';
import 'package:learning_platform/features/certificates/data/remote_certificate_data_source.dart';
import 'package:learning_platform/features/certificates/domain/certificate.dart';
import 'package:learning_platform/features/certificates/domain/certificate_eligibility.dart';
import 'package:learning_platform/features/certificates/domain/certificate_repository.dart';
import 'package:learning_platform/features/entitlements/application/entitlement_providers.dart';
import 'package:learning_platform/features/learning_progress/application/learning_providers.dart';

final certificateDataSourceProvider = Provider<CertificateDataSource>(
  (ref) => switch (ref.watch(appConfigProvider).environment) {
    AppEnvironment.development => FoundationCertificateDataSource(
      entitlementDataSource: ref.watch(entitlementDataSourceProvider),
      learningDataSource: ref.watch(learningDataSourceProvider),
      assessmentDataSource: ref.watch(assessmentDataSourceProvider),
    ),
    AppEnvironment.staging || AppEnvironment.production =>
      RemoteCertificateDataSource(ref.watch(apiClientProvider)),
  },
);

final certificateRepositoryProvider = Provider<CertificateRepository>((ref) {
  return CertificateRepositoryImpl(
    dataSource: ref.watch(certificateDataSourceProvider),
  );
});

final learnerCertificatesProvider =
    FutureProvider.autoDispose<List<Certificate>>((ref) {
      final learnerId =
          ref.watch(authControllerProvider).session?.identity.id ??
          'dev-learner-id';
      return ref
          .watch(certificateRepositoryProvider)
          .fetchCertificates(learnerId);
    });

final certificateDetailProvider = FutureProvider.autoDispose
    .family<Certificate, String>((ref, id) {
      final learnerId =
          ref.watch(authControllerProvider).session?.identity.id ??
          'dev-learner-id';
      return ref
          .watch(certificateRepositoryProvider)
          .fetchCertificateById(id, learnerId: learnerId);
    });

final courseCertificateEligibilityProvider = FutureProvider.autoDispose
    .family<CertificateEligibility, String>((ref, courseId) {
      final learnerId =
          ref.watch(authControllerProvider).session?.identity.id ??
          'dev-learner-id';
      return ref
          .watch(certificateRepositoryProvider)
          .checkEligibility(courseId, learnerId: learnerId);
    });

final credentialVerificationProvider = FutureProvider.autoDispose
    .family<CertificateVerificationInfo, String>((ref, credentialId) {
      return ref
          .watch(certificateRepositoryProvider)
          .verifyCredential(credentialId);
    });
