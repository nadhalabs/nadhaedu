import 'package:learning_platform/core/errors/result.dart';
import 'package:learning_platform/core/networking/api_client.dart';
import 'package:learning_platform/features/content_catalog/data/catalog_data_source.dart';
import 'package:learning_platform/features/content_catalog/domain/catalog_query.dart';
import 'package:learning_platform/features/content_catalog/domain/course.dart';
import 'package:learning_platform/features/content_catalog/domain/home_feed.dart';
import 'package:learning_platform/features/entitlements/domain/access_policy.dart';

final class RemoteCatalogDataSource implements CatalogDataSource {
  const RemoteCatalogDataSource(this._client);
  final ApiClient _client;
  @override
  Future<CursorPage<CourseSummary>> fetchCourses(CatalogQuery value) async {
    final json = await _get(
      '/api/v1/courses',
      query: {
        'search': value.searchTerm,
        if (value.categoryId != null) 'categoryId': value.categoryId,
        if (value.level != null) 'level': value.level!.name,
        'sort': value.sort.name,
        if (value.cursor != null) 'cursor': value.cursor,
        'pageSize': value.pageSize,
      },
    );
    return CursorPage(
      items: _list(
        json,
        'items',
      ).map((x) => _summary(_mapValue(x))).toList(growable: false),
      nextCursor: json['nextCursor'] as String?,
      isFromCache: json['isFromCache'] as bool? ?? false,
    );
  }

  @override
  Future<Course> fetchCourse(String id) async =>
      _course(await _get('/api/v1/courses/${Uri.encodeComponent(id)}'));
  @override
  Future<List<CourseCategory>> fetchCategories() async =>
      _list(await _get('/api/v1/categories'), 'items')
          .map((x) {
            final j = _mapValue(x);
            return CourseCategory(
              id: _string(j, 'id'),
              name: _string(j, 'name'),
              iconName: _string(j, 'iconName'),
              isSubject: j['isSubject'] == true,
            );
          })
          .toList(growable: false);
  @override
  Future<HomeFeed> fetchHomeFeed() async {
    final json = await _get('/api/v1/home');
    return HomeFeed(
      sections: _list(json, 'sections').map((x) {
        final j = _mapValue(x);
        final kind = HomeSectionKind.values.byName(_string(j, 'kind'));
        final content = kind == HomeSectionKind.popularCategories
            ? CategorySectionContent(
                _list(j, 'items').map((v) {
                  final c = _mapValue(v);
                  return CourseCategory(
                    id: _string(c, 'id'),
                    name: _string(c, 'name'),
                    iconName: _string(c, 'iconName'),
                    isSubject: c['isSubject'] == true,
                  );
                }).toList(),
              )
            : CourseSectionContent(
                _list(j, 'items').map((v) => _summary(_mapValue(v))).toList(),
              );
        return HomeFeedSection(
          id: _string(j, 'id'),
          kind: kind,
          title: _string(j, 'title'),
          content: content,
        );
      }).toList(),
      isFromCache: false,
      updatedAt: DateTime.parse(_string(json, 'updatedAt')).toUtc(),
    );
  }

  @override
  Future<Set<String>> fetchBookmarkedIds() async =>
      _list(await _get('/api/v1/bookmarks'), 'items').cast<String>().toSet();
  @override
  Future<void> setBookmarked(
    String courseId, {
    required bool bookmarked,
  }) async {
    await _post('/api/v1/bookmarks', {
      'courseId': courseId,
      'bookmarked': bookmarked,
    });
  }

  @override
  Future<List<String>> fetchRecentlyViewedIds({required int limit}) async =>
      _list(
        await _get('/api/v1/recently-viewed', query: {'limit': limit}),
        'items',
      ).cast<String>();
  @override
  Future<void> recordRecentlyViewed(String courseId) async {
    await _post('/api/v1/recently-viewed', {'courseId': courseId});
  }

  @override
  Future<List<CourseSummary>> fetchCoursesByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final json = await _post('/api/v1/courses/by-ids', {'ids': ids});
    return _list(json, 'items').map((x) => _summary(_mapValue(x))).toList();
  }

  Future<Map<String, Object?>> _get(
    String path, {
    Map<String, Object?> query = const {},
  }) async => switch (await _client.get(path, query: query)) {
    Success(value: final v) => v,
    Failure(failure: final f) => throw _error(f),
  };
  Future<Map<String, Object?>> _post(
    String path,
    Map<String, Object?> body,
  ) async => switch (await _client.post(path, body: body)) {
    Success(value: final v) => v,
    Failure(failure: final f) => throw _error(f),
  };
}

