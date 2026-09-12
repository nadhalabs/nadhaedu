import 'package:flutter/foundation.dart';
import 'package:nadha_cms/features/cms/domain/cms_role.dart';

@immutable
final class CmsUserSummary {
  const CmsUserSummary({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    required this.isActive,
    required this.onboardingComplete,
    required this.enrollmentCount,
    required this.createdAt,
  });

  factory CmsUserSummary.fromJson(Map<String, Object?> json) => CmsUserSummary(
    id: json['id'] as String? ?? '',
    email: json['email'] as String? ?? '',
    displayName: json['displayName'] as String? ?? '',
    role: CmsRole.fromValue(json['role'] as String? ?? 'learner'),
    isActive: json['isActive'] as bool? ?? true,
    onboardingComplete: json['onboardingComplete'] as bool? ?? false,
    enrollmentCount: (json['enrollmentCount'] as num?)?.toInt() ?? 0,
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
  );

  final String id;
  final String email;
  final String displayName;
  final CmsRole role;
  final bool isActive;
  final bool onboardingComplete;
  final int enrollmentCount;
  final DateTime createdAt;
}
