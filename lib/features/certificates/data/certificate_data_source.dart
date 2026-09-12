import 'package:learning_platform/features/certificates/domain/certificate.dart';
import 'package:learning_platform/features/certificates/domain/certificate_eligibility.dart';
import 'package:learning_platform/features/certificates/domain/certificate_page.dart';

enum CertificateDataErrorKind {
  notFound,
  ineligible,
  unconfigured,
  revoked,
  network,
}

final class CertificateDataException implements Exception {
  const CertificateDataException(this.kind, this.message);
  final CertificateDataErrorKind kind;
  final String message;

  @override
  String toString() => 'CertificateDataException($kind, $message)';
}

abstract interface class CertificateDataSource {
  Future<List<Certificate>> fetchCertificates(String learnerId);

  Future<CertificatePage> fetchCertificatePage(
    String learnerId, {
    String? cursor,
    int limit = 20,
  });

  Future<Certificate?> fetchCertificateByCourse(
    String courseId, {
    required String learnerId,
  });

  Future<Certificate> fetchCertificateById(
    String certificateId, {
    required String learnerId,
  });

  Future<CertificateEligibility> checkEligibility(
    String courseId, {
    required String learnerId,
  });

  Future<Certificate> claimCertificate(
    String courseId, {
    required String learnerId,
    required String learnerName,
  });

  Future<CertificateVerificationInfo> verifyCredential(String credentialId);
}
