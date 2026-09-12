import 'package:learning_platform/core/errors/result.dart';
import 'package:learning_platform/features/content_catalog/domain/catalog_query.dart';
import 'package:learning_platform/features/content_catalog/domain/course.dart';
import 'package:learning_platform/features/content_catalog/domain/home_feed.dart';

abstract interface class CatalogRepository {
  Future<Result<HomeFeed>> getHomeFeed({bool forceRefresh = false});
  Future<Result<CursorPage<CourseSummary>>> getCourses(CatalogQuery query);
  Future<Result<Course>> getCourse(String courseId);
  Future<Result<List<CourseCategory>>> getCategories();
  Future<Result<Set<String>>> getBookmarkedIds();
  Future<Result<void>> setBookmarked(
    String courseId, {
    required bool bookmarked,
  });
  Future<Result<List<CourseSummary>>> getBookmarkedCourses();
  Future<Result<void>> recordRecentlyViewed(String courseId);
  Future<Result<List<CourseSummary>>> getRecentlyViewed({int limit = 10});
}
