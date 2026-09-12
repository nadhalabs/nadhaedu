import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:learning_platform/core/errors/app_failure.dart';
import 'package:learning_platform/core/errors/result.dart';
import 'package:learning_platform/features/content_catalog/domain/catalog_repository.dart';
import 'package:learning_platform/features/content_catalog/domain/home_feed.dart';

final class HomeFeedState {
  const HomeFeedState({
    this.feed,
    this.failure,
    this.isLoading = false,
    this.isRefreshing = false,
  });
  final HomeFeed? feed;
  final AppFailure? failure;
  final bool isLoading;
  final bool isRefreshing;
}

final class HomeFeedController extends StateNotifier<HomeFeedState> {
  HomeFeedController(this._repository) : super(const HomeFeedState());
  final CatalogRepository _repository;

  Future<void> load({bool refresh = false}) async {
    if (state.isLoading || state.isRefreshing) return;
    state = HomeFeedState(
      feed: state.feed,
      isLoading: state.feed == null,
      isRefreshing: refresh && state.feed != null,
    );
    final result = await _repository.getHomeFeed(forceRefresh: refresh);
    if (!mounted) return;
    switch (result) {
      case Success<HomeFeed>(value: final feed):
        state = HomeFeedState(feed: feed);
      case Failure<HomeFeed>(failure: final failure):
        state = HomeFeedState(feed: state.feed, failure: failure);
    }
  }
}
