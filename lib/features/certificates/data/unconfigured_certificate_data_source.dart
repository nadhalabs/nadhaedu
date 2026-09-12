import 'package:learning_platform/features/certificates/data/certificate_data_source.dart';
import 'package:learning_platform/features/certificates/domain/certificate.dart';
import 'package:learning_platform/features/certificates/domain/certificate_eligibility.dart';
import 'package:learning_platform/features/certificates/domain/certificate_page.dart';

final class UnconfiguredCertificateDataSource implements CertificateDataSource {
  const UnconfiguredCertificateDataSource();

  @override
  Future<CertificatePage> fetchCertificatePage(
    String learnerId, {
    String? cursor,
    int limit = 20,
  }) async {
    throw const CertificateDataException(
      CertificateDataErrorKind.unconfigured,
      'Certificate service is not configured for this environment.',
    );
  }

  @override
  Future<List<Certificate>> fetchCertificates(String learnerId) async {
    throw const CertificateDataException(
      CertificateDataErrorKind.unconfigured,
      'Certificate service is not configured for this environment.',
    );
  }

  @override
  Future<Certificate?> fetchCertificateByCourse(
    String courseId, {
    required String learnerId,
  }) async {
    throw const CertificateDataException(
      CertificateDataErrorKind.unconfigured,
      'Certificate service is not configured for this environment.',
    );
  }

  @override
  Future<Certificate> fetchCertificateById(
    String certificateId, {
    required String learnerId,
  }) async {
    throw const CertificateDataException(
      CertificateDataErrorKind.unconfigured,
      'Certificate service is not configured for this environment.',
    );
  }

  @override
  Future<CertificateEligibility> checkEligibility(
    String courseId, {
    required String learnerId,
  }) async {
    throw const CertificateDataException(
      CertificateDataErrorKind.unconfigured,
      'Certificate service is not configured for this environment.',
    );
  }

  @override
  Future<Certificate> claimCertificate(
    String courseId, {
    required String learnerId,
    required String learnerName,
  }) async {
    throw const CertificateDataException(
      CertificateDataErrorKind.unconfigured,
      'Certificate service is not configured for this environment.',
    );
  }

  @override
  Future<CertificateVerificationInfo> verifyCredential(
    String credentialId,
  ) async {
    throw const CertificateDataException(
      CertificateDataErrorKind.unconfigured,
      'Certificate service is not configured for this environment.',
    );
  }
}
