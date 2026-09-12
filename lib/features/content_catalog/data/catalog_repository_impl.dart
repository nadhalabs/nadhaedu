import 'dart:convert';

import 'package:learning_platform/core/errors/app_failure.dart';
import 'package:learning_platform/core/errors/result.dart';
import 'package:learning_platform/core/persistence/key_value_store.dart';
import 'package:learning_platform/features/content_catalog/data/catalog_data_source.dart';
import 'package:learning_platform/features/content_catalog/domain/catalog_query.dart';
import 'package:learning_platform/features/content_catalog/domain/catalog_repository.dart';
import 'package:learning_platform/features/content_catalog/domain/course.dart';
import 'package:learning_platform/features/content_catalog/domain/home_feed.dart';

final class CatalogRepositoryImpl implements CatalogRepository {
  CatalogRepositoryImpl({
    required CatalogDataSource remote,
    required KeyValueStore localStore,
    String learnerId = 'anonymous',
    String Function()? academicContext,
    this.beforeCatalog,
  }) : _remote = remote,
       _localStore = localStore,
       _learnerId = learnerId,
       _academicContext = academicContext ?? _defaultContext;

  static String _defaultContext() => 'unconfigured';
  final String Function() _academicContext;
  final Future<void> Function()? beforeCatalog;
  Future<AppFailure?> _prepare() async {
    try {
      await beforeCatalog?.call();
      return null;
    } on Object catch (e) {
      return NetworkFailure(
        code: 'academic_profile_unavailable',
        message:
            'Unable to load Academic Profile. Retry in Settings → Academic Profile.',
        cause: e,
      );
    }
  }

  static const _contextChanged = NetworkFailure(
    code: 'academic_context_changed',
    message: 'Academic Profile changed. Refresh this view.',
  );

  final String _learnerId;
  String get _bookmarkCacheKey => 'catalog.bookmarks.v2.$_learnerId';
  String get _recentCacheKey => 'catalog.recently_viewed.v2.$_learnerId';

  final CatalogDataSource _remote;
  final KeyValueStore _localStore;
  final Map<String, CursorPage<CourseSummary>> _pageCache = {};
  final Map<String, Course> _courseCache = {};
  final Map<String, HomeFeed> _homeCache = {};

  @override
  Future<Result<HomeFeed>> getHomeFeed({bool forceRefresh = false}) async {
    final failure = await _prepare();
    if (failure != null) return Failure(failure);
    final context = _academicContext();
    if (!forceRefresh) {
      final cached = _homeCache[context];
      if (cached != null) return Success(_cachedFeed(cached));
    }
    try {
      final feed = await _remote.fetchHomeFeed();
      if (_academicContext() != context) return const Failure(_contextChanged);
      if (_homeCache.length >= 8) _homeCache.remove(_homeCache.keys.first);
      _homeCache[context] = feed;
      return Success(feed);
    } on CatalogDataException catch (error) {
      final cached = _homeCache[context];
      return cached == null
          ? Failure(_mapFailure(error))
          : Success(_cachedFeed(cached));
    }
  }

  @override
  Future<Result<CursorPage<CourseSummary>>> getCourses(
    CatalogQuery query,
  ) async {
    final failure = await _prepare();
    if (failure != null) return Failure(failure);
    query = query.copyWith(academicContext: _academicContext());
    try {
      final page = await _remote.fetchCourses(query);
      if (_academicContext() != query.academicContext) {
        return const Failure(_contextChanged);
      }
      if (_pageCache.length >= 40) _pageCache.remove(_pageCache.keys.first);
      _pageCache[query.cacheKey] = page;
      return Success(page);
    } on CatalogDataException catch (error) {
      final cached = _pageCache[query.cacheKey];
      if (cached != null) {
        return Success(
          CursorPage(
            items: cached.items,
            nextCursor: cached.nextCursor,
            isFromCache: true,
          ),
        );
      }
      return Failure(_mapFailure(error));
    }
  }

  @override
  Future<Result<Course>> getCourse(String courseId) async {
    try {
      final course = await _remote.fetchCourse(courseId);
      if (_courseCache.length >= 100) {
        _courseCache.remove(_courseCache.keys.first);
      }
      _courseCache[courseId] = course;
      return Success(course);
    } on CatalogDataException catch (error) {
      final cached = _courseCache[courseId];
      return cached == null ? Failure(_mapFailure(error)) : Success(cached);
    }
  }

  @override
  Future<Result<List<CourseCategory>>> getCategories() async {
    final failure = await _prepare();
    if (failure != null) return Failure(failure);
    try {
      return Success(await _remote.fetchCategories());
    } on CatalogDataException catch (error) {
      return Failure(_mapFailure(error));
    }
  }

