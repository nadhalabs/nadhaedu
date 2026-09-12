import 'dart:math';

import 'package:learning_platform/features/assessments/data/assessment_data_source.dart';
import 'package:learning_platform/features/certificates/data/certificate_data_source.dart';
import 'package:learning_platform/features/certificates/domain/certificate.dart';
import 'package:learning_platform/features/certificates/domain/certificate_eligibility.dart';
import 'package:learning_platform/features/certificates/domain/certificate_page.dart';
import 'package:learning_platform/features/entitlements/data/entitlement_data_source.dart';
import 'package:learning_platform/features/entitlements/domain/access_policy.dart';
import 'package:learning_platform/features/entitlements/domain/entitlement_source.dart';
import 'package:learning_platform/features/learning_progress/data/learning_data_source.dart';

final class FoundationCertificateDataSource implements CertificateDataSource {
  FoundationCertificateDataSource({
    EntitlementDataSource? entitlementDataSource,
    LearningDataSource? learningDataSource,
    AssessmentDataSource? assessmentDataSource,
  }) : _entitlementDataSource = entitlementDataSource,
       _learningDataSource = learningDataSource,
       _assessmentDataSource = assessmentDataSource {
    _seedCertificates();
  }

  final EntitlementDataSource? _entitlementDataSource;
  final LearningDataSource? _learningDataSource;
  final AssessmentDataSource? _assessmentDataSource;

  final Map<String, Certificate> _certificatesById = {};
  final Map<String, Certificate> _certificatesByCredentialId = {};
  final Map<String, List<String>> _certificateIdsByLearner = {};

  void _seedCertificates() {
    // Seed an issued valid certificate
    final cert1 = Certificate(
      id: 'cert-101',
      credentialId: 'CERT-2026-98124',
      courseId: 'course-1',
      courseTitle: 'Modern Application Development',
      learnerId: 'dev-learner-id',
      learnerName: 'Alex Mercer',
      issueDate: DateTime.utc(2026, 2, 15),
      status: CertificateStatus.issued,
      verificationUrl:
          'https://verify.learningplatform.com/credentials/CERT-2026-98124',
      issuerName: 'Nadha Edu Institute of Technology',
      grade: 'Distinction (92%)',
      metadata: const {'accreditation': 'Global Learning Standards Board'},
    );

    // Seed a revoked certificate for testing verification
    final cert2 = Certificate(
      id: 'cert-102',
      credentialId: 'CERT-2026-REVOKED-01',
      courseId: 'course-2',
      courseTitle: 'Design Systems in Practice',
      learnerId: 'dev-learner-id',
      learnerName: 'Alex Mercer',
      issueDate: DateTime.utc(2026, 1, 10),
      status: CertificateStatus.revoked,
      verificationUrl:
          'https://verify.learningplatform.com/credentials/CERT-2026-REVOKED-01',
      issuerName: 'Nadha Edu Institute of Technology',
      revocationReason:
          'Credential superseded following academic integrity audit.',
      metadata: const {'auditId': 'AUDIT-8819'},
    );

    _storeCertificate(cert1);
    _storeCertificate(cert2);
  }

