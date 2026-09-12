import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:learning_platform/core/errors/result.dart';
import 'package:learning_platform/features/content_catalog/application/catalog_state.dart';
import 'package:learning_platform/features/content_catalog/domain/catalog_query.dart';
import 'package:learning_platform/features/content_catalog/domain/catalog_repository.dart';
import 'package:learning_platform/features/content_catalog/domain/course.dart';

final class CatalogController extends StateNotifier<CatalogState> {
  CatalogController(
    this._repository, {
    CatalogQuery initialQuery = const CatalogQuery(),
  }) : super(CatalogState(query: initialQuery));

  final CatalogRepository _repository;
  int _generation = 0;

  Future<void> loadInitial() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, clearFailure: true);
    await _load(state.query.copyWith(clearCursor: true), replace: true);
  }

  Future<void> refresh() async {
    if (state.isRefreshing) return;
    state = state.copyWith(isRefreshing: true, clearFailure: true);
    await _load(state.query.copyWith(clearCursor: true), replace: true);
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true, clearFailure: true);
    await _load(state.query.copyWith(cursor: state.nextCursor), replace: false);
  }

  Future<void> updateQuery(CatalogQuery query) async {
    state = CatalogState(
      query: query.copyWith(clearCursor: true),
      isLoading: true,
    );
    await _load(state.query, replace: true);
  }

  Future<void> _load(CatalogQuery query, {required bool replace}) async {
    final generation = ++_generation;
    final result = await _repository.getCourses(query);
    if (!mounted || generation != _generation) return;
    switch (result) {
      case Success<CursorPage<CourseSummary>>(value: final page):
        final items = replace
            ? page.items
            : _mergeById(state.items, page.items);
        state = CatalogState(
          query: query.copyWith(clearCursor: true),
          items: items,
          nextCursor: page.nextCursor,
          isFromCache: page.isFromCache,
        );
      case Failure<CursorPage<CourseSummary>>(failure: final failure):
        state = state.copyWith(
          failure: failure,
          isLoading: false,
          isRefreshing: false,
          isLoadingMore: false,
        );
    }
  }

  List<CourseSummary> _mergeById(
    List<CourseSummary> current,
    List<CourseSummary> next,
  ) {
    final byId = <String, CourseSummary>{
      for (final course in current) course.id: course,
    };
    for (final course in next) {
      byId[course.id] = course;
    }
    return List.unmodifiable(byId.values);
  }
}
