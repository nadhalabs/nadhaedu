import 'package:learning_platform/features/content_catalog/data/catalog_data_source.dart';
import 'package:learning_platform/features/content_catalog/domain/catalog_query.dart';
import 'package:learning_platform/features/content_catalog/domain/course.dart';
import 'package:learning_platform/features/content_catalog/domain/home_feed.dart';

final class UnconfiguredCatalogDataSource implements CatalogDataSource {
  const UnconfiguredCatalogDataSource();

  Never _unavailable() => throw const CatalogDataException(
    CatalogDataErrorKind.server,
    'Content service is not configured.',
  );

  @override
  Future<HomeFeed> fetchHomeFeed() async => _unavailable();
  @override
  Future<CursorPage<CourseSummary>> fetchCourses(CatalogQuery query) async =>
      _unavailable();
  @override
  Future<Course> fetchCourse(String courseId) async => _unavailable();
  @override
  Future<List<CourseSummary>> fetchCoursesByIds(List<String> courseIds) async =>
      _unavailable();
  @override
  Future<List<CourseCategory>> fetchCategories() async => _unavailable();
  @override
  Future<Set<String>> fetchBookmarkedIds() async => _unavailable();
  @override
  Future<void> setBookmarked(
    String courseId, {
    required bool bookmarked,
  }) async => _unavailable();
  @override
  Future<List<String>> fetchRecentlyViewedIds({required int limit}) async =>
      _unavailable();
  @override
  Future<void> recordRecentlyViewed(String courseId) async => _unavailable();
}
