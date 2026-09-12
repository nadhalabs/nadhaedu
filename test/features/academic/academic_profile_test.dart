import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_platform/core/errors/result.dart';
import 'package:learning_platform/core/networking/api_client.dart';
import 'package:learning_platform/features/academic/academic_profile.dart';
import 'package:learning_platform/features/content_catalog/data/catalog_data_source.dart';
import 'package:learning_platform/features/content_catalog/data/catalog_repository_impl.dart';
import 'package:learning_platform/features/content_catalog/data/foundation_catalog_data_source.dart';
import 'package:learning_platform/features/content_catalog/domain/catalog_query.dart';
import 'package:learning_platform/features/content_catalog/domain/course.dart';
import 'package:learning_platform/features/content_catalog/domain/home_feed.dart';

import '../../helpers/memory_key_value_store.dart';

class _UnusedApi implements ApiClient {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Development fixture must not call API');
}

void main() {
  test(
    'switching only writes academic profile, preserves durable namespaces',
    () async {
      final store = MemoryKeyValueStore();
      final durable = {
        'learning.progress.v1.learner': 'watched',
        'catalog.bookmarks.v2.learner': '["saved"]',
        'downloads.learner': 'downloaded',
        'assessments.learner': 'passed',
        'auth': 'same-user',
      };
      store.values.addAll(durable);
      final repository = AcademicRepository(
        _UnusedApi(),
        store,
        'learner',
        isDevelopment: true,
      );
      final a = await repository.save('fixture-cbse', 'fixture-10', null);
      final same = await repository.save('fixture-cbse', 'fixture-10', null);
      final b = await repository.save(
        'fixture-kerala',
        'fixture-11',
        'fixture-science',
      );
      final back = await repository.save('fixture-cbse', 'fixture-10', null);
      expect([a.version, same.version, b.version, back.version], [1, 1, 2, 3]);
      expect((await repository.load())!.curriculumId, a.curriculumId);
      for (final e in durable.entries) {
        expect(store.values[e.key], e.value);
      }
      expect(store.values.length, durable.length + 1);
      await expectLater(
        repository.save('fixture-cbse', 'fixture-11', 'fixture-science'),
        throwsA(isA<StateError>()),
      );
    },
  );

  test(
    'catalog, home and bookmarks switch without replacing legacy IDs or records',
    () async {
      AcademicProfile profile = const AcademicProfile(
        curriculumId: 'fixture-cbse',
        standardId: 'fixture-10',
        version: 1,
      );
      final source = FoundationCatalogDataSource(
        academicProfile: () => profile,
      );
      final repository = CatalogRepositoryImpl(
        remote: source,
        localStore: MemoryKeyValueStore(),
        academicContext: () => profile.cacheKey,
      );
      final a =
          (await repository.getCourses(const CatalogQuery())
                  as Success<CursorPage<CourseSummary>>)
              .value
              .items
              .single;
      final homeA = (await repository.getHomeFeed() as Success<HomeFeed>).value;
      await repository.setBookmarked(a.id, bookmarked: true);
      profile = const AcademicProfile(
        curriculumId: 'fixture-kerala',
        standardId: 'fixture-11',
        streamId: 'fixture-science',
        version: 2,
      );
      final b =
          (await repository.getCourses(const CatalogQuery())
                  as Success<CursorPage<CourseSummary>>)
              .value
              .items
              .single;
      final homeB = (await repository.getHomeFeed() as Success<HomeFeed>).value;
      expect(a.id, isNot(b.id));
      expect(identical(homeA, homeB), isFalse);
      expect(
        (await repository.getBookmarkedCourses()
                as Success<List<CourseSummary>>)
            .value,
        isEmpty,
      );
      expect(
        (await repository.getBookmarkedIds() as Success<Set<String>>).value,
        contains(a.id),
      );
      profile = const AcademicProfile(
        curriculumId: 'fixture-cbse',
        standardId: 'fixture-10',
        version: 3,
      );
      expect(
        (await repository.getBookmarkedCourses()
                as Success<List<CourseSummary>>)
            .value
            .single
            .id,
        a.id,
      );
      expect(
        (await source.fetchCourse('course-1')).summary.curriculumId,
        isNull,
      );
      expect(
        (await source.fetchCourse(
          a.id,
        )).modules.single.lessons.single.contentItems.single.type,
        'note',
      );
    },
  );

  test('in-flight responses cannot populate a changed context cache', () async {
    var context = 'a';
    final source = _DelayedSource();
    final repository = CatalogRepositoryImpl(
      remote: source,
      localStore: MemoryKeyValueStore(),
      academicContext: () => context,
    );
    final pending = repository.getHomeFeed();
    await Future<void>.delayed(Duration.zero);
    context = 'b';
    source.release.complete();
    expect(await pending, isA<Failure<HomeFeed>>());
    expect(
      const CatalogQuery(academicContext: 'a').cacheKey,
      isNot(const CatalogQuery(academicContext: 'b').cacheKey),
    );
  });
}

class _DelayedSource implements CatalogDataSource {
  final release = Completer<void>();
  @override
  Future<HomeFeed> fetchHomeFeed() async {
    await release.future;
    return FoundationCatalogDataSource().fetchHomeFeed();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
