import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:learning_platform/core/widgets/content_states.dart';
import 'package:learning_platform/features/content_catalog/application/catalog_providers.dart';
import 'package:learning_platform/features/content_catalog/presentation/widgets/course_grid.dart';

class BookmarksScreen extends ConsumerWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bookmarksProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Bookmarks')),
      body: state.isLoading && state.courses.isEmpty
          ? const LoadingView(label: 'Loading bookmarks')
          : state.failure != null && state.courses.isEmpty
          ? ErrorView(onAction: ref.read(bookmarksProvider.notifier).load)
          : state.courses.isEmpty
          ? const MessageView(
              icon: Icons.bookmark_outline,
              title: 'No bookmarks yet',
              message: 'Save courses to find them quickly later.',
            )
          : CourseGrid(
              courses: state.courses,
              bookmarkedIds: state.ids,
              onBookmark: ref.read(bookmarksProvider.notifier).toggle,
            ),
    );
  }
}
