import 'package:learning_platform/features/entitlements/domain/access_policy.dart';

enum EligibilityStatus {
  eligible,
  alreadyIssued,
  ineligibleCourseIncomplete,
  ineligibleAssessmentFailed,
  ineligibleEntitlementRequired,
  unavailable,
}

final class CertificateEligibility {
  const CertificateEligibility({
    required this.courseId,
    required this.status,
    required this.requiredPolicy,
    required this.courseCompletionFraction,
    required this.assessmentsPassed,
    required this.assessmentsRequired,
    required this.missingRequirements,
  });

  final String courseId;
  final EligibilityStatus status;
  final AccessPolicy requiredPolicy;
  final double courseCompletionFraction;
  final int assessmentsPassed;
  final int assessmentsRequired;
  final List<String> missingRequirements;

  bool get isEligible => status == EligibilityStatus.eligible;
  bool get isAlreadyIssued => status == EligibilityStatus.alreadyIssued;
  bool get isCourseComplete => courseCompletionFraction >= 1.0;
  bool get areAssessmentsComplete =>
      assessmentsRequired == 0 || assessmentsPassed >= assessmentsRequired;
}
