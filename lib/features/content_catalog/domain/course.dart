import 'package:learning_platform/features/content_protection/domain/content_protection_policy.dart';
import 'package:learning_platform/features/entitlements/domain/access_policy.dart';

enum CourseLevel { beginner, intermediate, advanced, allLevels }

final class Instructor {
  const Instructor({required this.id, required this.name, this.headline});
  final String id;
  final String name;
  final String? headline;
}

final class CourseCategory {
  const CourseCategory({
    required this.id,
    required this.name,
    required this.iconName,
    this.isSubject = false,
  });
  final String id;
  final String name;
  final String iconName;
  final bool isSubject;
}

final class CourseSummary {
  const CourseSummary({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.instructors,
    required this.categoryIds,
    required this.level,
    required this.policy,
    required this.languageCode,
    required this.rating,
    required this.ratingCount,
    required this.duration,
    required this.lessonCount,
    required this.publishedAt,
    required this.tags,
    this.progress,
    this.protectionPolicy,
    this.curriculumId,
    this.standardId,
    this.streamId,
    this.subjectId,
    this.coverReference,
  });

  final String id;
  final String title;
  final String subtitle;
  final String? curriculumId;
  final String? standardId;
  final String? streamId;
  final String? subjectId;
  final String? coverReference;
  final List<Instructor> instructors;
  final Set<String> categoryIds;
  final CourseLevel level;
  final AccessPolicy policy;
  final String languageCode;
  final double rating;
  final int ratingCount;
  final Duration duration;
  final int lessonCount;
  final DateTime publishedAt;
  final Set<String> tags;
  final double? progress;
  final ContentProtectionPolicy? protectionPolicy;

  AccessPolicy get effectivePolicy => policy;

  ContentProtectionPolicy get effectiveProtectionPolicy =>
      protectionPolicy ??
      (policy.isPremium
          ? ContentProtectionPolicy.blockCaptureWhereSupported
          : ContentProtectionPolicy.none);
}

final class Course {
  const Course({
    required this.summary,
    required this.description,
    required this.learningOutcomes,
    required this.prerequisites,
    required this.modules,
    required this.updatedAt,
  });

  final CourseSummary summary;
  final String description;
  final List<String> learningOutcomes;
  final List<String> prerequisites;
  final List<CourseModule> modules;
  final DateTime updatedAt;
}

final class CourseModule {
  const CourseModule({
    required this.id,
    required this.title,
    required this.position,
    required this.lessons,
    this.policy,
  });

  final String id;
  final String title;
  final int position;
  final List<Lesson> lessons;
  final AccessPolicy? policy;
}

final class Lesson {
  const Lesson({
    this.contentItems = const [],
    this.hasContentItems = false,
    required this.id,
    required this.title,
    required this.position,
    required this.estimatedDuration,
    required this.content,
    required this.isPreview,
    this.policy,
    this.protectionPolicy,
  });

  final String id;
  final String title;
  final int position;
  final Duration estimatedDuration;
  final LessonContent content;
  final List<LessonContentItem> contentItems;
  final bool hasContentItems;
  final bool isPreview;
  final AccessPolicy? policy;
  final ContentProtectionPolicy? protectionPolicy;

  AccessPolicy get effectivePolicy =>
      policy ??
      (isPreview ? const AccessPolicy.preview() : const AccessPolicy.inherit());

  ContentProtectionPolicy resolveProtectionPolicy(
    ContentProtectionPolicy coursePolicy,
  ) {
    if (protectionPolicy != null) return protectionPolicy!;
    if (isPreview) return ContentProtectionPolicy.none;
    return coursePolicy;
  }
}

sealed class LessonContent {
  const LessonContent();
}

final class LessonContentItem {
  const LessonContentItem({
    required this.id,
    required this.type,
    required this.title,
    required this.position,
    this.referenceId,
    this.assessmentId,
    this.body,
  });
  factory LessonContentItem.fromJson(Map<String, Object?> json) =>
      LessonContentItem(
        id: json['id']! as String,
        type: json['type']! as String,
        title: json['title'] as String? ?? '',
        position: json['position']! as int,
        referenceId: json['referenceId'] as String?,
        assessmentId: json['assessmentId'] as String?,
        body: json['body'] as String?,
      );
  final String id;
  final String type;
  final String title;
  final int position;
  final String? referenceId;
  final String? assessmentId;
  final String? body;
}

final class VideoLessonContent extends LessonContent {
  const VideoLessonContent({
    required this.assetId,
    this.transcriptAvailable = false,
  });
  final String assetId;
  final bool transcriptAvailable;
}

final class ArticleLessonContent extends LessonContent {
  const ArticleLessonContent({required this.documentId});
  final String documentId;
}

final class ResourceLessonContent extends LessonContent {
  const ResourceLessonContent({
    required this.resourceId,
    required this.fileType,
  });
  final String resourceId;
  final String fileType;
}

final class QuizLessonContent extends LessonContent {
  const QuizLessonContent({
    required this.assessmentId,
    required this.questionCount,
  });
  final String assessmentId;
  final int questionCount;
}

final class AssignmentLessonContent extends LessonContent {
  const AssignmentLessonContent({
    required this.assignmentId,
    this.requiresSubmission = true,
  });
  final String assignmentId;
  final bool requiresSubmission;
}

final class LiveClassLessonContent extends LessonContent {
  const LiveClassLessonContent({required this.eventId, required this.startsAt});
  final String eventId;
  final DateTime startsAt;
}

final class ProjectLessonContent extends LessonContent {
  const ProjectLessonContent({
    required this.projectId,
    required this.briefDocumentId,
  });
  final String projectId;
  final String briefDocumentId;
}
