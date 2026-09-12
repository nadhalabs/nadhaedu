import 'package:flutter/foundation.dart';

@immutable
final class CmsCategory {
  const CmsCategory({
    required this.id,
    required this.name,
    required this.iconName,
  });

  factory CmsCategory.fromJson(Map<String, Object?> json) => CmsCategory(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    iconName: json['iconName'] as String? ?? 'school',
  );

  final String id;
  final String name;
  final String iconName;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'iconName': iconName,
  };
}

@immutable
final class CmsLessonDetail {
  const CmsLessonDetail({
    required this.id,
    required this.moduleId,
    required this.title,
    required this.position,
    required this.durationSeconds,
    required this.contentType,
    required this.contentRef,
    required this.isPreview,
    required this.isDownloadable,
    required this.policyKind,
    required this.protectionPolicy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CmsLessonDetail.fromJson(
    Map<String, Object?> json,
  ) => CmsLessonDetail(
    id: json['id'] as String? ?? '',
    moduleId: json['moduleId'] as String? ?? '',
    title: json['title'] as String? ?? '',
    position: (json['position'] as num?)?.toInt() ?? 1,
    durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
    contentType: json['contentType'] as String? ?? 'video',
    contentRef: json['contentRef'] as String? ?? '',
    isPreview: json['isPreview'] as bool? ?? false,
    isDownloadable: json['isDownloadable'] as bool? ?? true,
    policyKind: json['policyKind'] as String? ?? 'inherit',
    protectionPolicy:
        json['protectionPolicy'] as String? ?? 'blockCaptureWhereSupported',
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    updatedAt:
        DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
  );

  final String id;
  final String moduleId;
  final String title;
  final int position;
  final int durationSeconds;
  final String contentType;
  final String contentRef;
  final bool isPreview;
  final bool isDownloadable;
  final String policyKind;
  final String protectionPolicy;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get formattedDuration {
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    if (minutes == 0) return '${seconds}s';
    return '${minutes}m ${seconds}s';
  }
}

@immutable
final class CmsModuleDetail {
  const CmsModuleDetail({
    required this.id,
    required this.courseId,
    required this.title,
    required this.position,
    required this.policyKind,
    required this.lessons,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CmsModuleDetail.fromJson(Map<String, Object?> json) {
    final rawLessons = json['lessons'] as List<Object?>? ?? const [];
    return CmsModuleDetail(
      id: json['id'] as String? ?? '',
      courseId: json['courseId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      position: (json['position'] as num?)?.toInt() ?? 1,
      policyKind: json['policyKind'] as String? ?? 'inherit',
      lessons: rawLessons
          .whereType<Map<String, Object?>>()
          .map(CmsLessonDetail.fromJson)
          .toList(),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  final String id;
  final String courseId;
  final String title;
  final int position;
  final String policyKind;
  final List<CmsLessonDetail> lessons;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get totalDurationSeconds =>
      lessons.fold(0, (sum, l) => sum + l.durationSeconds);
}

@immutable
final class CmsValidationItem {
  const CmsValidationItem({
    required this.code,
    required this.message,
    required this.severity,
    this.field,
  });

  factory CmsValidationItem.fromJson(Map<String, Object?> json) =>
      CmsValidationItem(
        code: json['code'] as String? ?? '',
        message: json['message'] as String? ?? '',
        severity: json['severity'] as String? ?? 'error',
        field: json['field'] as String?,
      );

  final String code;
  final String message;
  final String severity;
  final String? field;

  bool get isError => severity == 'error';
  bool get isWarning => severity == 'warning';
}

@immutable
final class CmsCourseValidation {
  const CmsCourseValidation({
    required this.isValid,
    required this.canPublish,
    required this.errors,
    required this.warnings,
  });

  factory CmsCourseValidation.fromJson(Map<String, Object?> json) {
    final rawErrors = json['errors'] as List<Object?>? ?? const [];
    final rawWarnings = json['warnings'] as List<Object?>? ?? const [];
    return CmsCourseValidation(
      isValid: json['isValid'] as bool? ?? false,
      canPublish: json['canPublish'] as bool? ?? false,
      errors: rawErrors
          .whereType<Map<String, Object?>>()
          .map(CmsValidationItem.fromJson)
          .toList(),
      warnings: rawWarnings
          .whereType<Map<String, Object?>>()
          .map(CmsValidationItem.fromJson)
          .toList(),
    );
  }

  static const empty = CmsCourseValidation(
    isValid: true,
    canPublish: true,
    errors: [],
    warnings: [],
  );

  final bool isValid;
  final bool canPublish;
  final List<CmsValidationItem> errors;
  final List<CmsValidationItem> warnings;
}

@immutable
final class CmsAssessmentSummary {
  const CmsAssessmentSummary({
    required this.id,
    required this.courseId,
    required this.title,
    required this.description,
    required this.passingPercentage,
    this.timeLimitSeconds,
    required this.maxAttempts,
    required this.requiredForCertificate,
    required this.protectionPolicy,
    required this.status,
    required this.questionCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CmsAssessmentSummary.fromJson(
    Map<String, Object?> json,
  ) => CmsAssessmentSummary(
    id: json['id'] as String? ?? '',
    courseId: json['courseId'] as String? ?? '',
    title: json['title'] as String? ?? '',
    description: json['description'] as String? ?? '',
    passingPercentage: (json['passingPercentage'] as num?)?.toInt() ?? 70,
    timeLimitSeconds: (json['timeLimitSeconds'] as num?)?.toInt(),
    maxAttempts: (json['maxAttempts'] as num?)?.toInt() ?? 3,
    requiredForCertificate: json['requiredForCertificate'] as bool? ?? true,
    protectionPolicy:
        json['protectionPolicy'] as String? ?? 'blockCaptureWhereSupported',
    status: json['status'] as String? ?? 'draft',
    questionCount: (json['questionCount'] as num?)?.toInt() ?? 0,
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    updatedAt:
        DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
  );

  final String id;
  final String courseId;
  final String title;
  final String description;
  final int passingPercentage;
  final int? timeLimitSeconds;
  final int maxAttempts;
  final bool requiredForCertificate;
  final String protectionPolicy;
  final String status;
  final int questionCount;
  final DateTime createdAt;
  final DateTime updatedAt;
}

@immutable
final class CmsCourseDetail {
  const CmsCourseDetail({
    this.academic = const {},
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.level,
    required this.languageCode,
    required this.policyKind,
    required this.protectionPolicy,
    this.requiredTier,
    this.requiredBundleId,
    required this.status,
    this.publishedAt,
    required this.rating,
    required this.ratingCount,
    required this.durationSeconds,
    required this.learningOutcomes,
    required this.prerequisites,
    required this.categories,
    required this.tags,
    required this.modules,
    required this.assessments,
    required this.validation,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CmsCourseDetail.fromJson(Map<String, Object?> json) {
    final rawCats = json['categories'] as List<Object?>? ?? const [];
    final rawTags = json['tags'] as List<Object?>? ?? const [];
    final rawOutcomes = json['learningOutcomes'] as List<Object?>? ?? const [];
    final rawPrereqs = json['prerequisites'] as List<Object?>? ?? const [];
    final rawModules = json['modules'] as List<Object?>? ?? const [];
    final rawAssessments = json['assessments'] as List<Object?>? ?? const [];
    final rawVal = json['validation'] as Map<String, Object?>? ?? const {};

    return CmsCourseDetail(
      academic: {
        for (final k in ['curriculumId', 'standardId', 'streamId', 'subjectId'])
          k: json[k],
      },
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      description: json['description'] as String? ?? '',
      level: json['level'] as String? ?? 'allLevels',
      languageCode: json['languageCode'] as String? ?? 'en',
      policyKind: json['policyKind'] as String? ?? 'free',
      protectionPolicy:
          json['protectionPolicy'] as String? ?? 'blockCaptureWhereSupported',
      requiredTier: json['requiredTier'] as String?,
      requiredBundleId: json['requiredBundleId'] as String?,
      status: json['status'] as String? ?? 'draft',
      publishedAt: DateTime.tryParse(json['publishedAt'] as String? ?? ''),
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      ratingCount: (json['ratingCount'] as num?)?.toInt() ?? 0,
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      learningOutcomes: rawOutcomes.whereType<String>().toList(),
      prerequisites: rawPrereqs.whereType<String>().toList(),
      categories: rawCats
          .whereType<Map<String, Object?>>()
          .map(CmsCategory.fromJson)
          .toList(),
      tags: rawTags.whereType<String>().toList(),
      modules: rawModules
          .whereType<Map<String, Object?>>()
          .map(CmsModuleDetail.fromJson)
          .toList(),
      assessments: rawAssessments
          .whereType<Map<String, Object?>>()
          .map(CmsAssessmentSummary.fromJson)
          .toList(),
      validation: CmsCourseValidation.fromJson(rawVal),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  final String id;
  final String title;
  final String subtitle;
  final String description;
  final String level;
  final String languageCode;
  final String policyKind;
  final String protectionPolicy;
  final String? requiredTier;
  final String? requiredBundleId;
  final String status;
  final DateTime? publishedAt;
  final double rating;
  final int ratingCount;
  final int durationSeconds;
  final List<String> learningOutcomes;
  final List<String> prerequisites;
  final List<CmsCategory> categories;
  final List<String> tags;
  final List<CmsModuleDetail> modules;
  final List<CmsAssessmentSummary> assessments;
  final CmsCourseValidation validation;
  final Map<String, Object?> academic;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isPublished => status == 'published';
  bool get isDraft => status == 'draft';
  bool get isArchived => status == 'archived';

  int get totalLessons => modules.fold(0, (sum, m) => sum + m.lessons.length);
}
