import 'package:learning_platform/features/certificates/data/certificate_data_source.dart';
import 'package:learning_platform/features/certificates/domain/certificate.dart';
import 'package:learning_platform/features/certificates/domain/certificate_eligibility.dart';
import 'package:learning_platform/features/certificates/domain/certificate_page.dart';
import 'package:learning_platform/features/certificates/domain/certificate_repository.dart';

final class CertificateRepositoryImpl implements CertificateRepository {
  CertificateRepositoryImpl({required CertificateDataSource dataSource})
    : _dataSource = dataSource;

  final CertificateDataSource _dataSource;

  @override
  Future<List<Certificate>> fetchCertificates(String learnerId) {
    return _dataSource.fetchCertificates(learnerId);
  }

  @override
  Future<CertificatePage> fetchCertificatePage(
    String learnerId, {
    String? cursor,
    int limit = 20,
  }) => _dataSource.fetchCertificatePage(
    learnerId,
    cursor: cursor,
    limit: limit.clamp(1, 50),
  );

  @override
  Future<Certificate?> fetchCertificateByCourse(
    String courseId, {
    required String learnerId,
  }) {
    return _dataSource.fetchCertificateByCourse(courseId, learnerId: learnerId);
  }

  @override
  Future<Certificate> fetchCertificateById(
    String certificateId, {
    required String learnerId,
  }) {
    return _dataSource.fetchCertificateById(
      certificateId,
      learnerId: learnerId,
    );
  }

  @override
  Future<CertificateEligibility> checkEligibility(
    String courseId, {
    required String learnerId,
  }) {
    return _dataSource.checkEligibility(courseId, learnerId: learnerId);
  }

  @override
  Future<Certificate> claimCertificate(
    String courseId, {
    required String learnerId,
    required String learnerName,
  }) {
    return _dataSource.claimCertificate(
      courseId,
      learnerId: learnerId,
      learnerName: learnerName,
    );
  }

  @override
  Future<CertificateVerificationInfo> verifyCredential(String credentialId) {
    return _dataSource.verifyCredential(credentialId);
  }
}
