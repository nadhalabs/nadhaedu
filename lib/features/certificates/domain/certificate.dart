enum CertificateStatus { issued, revoked, unavailable, pendingEligibility }

final class Certificate {
  const Certificate({
    required this.id,
    required this.credentialId,
    required this.courseId,
    required this.courseTitle,
    required this.learnerId,
    required this.learnerName,
    required this.issueDate,
    required this.status,
    required this.verificationUrl,
    required this.issuerName,
    this.expiryDate,
    this.grade,
    this.revocationReason,
    this.metadata = const {},
  });

  final String id;
  final String credentialId;
  final String courseId;
  final String courseTitle;
  final String learnerId;
  final String learnerName;
  final DateTime issueDate;
  final DateTime? expiryDate;
  final CertificateStatus status;
  final String verificationUrl;
  final String issuerName;
  final String? grade;
  final String? revocationReason;
  final Map<String, Object?> metadata;

  bool get isIssued => status == CertificateStatus.issued;
  bool get isRevoked => status == CertificateStatus.revoked;
  bool get isUnavailable => status == CertificateStatus.unavailable;

  Certificate copyWith({
    String? id,
    String? credentialId,
    String? courseId,
    String? courseTitle,
    String? learnerId,
    String? learnerName,
    DateTime? issueDate,
    DateTime? expiryDate,
    CertificateStatus? status,
    String? verificationUrl,
    String? issuerName,
    String? grade,
    String? revocationReason,
    Map<String, Object?>? metadata,
  }) => Certificate(
    id: id ?? this.id,
    credentialId: credentialId ?? this.credentialId,
    courseId: courseId ?? this.courseId,
    courseTitle: courseTitle ?? this.courseTitle,
    learnerId: learnerId ?? this.learnerId,
    learnerName: learnerName ?? this.learnerName,
    issueDate: issueDate ?? this.issueDate,
    expiryDate: expiryDate ?? this.expiryDate,
    status: status ?? this.status,
    verificationUrl: verificationUrl ?? this.verificationUrl,
    issuerName: issuerName ?? this.issuerName,
    grade: grade ?? this.grade,
    revocationReason: revocationReason ?? this.revocationReason,
    metadata: metadata ?? this.metadata,
  );
}

final class CertificateVerificationInfo {
  const CertificateVerificationInfo({
    required this.credentialId,
    required this.isValid,
    required this.verificationTimestamp,
    this.certificate,
    this.message,
  });

  final String credentialId;
  final bool isValid;
  final DateTime verificationTimestamp;
  final Certificate? certificate;
  final String? message;
}
