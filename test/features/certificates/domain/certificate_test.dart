import 'package:flutter_test/flutter_test.dart';
import 'package:learning_platform/features/certificates/domain/certificate.dart';
import 'package:learning_platform/features/certificates/domain/certificate_eligibility.dart';
import 'package:learning_platform/features/entitlements/domain/access_policy.dart';

void main() {
  group('Certificate Domain Models', () {
    test('Certificate status and getters work correctly', () {
      final now = DateTime.now().toUtc();
      final cert = Certificate(
        id: 'cert-1',
        credentialId: 'CERT-2026-001',
        courseId: 'course-1',
        courseTitle: 'Clean Architecture',
        learnerId: 'learner-1',
        learnerName: 'Alex Mercer',
        issueDate: now,
        status: CertificateStatus.issued,
        verificationUrl:
            'https://verify.learningplatform.com/credentials/CERT-2026-001',
        issuerName: 'Academy of Engineering',
        grade: 'Pass with Distinction',
      );

      expect(cert.isIssued, isTrue);
      expect(cert.isRevoked, isFalse);
      expect(cert.isUnavailable, isFalse);

      final revoked = cert.copyWith(
        status: CertificateStatus.revoked,
        revocationReason: 'Academic dishonesty',
      );
      expect(revoked.isRevoked, isTrue);
      expect(revoked.revocationReason, 'Academic dishonesty');
    });

    test('CertificateEligibility evaluates conditions properly', () {
      const eligible = CertificateEligibility(
        courseId: 'course-1',
        status: EligibilityStatus.eligible,
        requiredPolicy: AccessPolicy.free(),
        courseCompletionFraction: 1.0,
        assessmentsPassed: 1,
        assessmentsRequired: 1,
        missingRequirements: [],
      );
      expect(eligible.isEligible, isTrue);
      expect(eligible.isCourseComplete, isTrue);
      expect(eligible.areAssessmentsComplete, isTrue);

      const incompleteCourse = CertificateEligibility(
        courseId: 'course-1',
        status: EligibilityStatus.ineligibleCourseIncomplete,
        requiredPolicy: AccessPolicy.free(),
        courseCompletionFraction: 0.75,
        assessmentsPassed: 1,
        assessmentsRequired: 1,
        missingRequirements: ['Complete all course lessons'],
      );
      expect(incompleteCourse.isEligible, isFalse);
      expect(incompleteCourse.isCourseComplete, isFalse);
      expect(incompleteCourse.missingRequirements.length, 1);
    });

    test('CertificateVerificationInfo models verification outcome', () {
      final now = DateTime.now().toUtc();
      final validInfo = CertificateVerificationInfo(
        credentialId: 'CERT-2026-001',
        isValid: true,
        verificationTimestamp: now,
        message: 'Verified authentic',
      );
      expect(validInfo.isValid, isTrue);

      final invalidInfo = CertificateVerificationInfo(
        credentialId: 'CERT-INVALID',
        isValid: false,
        verificationTimestamp: now,
        message: 'Not found',
      );
      expect(invalidInfo.isValid, isFalse);
    });
  });
}
