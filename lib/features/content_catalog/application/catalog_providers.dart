import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_platform/bootstrap/providers.dart';
import 'package:learning_platform/config/app_environment.dart';
import 'package:learning_platform/core/errors/result.dart';
import 'package:learning_platform/features/academic/academic_profile.dart';
import 'package:learning_platform/features/authentication/application/auth_providers.dart';
import 'package:learning_platform/features/content_catalog/application/bookmarks_controller.dart';
import 'package:learning_platform/features/content_catalog/application/catalog_controller.dart';
import 'package:learning_platform/features/content_catalog/application/catalog_state.dart';
import 'package:learning_platform/features/content_catalog/application/course_detail_controller.dart';
import 'package:learning_platform/features/content_catalog/application/home_feed_controller.dart';
import 'package:learning_platform/features/content_catalog/application/search_controller.dart';
import 'package:learning_platform/features/content_catalog/data/catalog_data_source.dart';
import 'package:learning_platform/features/content_catalog/data/catalog_repository_impl.dart';
import 'package:learning_platform/features/content_catalog/data/foundation_catalog_data_source.dart';
import 'package:learning_platform/features/content_catalog/data/remote_catalog_data_source.dart';
import 'package:learning_platform/features/content_catalog/domain/catalog_repository.dart';
import 'package:learning_platform/features/content_catalog/domain/course.dart';

final catalogDataSourceProvider = Provider<CatalogDataSource>(
  (ref) => switch (ref.watch(appConfigProvider).environment) {
    AppEnvironment.development => FoundationCatalogDataSource(
      academicProfile: () => ref.read(academicProfileProvider).valueOrNull,
    ),
    AppEnvironment.staging || AppEnvironment.production =>
      RemoteCatalogDataSource(ref.watch(apiClientProvider)),
  },
);
final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => CatalogRepositoryImpl(
    remote: ref.watch(catalogDataSourceProvider),
    localStore: ref.watch(keyValueStoreProvider),
    academicContext: () => ref.read(academicContextKeyProvider),
    beforeCatalog: () async {
      await ref.read(academicProfileProvider.future);
    },
    learnerId:
        ref.watch(
          authControllerProvider.select((state) => state.session?.identity.id),
        ) ??
        'anonymous',
  ),
);
final homeFeedProvider =
    StateNotifierProvider<HomeFeedController, HomeFeedState>((ref) {
      ref.watch(academicContextKeyProvider);
      final controller = HomeFeedController(
        ref.watch(catalogRepositoryProvider),
      );
      unawaited(controller.load());
      return controller;
    });
final catalogProvider = StateNotifierProvider<CatalogController, CatalogState>((
  ref,
) {
  ref.watch(academicContextKeyProvider);
  final controller = CatalogController(ref.watch(catalogRepositoryProvider));
  unawaited(controller.loadInitial());
  return controller;
});
final courseSearchProvider =
    StateNotifierProvider<CourseSearchController, CatalogState>((ref) {
      final controller = CourseSearchController(
        ref.watch(catalogRepositoryProvider),
      );
      ref.listen(academicContextKeyProvider, (previous, next) {
        if (previous != next) controller.refreshAcademicContext();
      });
      return controller;
    });
final bookmarksProvider =
    StateNotifierProvider<BookmarksController, BookmarksState>((ref) {
      ref.watch(academicContextKeyProvider);
      final controller = BookmarksController(
        ref.watch(catalogRepositoryProvider),
      );
      unawaited(controller.load());
      return controller;
    });
final courseDetailProvider =
    StateNotifierProvider.family<
      CourseDetailController,
      CourseDetailState,
      String
    >((ref, courseId) {
      final controller = CourseDetailController(
        ref.watch(catalogRepositoryProvider),
        courseId,
      );
      unawaited(controller.load());
      return controller;
    });
final categoriesProvider = FutureProvider<List<CourseCategory>>((ref) async {
  ref.watch(academicContextKeyProvider);
  await ref.watch(academicProfileProvider.future);
  final result = await ref.watch(catalogRepositoryProvider).getCategories();
  return switch (result) {
    Success<List<CourseCategory>>(value: final categories) => categories,
    Failure<List<CourseCategory>>(failure: final failure) => throw failure,
  };
});
final recentlyViewedProvider = FutureProvider<List<CourseSummary>>((ref) async {
  ref.watch(academicContextKeyProvider);
  await ref.watch(academicProfileProvider.future);
  final result = await ref.watch(catalogRepositoryProvider).getRecentlyViewed();
  return switch (result) {
    Success<List<CourseSummary>>(value: final courses) => courses,
    Failure<List<CourseSummary>>() => const [],
  };
});
