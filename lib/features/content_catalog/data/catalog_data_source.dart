import 'package:learning_platform/features/content_catalog/domain/catalog_query.dart';
import 'package:learning_platform/features/content_catalog/domain/course.dart';
import 'package:learning_platform/features/content_catalog/domain/home_feed.dart';

enum CatalogDataErrorKind { offline, timeout, server, notFound }

final class CatalogDataException implements Exception {
  const CatalogDataException(this.kind, this.message);
  final CatalogDataErrorKind kind;
  final String message;
}

abstract interface class CatalogDataSource {
  Future<HomeFeed> fetchHomeFeed();
  Future<CursorPage<CourseSummary>> fetchCourses(CatalogQuery query);
  Future<Course> fetchCourse(String courseId);
  Future<List<CourseSummary>> fetchCoursesByIds(List<String> courseIds);
  Future<List<CourseCategory>> fetchCategories();
  Future<Set<String>> fetchBookmarkedIds();
  Future<void> setBookmarked(String courseId, {required bool bookmarked});
  Future<List<String>> fetchRecentlyViewedIds({required int limit});
  Future<void> recordRecentlyViewed(String courseId);
}
