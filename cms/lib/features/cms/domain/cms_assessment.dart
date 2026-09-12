import 'package:flutter/foundation.dart';

@immutable
final class CmsQuestionOption {
  const CmsQuestionOption({
    required this.id,
    required this.text,
    this.hint,
    required this.position,
  });

  factory CmsQuestionOption.fromJson(Map<String, Object?> json) =>
      CmsQuestionOption(
        id: json['id'] as String? ?? '',
        text: json['text'] as String? ?? '',
        hint: json['hint'] as String?,
        position: (json['position'] as num?)?.toInt() ?? 1,
      );

  final String id;
  final String text;
  final String? hint;
  final int position;

  Map<String, Object?> toJson() => {
    'id': id,
    'text': text,
    'hint': hint,
    'position': position,
  };
}

@immutable
final class CmsQuestionDetail {
  const CmsQuestionDetail({
    required this.id,
    required this.assessmentId,
    required this.type,
    required this.prompt,
    required this.points,
    required this.position,
    this.explanation,
    required this.settings,
    required this.options,
    required this.gradingData,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CmsQuestionDetail.fromJson(Map<String, Object?> json) {
    final rawOptions = json['options'] as List<Object?>? ?? const [];
    return CmsQuestionDetail(
      id: json['id'] as String? ?? '',
      assessmentId: json['assessmentId'] as String? ?? '',
      type: json['type'] as String? ?? 'singleChoice',
      prompt: json['prompt'] as String? ?? '',
      points: (json['points'] as num?)?.toInt() ?? 1,
      position: (json['position'] as num?)?.toInt() ?? 1,
      explanation: json['explanation'] as String?,
      settings: (json['settings'] as Map<String, Object?>?) ?? const {},
      options: rawOptions
          .whereType<Map<String, Object?>>()
          .map(CmsQuestionOption.fromJson)
          .toList(),
      gradingData: (json['gradingData'] as Map<String, Object?>?) ?? const {},
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  final String id;
  final String assessmentId;
  final String type;
  final String prompt;
  final int points;
  final int position;
  final String? explanation;
  final Map<String, Object?> settings;
  final List<CmsQuestionOption> options;
  final Map<String, Object?> gradingData;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isSingleChoice => type == 'singleChoice';
  bool get isMultipleChoice => type == 'multipleChoice';
  bool get isTrueFalse => type == 'trueFalse';
  bool get isTextResponse => type == 'textResponse';
}

@immutable
final class CmsAssessmentDetail {
  const CmsAssessmentDetail({
    required this.id,
    required this.courseId,
    required this.title,
    required this.description,
    required this.instructions,
    required this.passingPercentage,
    this.timeLimitSeconds,
    required this.maxAttempts,
    required this.requiredForCertificate,
    required this.protectionPolicy,
    required this.status,
    required this.questions,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CmsAssessmentDetail.fromJson(Map<String, Object?> json) {
    final rawInst = json['instructions'] as List<Object?>? ?? const [];
    final rawQuestions = json['questions'] as List<Object?>? ?? const [];
    return CmsAssessmentDetail(
      id: json['id'] as String? ?? '',
      courseId: json['courseId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      instructions: rawInst.whereType<String>().toList(),
      passingPercentage: (json['passingPercentage'] as num?)?.toInt() ?? 70,
      timeLimitSeconds: (json['timeLimitSeconds'] as num?)?.toInt(),
      maxAttempts: (json['maxAttempts'] as num?)?.toInt() ?? 3,
      requiredForCertificate: json['requiredForCertificate'] as bool? ?? true,
      protectionPolicy:
          json['protectionPolicy'] as String? ?? 'blockCaptureWhereSupported',
      status: json['status'] as String? ?? 'draft',
      questions: rawQuestions
          .whereType<Map<String, Object?>>()
          .map(CmsQuestionDetail.fromJson)
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
  final String description;
  final List<String> instructions;
  final int passingPercentage;
  final int? timeLimitSeconds;
  final int maxAttempts;
  final bool requiredForCertificate;
  final String protectionPolicy;
  final String status;
  final List<CmsQuestionDetail> questions;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isPublished => status == 'published';
  int get totalPoints => questions.fold(0, (sum, q) => sum + q.points);
}
