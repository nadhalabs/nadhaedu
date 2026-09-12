import 'package:flutter_test/flutter_test.dart';

import 'package:learning_platform/features/content_catalog/application/catalog_controller.dart';
import 'package:learning_platform/features/content_catalog/application/search_controller.dart';
import 'package:learning_platform/features/content_catalog/data/catalog_repository_impl.dart';
import 'package:learning_platform/features/content_catalog/data/foundation_catalog_data_source.dart';

import '../../../helpers/memory_key_value_store.dart';

void main() {
  test('catalog controller appends cursor pages without duplicates', () async {
    final repository = CatalogRepositoryImpl(
      remote: FoundationCatalogDataSource(),
      localStore: MemoryKeyValueStore(),
    );
    final controller = CatalogController(repository);
    await controller.loadInitial();
    final firstCount = controller.state.items.length;
    await controller.loadMore();

    expect(firstCount, 12);
    expect(controller.state.items, hasLength(24));
    expect(
      controller.state.items.map((course) => course.id).toSet(),
      hasLength(controller.state.items.length),
    );
  });

  test(
    'search waits for debounce and returns server-filtered results',
    () async {
      final repository = CatalogRepositoryImpl(
        remote: FoundationCatalogDataSource(),
        localStore: MemoryKeyValueStore(),
      );
      final controller = CourseSearchController(
        repository,
        debounceDuration: const Duration(milliseconds: 10),
      );
      controller.search('design');
      expect(controller.state.items, isEmpty);

      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(controller.state.query.searchTerm, 'design');
      expect(controller.state.items, isNotEmpty);
      controller.dispose();
    },
  );
}
