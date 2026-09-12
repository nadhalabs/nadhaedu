import 'package:learning_platform/core/errors/result.dart';
import 'package:learning_platform/core/networking/api_client.dart';
import 'package:learning_platform/features/certificates/data/certificate_data_source.dart';
import 'package:learning_platform/features/certificates/domain/certificate.dart';
import 'package:learning_platform/features/certificates/domain/certificate_eligibility.dart';
import 'package:learning_platform/features/certificates/domain/certificate_page.dart';
import 'package:learning_platform/features/entitlements/domain/access_policy.dart';

final class RemoteCertificateDataSource implements CertificateDataSource {
  const RemoteCertificateDataSource(this._client);

  final ApiClient _client;

  @override
  Future<List<Certificate>> fetchCertificates(String learnerId) async {
    return (await fetchCertificatePage(learnerId, limit: 50)).items;
  }

  @override
  Future<CertificatePage> fetchCertificatePage(
    String learnerId, {
    String? cursor,
    int limit = 20,
  }) async {
    final query = <String, Object?>{'limit': limit.clamp(1, 50)};
    if (cursor case final value?) query['cursor'] = value;
    final json = await _get('/api/v1/certificates', query: query);
    final items = (json['items']! as List<Object?>)
        .map((value) => _decodeCertificate(value! as Map<String, Object?>))
        .toList(growable: false);
    return CertificatePage(
      items: items,
      nextCursor: json['nextCursor'] as String?,
    );
  }

  @override
  Future<Certificate?> fetchCertificateByCourse(
    String courseId, {
    required String learnerId,
  }) async {
    final json = await _get(
      '/api/v1/certificates/by-course/${Uri.encodeComponent(courseId)}',
    );
    final value = json['certificate'];
    return value == null
        ? null
        : _decodeCertificate(value as Map<String, Object?>);
  }

  @override
  Future<Certificate> fetchCertificateById(
    String certificateId, {
    required String learnerId,
  }) async => _decodeCertificate(
    await _get('/api/v1/certificates/${Uri.encodeComponent(certificateId)}'),
  );

  @override
  Future<CertificateEligibility> checkEligibility(
    String courseId, {
    required String learnerId,
  }) async => _decodeEligibility(
    await _get(
      '/api/v1/certificate-eligibility/${Uri.encodeComponent(courseId)}',
    ),
  );

  @override
  Future<Certificate> claimCertificate(
    String courseId, {
    required String learnerId,
    required String learnerName,
  }) async => _decodeCertificate(
    await _post('/api/v1/certificate-issuances', body: {'courseId': courseId}),
  );

  @override
  Future<CertificateVerificationInfo> verifyCredential(
    String credentialId,
  ) async => _decodeVerification(
    await _get(
      '/api/v1/public/credentials/${Uri.encodeComponent(credentialId)}',
      authenticated: false,
    ),
  );

  Future<Map<String, Object?>> _get(
    String path, {
    Map<String, Object?> query = const {},
    bool authenticated = true,
  }) async => switch (await _client.get(
    path,
    query: query,
    authenticated: authenticated,
  )) {
    Success(value: final value) => value,
    Failure(failure: final failure) => throw CertificateDataException(
      CertificateDataErrorKind.network,
      failure.message,
    ),
  };

  Future<Map<String, Object?>> _post(
    String path, {
    Map<String, Object?> body = const {},
  }) async => switch (await _client.post(path, body: body)) {
    Success(value: final value) => value,
    Failure(failure: final failure) => throw CertificateDataException(
      CertificateDataErrorKind.network,
      failure.message,
    ),
  };
}

Certificate _decodeCertificate(Map<String, Object?> json) => Certificate(
  id: json['id']! as String,
  credentialId: json['credentialId']! as String,
  courseId: json['courseId']! as String,
  courseTitle: json['courseTitle']! as String,
  learnerId: json['learnerId']! as String,
  learnerName: json['learnerName']! as String,
  issueDate: DateTime.parse(json['issueDate']! as String).toUtc(),
  expiryDate: json['expiryDate'] == null
      ? null
      : DateTime.parse(json['expiryDate']! as String).toUtc(),
  status: CertificateStatus.values.byName(json['status']! as String),
  verificationUrl: json['verificationUrl']! as String,
  issuerName: json['issuerName']! as String,
  grade: json['grade'] as String?,
  revocationReason: json['revocationReason'] as String?,
  metadata: json['metadata'] as Map<String, Object?>? ?? const {},
);

CertificateEligibility _decodeEligibility(Map<String, Object?> json) =>
    CertificateEligibility(
      courseId: json['courseId']! as String,
      status: EligibilityStatus.values.byName(json['status']! as String),
      requiredPolicy: _decodePolicy(
        json['requiredPolicy']! as Map<String, Object?>,
      ),
      courseCompletionFraction: (json['courseCompletionFraction']! as num)
          .toDouble(),
      assessmentsPassed: json['assessmentsPassed']! as int,
      assessmentsRequired: json['assessmentsRequired']! as int,
      missingRequirements: (json['missingRequirements']! as List<Object?>)
          .cast<String>(),
    );

AccessPolicy _decodePolicy(Map<String, Object?> json) =>
    switch (json['type']! as String) {
      'free' => const AccessPolicy.free(),
      'premium' => AccessPolicy.premium(
        requiredTier: json['requiredTier'] as String?,
      ),
      _ => const AccessPolicy.unavailable(),
    };

CertificateVerificationInfo _decodeVerification(Map<String, Object?> json) =>
    CertificateVerificationInfo(
      credentialId: json['credentialId']! as String,
      isValid: json['isValid']! as bool,
      verificationTimestamp: DateTime.parse(
        json['verificationTimestamp']! as String,
      ).toUtc(),
      certificate: json['certificate'] == null
          ? null
          : _decodeCertificate(json['certificate']! as Map<String, Object?>),
      message: json['message'] as String?,
    );
