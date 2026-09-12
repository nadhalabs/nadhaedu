import 'package:flutter_test/flutter_test.dart';

import 'package:learning_platform/features/content_catalog/data/foundation_catalog_data_source.dart';
import 'package:learning_platform/features/content_catalog/domain/catalog_query.dart';
import 'package:learning_platform/features/content_catalog/domain/home_feed.dart';

void main() {
  test('catalog uses cursors without returning duplicate pages', () async {
    final source = FoundationCatalogDataSource();
    final first = await source.fetchCourses(const CatalogQuery(pageSize: 10));
    final second = await source.fetchCourses(
      CatalogQuery(pageSize: 10, cursor: first.nextCursor),
    );

    expect(first.items, hasLength(10));
    expect(second.items, hasLength(10));
    expect(
      first.items
          .map((course) => course.id)
          .toSet()
          .intersection(second.items.map((course) => course.id).toSet()),
      isEmpty,
    );
  });

  test('search and category filtering happen in the data source', () async {
    final source = FoundationCatalogDataSource();
    final result = await source.fetchCourses(
      const CatalogQuery(searchTerm: 'design', categoryId: 'design'),
    );
    expect(result.items, isNotEmpty);
    expect(
      result.items.every((course) => course.categoryIds.contains('design')),
      isTrue,
    );
  });

  test('server-driven feed supplies every required section kind', () async {
    final feed = await FoundationCatalogDataSource().fetchHomeFeed();
    final kinds = feed.sections.map((section) => section.kind).toSet();
    expect(kinds, containsAll(HomeSectionKind.values));
  });

  test('bookmark and recently-viewed indexes avoid duplicates', () async {
    final source = FoundationCatalogDataSource();
    await source.setBookmarked('course-1', bookmarked: true);
    await source.setBookmarked('course-1', bookmarked: true);
    await source.recordRecentlyViewed('course-1');
    await source.recordRecentlyViewed('course-1');
    expect(await source.fetchBookmarkedIds(), {'course-1'});
    expect(await source.fetchRecentlyViewedIds(limit: 10), ['course-1']);
  });
}