  void _storeCertificate(Certificate cert) {
    _certificatesById[cert.id] = cert;
    _certificatesByCredentialId[cert.credentialId] = cert;
    final list = _certificateIdsByLearner.putIfAbsent(cert.learnerId, () => []);
    if (!list.contains(cert.id)) {
      list.add(cert.id);
    }
  }

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
    final ids = _certificateIdsByLearner[learnerId] ?? const [];
    final boundedLimit = limit.clamp(1, 50);
    final start = cursor == null ? 0 : int.tryParse(cursor) ?? ids.length;
    final end = (start + boundedLimit).clamp(0, ids.length);
    return CertificatePage(
      items: [for (final id in ids.sublist(start, end)) ?_certificatesById[id]],
      nextCursor: end < ids.length ? '$end' : null,
    );
  }

  @override
  Future<Certificate?> fetchCertificateByCourse(
    String courseId, {
    required String learnerId,
  }) async {
    final ids = _certificateIdsByLearner[learnerId] ?? const [];
    for (final id in ids) {
      final cert = _certificatesById[id];
      if (cert != null && cert.courseId == courseId) {
        return cert;
      }
    }
    return null;
  }

  @override
  Future<Certificate> fetchCertificateById(
    String certificateId, {
    required String learnerId,
  }) async {
    final cert = _certificatesById[certificateId];
    if (cert == null || cert.learnerId != learnerId) {
      throw const CertificateDataException(
        CertificateDataErrorKind.notFound,
        'Certificate not found.',
      );
    }
    return cert;
  }

  @override
  Future<CertificateEligibility> checkEligibility(
    String courseId, {
    required String learnerId,
  }) async {
    // 1. Check if already issued
    final existing = await fetchCertificateByCourse(
      courseId,
      learnerId: learnerId,
    );
    if (existing != null && existing.isIssued) {
      return CertificateEligibility(
        courseId: courseId,
        status: EligibilityStatus.alreadyIssued,
        requiredPolicy: const AccessPolicy.free(),
        courseCompletionFraction: 1.0,
        assessmentsPassed: 1,
        assessmentsRequired: 1,
        missingRequirements: const [],
      );
    }

    if (_learningDataSource == null ||
        _assessmentDataSource == null ||
        _entitlementDataSource == null) {
      return CertificateEligibility(
        courseId: courseId,
        status: EligibilityStatus.unavailable,
        requiredPolicy: const AccessPolicy.unavailable(),
        courseCompletionFraction: 0,
        assessmentsPassed: 0,
        assessmentsRequired: 1,
        missingRequirements: const [
          'Authoritative eligibility services are unavailable.',
        ],
      );
    }

    // 2. Evaluate course progress (Server authoritative check)
    var progressFraction = 0.0;
    try {
      final progress = await _learningDataSource.fetchProgress(
        learnerId,
        courseId,
      );
      final completedCount = progress.lessons.values
          .where((l) => l.completed)
          .length;
      final totalCount = progress.lessons.isEmpty ? 1 : progress.lessons.length;
      progressFraction = (completedCount / totalCount).clamp(0.0, 1.0);
    } on Object {
      return _unavailableEligibility(courseId);
    }

    // 3. Evaluate assessment status
    var assessmentsPassed = 0;
    const assessmentsRequired = 1;
    try {
      final quizId = 'quiz-$courseId-4';
      final summary = await _assessmentDataSource.fetchAttemptSummary(
        quizId,
        learnerId: learnerId,
      );
      assessmentsPassed = summary.hasPassed ? 1 : 0;
    } on Object {
      return _unavailableEligibility(courseId);
    }

    // 4. Evaluate entitlement access policy for certificate
    var hasEntitlement = false;
    final policy = courseId == 'course-4'
        ? const AccessPolicy.premium(requiredTier: 'pro')
        : const AccessPolicy.free();

    if (policy.isPremium) {
      try {
        final entitlements = await _entitlementDataSource.fetchEntitlements(
          learnerId,
        );
        final now = DateTime.now().toUtc();
        hasEntitlement = entitlements.any((e) {
          if (!e.isUsableAt(now)) return false;
          if (e.source case SubscriptionEntitlementSource(tier: final tier)) {
            return tier == policy.requiredTier;
          }
          return false;
        });
      } on Object {
        return _unavailableEligibility(courseId, policy: policy);
      }
    } else {
      hasEntitlement = true;
    }

    final missing = <String>[];
    if (progressFraction < 1.0) {
      missing.add(
        'Complete all course lessons (currently ${(progressFraction * 100).round()}%)',
      );
    }
    if (assessmentsPassed < assessmentsRequired) {
      missing.add('Pass the required module knowledge assessment');
    }
    if (!hasEntitlement) {
      missing.add(
        'Upgrade to a Pro subscription to unlock verified certificates',
      );
    }

    EligibilityStatus status;
    if (progressFraction < 1.0) {
      status = EligibilityStatus.ineligibleCourseIncomplete;
    } else if (assessmentsPassed < assessmentsRequired) {
      status = EligibilityStatus.ineligibleAssessmentFailed;
    } else if (!hasEntitlement) {
      status = EligibilityStatus.ineligibleEntitlementRequired;
    } else {
      status = EligibilityStatus.eligible;
    }

    return CertificateEligibility(
      courseId: courseId,
      status: status,
      requiredPolicy: policy,
      courseCompletionFraction: progressFraction,
      assessmentsPassed: assessmentsPassed,
      assessmentsRequired: assessmentsRequired,
      missingRequirements: List.unmodifiable(missing),
    );
  }

  CertificateEligibility _unavailableEligibility(
    String courseId, {
    AccessPolicy policy = const AccessPolicy.unavailable(),
  }) => CertificateEligibility(
    courseId: courseId,
    status: EligibilityStatus.unavailable,
    requiredPolicy: policy,
    courseCompletionFraction: 0,
    assessmentsPassed: 0,
    assessmentsRequired: 1,
    missingRequirements: const [
      'Authoritative eligibility could not be verified. Try again later.',
    ],
  );

  @override
  Future<Certificate> claimCertificate(
    String courseId, {
    required String learnerId,
    required String learnerName,
  }) async {
    final eligibility = await checkEligibility(courseId, learnerId: learnerId);
    if (!eligibility.isEligible && !eligibility.isAlreadyIssued) {
      throw CertificateDataException(
        CertificateDataErrorKind.ineligible,
        'Cannot claim certificate: ${eligibility.missingRequirements.join(', ')}',
      );
    }

    final existing = await fetchCertificateByCourse(
      courseId,
      learnerId: learnerId,
    );
    if (existing != null) {
      return existing;
    }

    final now = DateTime.now().toUtc();
    final credentialId = 'DEV-${_secureIdentifier()}';
    final certId = 'cert-$courseId-${now.millisecondsSinceEpoch}';

    final newCert = Certificate(
      id: certId,
      credentialId: credentialId,
      courseId: courseId,
      courseTitle: 'Course $courseId Completion',
      learnerId: learnerId,
      learnerName: learnerName,
      issueDate: now,
      status: CertificateStatus.issued,
      verificationUrl: '/verify/$credentialId',
      issuerName: 'Nadha Edu Academy of Continuing Education',
      grade: 'Passed',
    );

    _storeCertificate(newCert);
    return newCert;
  }

  String _secureIdentifier() {
    final random = Random.secure();
    return List<int>.generate(
      16,
      (_) => random.nextInt(256),
    ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  }

  @override
  Future<CertificateVerificationInfo> verifyCredential(
    String credentialId,
  ) async {
    final cert = _certificatesByCredentialId[credentialId];
    final now = DateTime.now().toUtc();

    if (cert == null) {
      return CertificateVerificationInfo(
        credentialId: credentialId,
        isValid: false,
        verificationTimestamp: now,
        message:
            'No certificate found matching credential identifier $credentialId.',
      );
    }

    if (cert.isRevoked) {
      return CertificateVerificationInfo(
        credentialId: credentialId,
        isValid: false,
        certificate: cert,
        verificationTimestamp: now,
        message:
            cert.revocationReason ??
            'This certificate has been revoked by the issuing institution.',
      );
    }

    if (cert.isUnavailable) {
      return CertificateVerificationInfo(
        credentialId: credentialId,
        isValid: false,
        certificate: cert,
        verificationTimestamp: now,
        message: 'This certificate credential is currently unavailable.',
      );
    }

    return CertificateVerificationInfo(
      credentialId: credentialId,
      isValid: true,
      certificate: cert,
      verificationTimestamp: now,
      message: 'Certificate is authentic and verified active.',
    );
  }
}
