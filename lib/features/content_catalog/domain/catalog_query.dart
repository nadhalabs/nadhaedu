import 'package:learning_platform/features/content_catalog/domain/course.dart';

enum CatalogSort { relevance, newest, rating, popularity }

final class CatalogQuery {
  const CatalogQuery({
    this.searchTerm = '',
    this.categoryId,
    this.level,
    this.sort = CatalogSort.relevance,
    this.cursor,
    this.pageSize = 12,
    this.academicContext = 'unconfigured',
  }) : assert(pageSize > 0 && pageSize <= 50);

  final String searchTerm;
  final String? categoryId;
  final CourseLevel? level;
  final CatalogSort sort;
  final String? cursor;
  final int pageSize;
  final String academicContext;

  CatalogQuery copyWith({
    String? searchTerm,
    String? categoryId,
    bool clearCategory = false,
    CourseLevel? level,
    bool clearLevel = false,
    CatalogSort? sort,
    String? cursor,
    bool clearCursor = false,
    String? academicContext,
  }) => CatalogQuery(
    searchTerm: searchTerm ?? this.searchTerm,
    categoryId: clearCategory ? null : categoryId ?? this.categoryId,
    level: clearLevel ? null : level ?? this.level,
    sort: sort ?? this.sort,
    cursor: clearCursor ? null : cursor ?? this.cursor,
    pageSize: pageSize,
    academicContext: academicContext ?? this.academicContext,
  );

  String get cacheKey =>
      '$academicContext|${searchTerm.trim().toLowerCase()}|$categoryId|$level|$sort|$cursor|$pageSize';
}

final class CursorPage<T> {
  const CursorPage({
    required this.items,
    required this.nextCursor,
    required this.isFromCache,
  });

  final List<T> items;
  final String? nextCursor;
  final bool isFromCache;
  bool get hasMore => nextCursor != null;
}
