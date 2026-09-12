import 'package:learning_platform/core/errors/app_failure.dart';
import 'package:learning_platform/features/content_catalog/domain/course.dart';

enum HomeSectionKind {
  continueLearning,
  recommended,
  trending,
  newReleases,
  popularCategories,
  recentlyViewed,
  contextualRecommendation,
}

sealed class HomeSectionContent {
  const HomeSectionContent();
}

final class CourseSectionContent extends HomeSectionContent {
  const CourseSectionContent(this.courses);
  final List<CourseSummary> courses;
}

final class CategorySectionContent extends HomeSectionContent {
  const CategorySectionContent(this.categories);
  final List<CourseCategory> categories;
}

final class HomeFeedSection {
  const HomeFeedSection({
    required this.id,
    required this.kind,
    required this.title,
    required this.content,
    this.failure,
  });

  final String id;
  final HomeSectionKind kind;
  final String title;
  final HomeSectionContent content;
  final AppFailure? failure;
}

final class HomeFeed {
  const HomeFeed({
    required this.sections,
    required this.isFromCache,
    required this.updatedAt,
  });
  final List<HomeFeedSection> sections;
  final bool isFromCache;
  final DateTime updatedAt;
}
