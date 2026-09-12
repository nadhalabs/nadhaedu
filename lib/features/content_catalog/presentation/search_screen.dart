import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:learning_platform/core/theme/app_spacing.dart';
import 'package:learning_platform/core/widgets/content_states.dart';
import 'package:learning_platform/features/content_catalog/application/catalog_providers.dart';
import 'package:learning_platform/features/content_catalog/presentation/widgets/course_grid.dart';

class CourseSearchScreen extends ConsumerWidget {
  const CourseSearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(courseSearchProvider);
    final bookmarks = ref.watch(bookmarksProvider).ids;
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.medium),
            child: SearchBar(
              hintText: 'Search courses, skills, or topics',
              leading: const Icon(Icons.search),
              onChanged: ref.read(courseSearchProvider.notifier).search,
            ),
          ),
          Expanded(
            child: state.query.searchTerm.isEmpty
                ? const MessageView(
                    icon: Icons.search,
                    title: 'Find your next course',
                    message: 'Search by course title, skill, or topic.',
                  )
                : state.isLoading
                ? const LoadingView(label: 'Searching courses')
                : state.failure != null
                ? ErrorView(
                    onAction: () => ref
                        .read(courseSearchProvider.notifier)
                        .search(state.query.searchTerm),
                  )
                : state.items.isEmpty
                ? const MessageView(
                    icon: Icons.search_off_outlined,
                    title: 'No discoveries this time',
                    message: 'Try a shorter word or a different topic.',
                  )
                : CourseGrid(
                    courses: state.items,
                    bookmarkedIds: bookmarks,
                    onBookmark: ref.read(bookmarksProvider.notifier).toggle,
                    footer: state.hasMore
                        ? Center(
                            child: OutlinedButton(
                              onPressed: ref
                                  .read(courseSearchProvider.notifier)
                                  .loadMore,
                              child: const Text('Load more results'),
                            ),
                          )
                        : null,
                  ),
          ),
        ],
      ),
    );
  }
}
