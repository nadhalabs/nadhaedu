import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:learning_platform/core/routing/app_router.dart';
import 'package:learning_platform/core/theme/app_spacing.dart';
import 'package:learning_platform/core/widgets/content_states.dart';
import 'package:learning_platform/features/content_catalog/application/catalog_providers.dart';
import 'package:learning_platform/features/content_catalog/application/catalog_state.dart';
import 'package:learning_platform/features/content_catalog/domain/catalog_query.dart';
import 'package:learning_platform/features/content_catalog/presentation/widgets/course_grid.dart';

class DiscoveryScreen extends ConsumerWidget {
  const DiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(catalogProvider);
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];
    final bookmarks = ref.watch(bookmarksProvider).ids;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover courses'),
        actions: [
          TextButton(
            onPressed: () => context.push(AppRoutes.categories),
            child: const Text('Categories'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(58),
          child: SizedBox(
            height: 58,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.medium,
              ),
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: state.query.categoryId == null,
                  onSelected: (_) => ref
                      .read(catalogProvider.notifier)
                      .updateQuery(state.query.copyWith(clearCategory: true)),
                ),
                for (final category in categories)
                  Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.small),
                    child: ChoiceChip(
                      label: Text(category.name),
                      selected: state.query.categoryId == category.id,
                      onSelected: (_) => ref
                          .read(catalogProvider.notifier)
                          .updateQuery(
                            state.query.copyWith(categoryId: category.id),
                          ),
                    ),
                  ),
                const SizedBox(width: AppSpacing.small),
                Tooltip(
                  message: 'Sort courses',
                  child: DropdownButton<CatalogSort>(
                    value: state.query.sort,
                    items: const [
                      DropdownMenuItem(
                        value: CatalogSort.relevance,
                        child: Text('Relevant'),
                      ),
                      DropdownMenuItem(
                        value: CatalogSort.newest,
                        child: Text('Newest'),
                      ),
                      DropdownMenuItem(
                        value: CatalogSort.rating,
                        child: Text('Rating'),
                      ),
                      DropdownMenuItem(
                        value: CatalogSort.popularity,
                        child: Text('Popular'),
                      ),
                    ],
                    onChanged: (sort) async {
                      if (sort != null) {
                        await ref
                            .read(catalogProvider.notifier)
                            .updateQuery(state.query.copyWith(sort: sort));
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _CatalogBody(
        state: state,
        bookmarkedIds: bookmarks,
        onBookmark: ref.read(bookmarksProvider.notifier).toggle,
        onRetry: ref.read(catalogProvider.notifier).loadInitial,
        onLoadMore: ref.read(catalogProvider.notifier).loadMore,
      ),
    );
  }
}

class _CatalogBody extends StatelessWidget {
  const _CatalogBody({
    required this.state,
    required this.bookmarkedIds,
    required this.onBookmark,
    required this.onRetry,
    required this.onLoadMore,
  });

  final CatalogState state;
  final Set<String> bookmarkedIds;
  final ValueChanged<String> onBookmark;
  final VoidCallback onRetry;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && state.items.isEmpty) {
      return const LoadingView(label: 'Loading courses');
    }
    if (state.failure != null && state.items.isEmpty) {
      return ErrorView(onAction: onRetry);
    }
    if (state.items.isEmpty) {
      return const EmptyView();
    }
    return Column(
      children: [
        if (state.isFromCache)
          const MaterialBanner(
            content: Text('Showing cached results while offline.'),
            actions: [SizedBox.shrink()],
          ),
        Expanded(
          child: CourseGrid(
            courses: state.items,
            bookmarkedIds: bookmarkedIds,
            onBookmark: onBookmark,
            footer: Padding(
              padding: const EdgeInsets.all(AppSpacing.large),
              child: state.isLoadingMore
                  ? const Center(child: CircularProgressIndicator())
                  : state.hasMore
                  ? Center(
                      child: OutlinedButton(
                        onPressed: onLoadMore,
                        child: const Text('Load more'),
                      ),
                    )
                  : const Center(child: Text('You have reached the end.')),
            ),
          ),
        ),
      ],
    );
  }
}
