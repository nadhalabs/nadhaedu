import 'package:learning_platform/core/errors/app_failure.dart';
import 'package:learning_platform/features/content_catalog/domain/catalog_query.dart';
import 'package:learning_platform/features/content_catalog/domain/course.dart';

final class CatalogState {
  const CatalogState({
    required this.query,
    this.items = const [],
    this.nextCursor,
    this.failure,
    this.isLoading = false,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.isFromCache = false,
  });

  final CatalogQuery query;
  final List<CourseSummary> items;
  final String? nextCursor;
  final AppFailure? failure;
  final bool isLoading;
  final bool isRefreshing;
  final bool isLoadingMore;
  final bool isFromCache;
  bool get hasMore => nextCursor != null;

  CatalogState copyWith({
    CatalogQuery? query,
    List<CourseSummary>? items,
    String? nextCursor,
    bool clearCursor = false,
    AppFailure? failure,
    bool clearFailure = false,
    bool? isLoading,
    bool? isRefreshing,
    bool? isLoadingMore,
    bool? isFromCache,
  }) => CatalogState(
    query: query ?? this.query,
    items: items ?? this.items,
    nextCursor: clearCursor ? null : nextCursor ?? this.nextCursor,
    failure: clearFailure ? null : failure ?? this.failure,
    isLoading: isLoading ?? this.isLoading,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    isFromCache: isFromCache ?? this.isFromCache,
  );
}
