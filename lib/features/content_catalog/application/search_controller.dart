import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:learning_platform/features/content_catalog/application/catalog_controller.dart';
import 'package:learning_platform/features/content_catalog/application/catalog_state.dart';
import 'package:learning_platform/features/content_catalog/domain/catalog_query.dart';
import 'package:learning_platform/features/content_catalog/domain/catalog_repository.dart';

final class CourseSearchController extends StateNotifier<CatalogState> {
  CourseSearchController(
    this._repository, {
    this.debounceDuration = const Duration(milliseconds: 350),
  }) : super(const CatalogState(query: CatalogQuery()));

  final CatalogRepository _repository;
  final Duration debounceDuration;
  Timer? _debounce;
  CatalogController? _activeSearch;

  void refreshAcademicContext() => search(state.query.searchTerm);

  void search(String term) {
    _debounce?.cancel();
    _activeSearch?.dispose();
    _activeSearch = null;
    final normalized = term.trim();
    if (normalized.isEmpty) {
      state = const CatalogState(query: CatalogQuery());
      return;
    }
    state = CatalogState(
      query: CatalogQuery(searchTerm: normalized),
      isLoading: true,
    );
    _debounce = Timer(debounceDuration, () async {
      _activeSearch?.dispose();
      final controller = CatalogController(
        _repository,
        initialQuery: CatalogQuery(searchTerm: normalized),
      );
      _activeSearch = controller;
      controller.addListener((next) {
        if (mounted && identical(_activeSearch, controller)) state = next;
      });
      await controller.loadInitial();
    });
  }

  Future<void> loadMore() async => _activeSearch?.loadMore();

  @override
  void dispose() {
    _debounce?.cancel();
    _activeSearch?.dispose();
    super.dispose();
  }
}
