import 'package:flutter/foundation.dart';

@immutable
final class CmsCourseSummary {
  const CmsCourseSummary({
    this.academic = const {},
    required this.id,
    required this.title,
    required this.subtitle,
    required this.level,
    required this.policyKind,
    required this.status,
    required this.moduleCount,
    required this.lessonCount,
    required this.enrollmentCount,
    required this.durationSeconds,
    required this.createdAt,
    this.publishedAt,
  });

  factory CmsCourseSummary.fromJson(
    Map<String, Object?> json,
  ) => CmsCourseSummary(
    academic: {
      for (final k in ['curriculumId', 'standardId', 'streamId', 'subjectId'])
        k: json[k],
    },
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    subtitle: json['subtitle'] as String? ?? '',
    level: json['level'] as String? ?? 'allLevels',
    policyKind: json['policyKind'] as String? ?? 'free',
    status: json['status'] as String? ?? 'draft',
    moduleCount: (json['moduleCount'] as num?)?.toInt() ?? 0,
    lessonCount: (json['lessonCount'] as num?)?.toInt() ?? 0,
    enrollmentCount: (json['enrollmentCount'] as num?)?.toInt() ?? 0,
    durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    publishedAt: DateTime.tryParse(json['publishedAt'] as String? ?? ''),
  );

  final String id;
  final Map<String, Object?> academic;
  final String title;
  final String subtitle;
  final String level;
  final String policyKind;
  final String status;
  final int moduleCount;
  final int lessonCount;
  final int enrollmentCount;
  final int durationSeconds;
  final DateTime createdAt;
  final DateTime? publishedAt;

  bool get isPublished => status == 'published';
  bool get isDraft => status == 'draft';
  bool get isArchived => status == 'archived';
  bool get isUnavailable => status == 'unavailable';
}