CatalogDataException _error(Object value) => CatalogDataException(
  value is ApiFailure && value.kind == ApiErrorKind.notFound
      ? CatalogDataErrorKind.notFound
      : value is ApiFailure && value.kind == ApiErrorKind.offline
      ? CatalogDataErrorKind.offline
      : value is ApiFailure && value.kind == ApiErrorKind.timeout
      ? CatalogDataErrorKind.timeout
      : CatalogDataErrorKind.server,
  value is ApiFailure ? value.message : 'Catalog request failed.',
);
CourseSummary _summary(Map<String, Object?> j) => CourseSummary(
  curriculumId: j['curriculumId'] as String?,
  standardId: j['standardId'] as String?,
  streamId: j['streamId'] as String?,
  subjectId: j['subjectId'] as String?,
  id: _string(j, 'id'),
  title: _string(j, 'title'),
  subtitle: _string(j, 'subtitle'),
  coverReference: j['coverReference'] as String?,
  instructors: _list(j, 'instructors').map((x) {
    final v = _mapValue(x);
    return Instructor(
      id: _string(v, 'id'),
      name: _string(v, 'name'),
      headline: v['headline'] as String?,
    );
  }).toList(),
  categoryIds: _list(j, 'categoryIds').cast<String>().toSet(),
  level: CourseLevel.values.byName(_string(j, 'level')),
  policy: _policy(_map(j, 'policy')),
  languageCode: _string(j, 'languageCode'),
  rating: (j['rating']! as num).toDouble(),
  ratingCount: j['ratingCount']! as int,
  duration: Duration(seconds: j['durationSeconds']! as int),
  lessonCount: j['lessonCount']! as int,
  publishedAt: DateTime.parse(_string(j, 'publishedAt')).toUtc(),
  tags: _list(j, 'tags').cast<String>().toSet(),
  progress: (j['progress'] as num?)?.toDouble(),
);
Course _course(Map<String, Object?> j) => Course(
  summary: _summary(_map(j, 'summary')),
  description: _string(j, 'description'),
  learningOutcomes: _list(j, 'learningOutcomes').cast<String>(),
  prerequisites: _list(j, 'prerequisites').cast<String>(),
  modules: _list(j, 'modules').map((x) {
    final m = _mapValue(x);
    return CourseModule(
      id: _string(m, 'id'),
      title: _string(m, 'title'),
      position: m['position']! as int,
      policy: m['policy'] == null ? null : _policy(_map(m, 'policy')),
      lessons: _list(m, 'lessons').map((y) {
        final l = _mapValue(y);
        return Lesson(
          hasContentItems: l['hasContentItems'] as bool? ?? false,
          contentItems: (l['contentItems'] as List? ?? [])
              .map(
                (item) => LessonContentItem.fromJson(
                  Map<String, Object?>.from(item as Map),
                ),
              )
              .toList(),
          id: _string(l, 'id'),
          title: _string(l, 'title'),
          position: l['position']! as int,
          estimatedDuration: Duration(
            seconds: l['estimatedDurationSeconds']! as int,
          ),
          content: _content(_map(l, 'content')),
          isPreview: l['isPreview']! as bool,
          policy: l['policy'] == null ? null : _policy(_map(l, 'policy')),
        );
      }).toList(),
    );
  }).toList(),
  updatedAt: DateTime.parse(_string(j, 'updatedAt')).toUtc(),
);
LessonContent _content(Map<String, Object?> j) {
  final id = _string(j, 'referenceId');
  return switch (_string(j, 'type')) {
    'video' => VideoLessonContent(assetId: id),
    'article' => ArticleLessonContent(documentId: id),
    'resource' => ResourceLessonContent(
      resourceId: id,
      fileType: j['fileType'] as String? ?? 'file',
    ),
    'quiz' => QuizLessonContent(
      assessmentId: id,
      questionCount: j['questionCount'] as int? ?? 0,
    ),
    'assignment' => AssignmentLessonContent(assignmentId: id),
    'liveClass' => LiveClassLessonContent(
      eventId: id,
      startsAt: DateTime.parse(_string(j, 'startsAt')),
    ),
    'project' => ProjectLessonContent(
      projectId: id,
      briefDocumentId: j['briefDocumentId'] as String? ?? id,
    ),
    _ => ArticleLessonContent(documentId: id),
  };
}

AccessPolicy _policy(Map<String, Object?> j) => switch (_string(j, 'type')) {
  'free' => const AccessPolicy.free(),
  'premium' => AccessPolicy.premium(
    requiredTier: j['requiredTier'] as String?,
    requiredBundleId: j['requiredBundleId'] as String?,
  ),
  'preview' => const AccessPolicy.preview(),
  'inherit' => const AccessPolicy.inherit(),
  _ => const AccessPolicy.unavailable(),
};
Map<String, Object?> _map(Map<String, Object?> j, String k) => _mapValue(j[k]);
Map<String, Object?> _mapValue(Object? v) =>
    Map<String, Object?>.from(v! as Map);
List<Object?> _list(Map<String, Object?> j, String k) =>
    (j[k] as List<Object?>?) ?? const [];
String _string(Map<String, Object?> j, String k) => j[k]! as String;
