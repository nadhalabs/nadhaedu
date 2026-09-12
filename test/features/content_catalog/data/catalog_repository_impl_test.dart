import 'package:flutter_test/flutter_test.dart';

import 'package:learning_platform/core/errors/result.dart';
import 'package:learning_platform/features/content_catalog/data/catalog_repository_impl.dart';
import 'package:learning_platform/features/content_catalog/data/foundation_catalog_data_source.dart';
import 'package:learning_platform/features/content_catalog/domain/course.dart';

import '../../../helpers/memory_key_value_store.dart';

void main() {
  test('bookmark changes are reflected through repository indexes', () async {
    final repository = CatalogRepositoryImpl(
      remote: FoundationCatalogDataSource(),
      localStore: MemoryKeyValueStore(),
    );
    await repository.setBookmarked('course-1', bookmarked: true);
    final result = await repository.getBookmarkedCourses();

    expect(result, isA<Success<List<CourseSummary>>>());
    final courses = (result as Success<List<CourseSummary>>).value;
    expect(courses, hasLength(1));
  });

  test('recently viewed remains bounded and most-recent-first', () async {
    final repository = CatalogRepositoryImpl(
      remote: FoundationCatalogDataSource(),
      localStore: MemoryKeyValueStore(),
    );
    await repository.recordRecentlyViewed('course-1');
    await repository.recordRecentlyViewed('course-2');
    await repository.recordRecentlyViewed('course-1');
    final result = await repository.getRecentlyViewed(limit: 2);
    final courses = (result as Success<List<CourseSummary>>).value;
    expect(courses.map((course) => course.id), ['course-1', 'course-2']);
  });
}