  @override
  Future<Result<Set<String>>> getBookmarkedIds() async {
    try {
      final ids = await _remote.fetchBookmarkedIds();
      await _writeIds(_bookmarkCacheKey, ids);
      return Success(ids);
    } on CatalogDataException catch (error) {
      final cached = await _readIds(_bookmarkCacheKey);
      return cached.isEmpty ? Failure(_mapFailure(error)) : Success(cached);
    }
  }

  @override
  Future<Result<void>> setBookmarked(
    String courseId, {
    required bool bookmarked,
  }) async {
    try {
      await _remote.setBookmarked(courseId, bookmarked: bookmarked);
      final ids = await _readIds(_bookmarkCacheKey);
      bookmarked ? ids.add(courseId) : ids.remove(courseId);
      await _writeIds(_bookmarkCacheKey, ids);
      return const Success(null);
    } on CatalogDataException catch (error) {
      return Failure(_mapFailure(error));
    }
  }

  @override
  Future<Result<List<CourseSummary>>> getBookmarkedCourses() async {
    final failure = await _prepare();
    if (failure != null) return Failure(failure);
    final idsResult = await getBookmarkedIds();
    switch (idsResult) {
      case Failure<Set<String>>(failure: final failure):
        return Failure(failure);
      case Success<Set<String>>(value: final ids):
        try {
          return Success(
            await _remote.fetchCoursesByIds(ids.toList(growable: false)),
          );
        } on CatalogDataException catch (error) {
          return Failure(_mapFailure(error));
        }
    }
  }

  @override
  Future<Result<void>> recordRecentlyViewed(String courseId) async {
    try {
      await _remote.recordRecentlyViewed(courseId);
      final ids =
          (await _readOrderedIds(_recentCacheKey)).toList(growable: true)
            ..remove(courseId)
            ..insert(0, courseId);
      if (ids.length > 20) ids.removeRange(20, ids.length);
      await _localStore.writeString(_recentCacheKey, jsonEncode(ids));
      return const Success(null);
    } on CatalogDataException catch (error) {
      return Failure(_mapFailure(error));
    }
  }

  @override
  Future<Result<List<CourseSummary>>> getRecentlyViewed({
    int limit = 10,
  }) async {
    final failure = await _prepare();
    if (failure != null) return Failure(failure);
    try {
      final ids = await _remote.fetchRecentlyViewedIds(limit: limit);
      await _localStore.writeString(_recentCacheKey, jsonEncode(ids));
      return Success(await _remote.fetchCoursesByIds(ids));
    } on CatalogDataException catch (error) {
      final cached = await _readOrderedIds(_recentCacheKey);
      if (cached.isEmpty) return Failure(_mapFailure(error));
      try {
        return Success(
          await _remote.fetchCoursesByIds(
            cached.take(limit).toList(growable: false),
          ),
        );
      } on CatalogDataException {
        return Failure(_mapFailure(error));
      }
    }
  }

  HomeFeed _cachedFeed(HomeFeed feed) => HomeFeed(
    sections: feed.sections,
    isFromCache: true,
    updatedAt: feed.updatedAt,
  );

  Future<Set<String>> _readIds(String key) async =>
      (await _readOrderedIds(key)).toSet();

  Future<List<String>> _readOrderedIds(String key) async {
    final encoded = await _localStore.readString(key);
    if (encoded == null) return [];
    final decoded = jsonDecode(encoded);
    if (decoded is! List) return [];
    return decoded.whereType<String>().toList(growable: false);
  }

  Future<void> _writeIds(String key, Set<String> ids) =>
      _localStore.writeString(key, jsonEncode(ids.toList(growable: false)));

  AppFailure _mapFailure(CatalogDataException error) => switch (error.kind) {
    CatalogDataErrorKind.offline => NetworkFailure(
      code: 'catalog_offline',
      message: 'Catalog content is unavailable while offline.',
      cause: error,
    ),
    CatalogDataErrorKind.timeout => NetworkFailure(
      code: 'catalog_timeout',
      message: 'The catalog request timed out.',
      cause: error,
    ),
    CatalogDataErrorKind.server => NetworkFailure(
      code: 'catalog_server_failure',
      message: 'Catalog content is temporarily unavailable.',
      cause: error,
    ),
    CatalogDataErrorKind.notFound => NetworkFailure(
      code: 'course_not_found',
      message: 'This course is no longer available.',
      cause: error,
    ),
  };
}
