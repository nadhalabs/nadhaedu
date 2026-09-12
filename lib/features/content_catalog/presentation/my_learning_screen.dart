import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:learning_platform/core/routing/app_router.dart';
import 'package:learning_platform/core/theme/app_spacing.dart';
import 'package:learning_platform/core/widgets/content_states.dart';
import 'package:learning_platform/features/content_catalog/application/catalog_providers.dart';
import 'package:learning_platform/features/content_catalog/presentation/widgets/course_grid.dart';
import 'package:learning_platform/features/learning_progress/application/learning_providers.dart';

class MyLearningScreen extends ConsumerWidget {
  const MyLearningScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentlyViewedProvider);
    final bookmarks = ref.watch(bookmarksProvider).ids;
    final history =
        ref.watch(learningHistoryViewProvider).valueOrNull ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('My Learning')),
      body: recent.when(
        loading: () => const LoadingView(label: 'Loading your learning'),
        error: (error, stack) =>
            ErrorView(onAction: () => ref.invalidate(recentlyViewedProvider)),
        data: (courses) => courses.isEmpty
            ? const MessageView(
                icon: Icons.school_outlined,
                title: 'Start learning',
                message: 'Courses you view and begin will appear here.',
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (history.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.medium,
                        AppSpacing.medium,
                        AppSpacing.medium,
                        0,
                      ),
                      child: Card(
                        child: ListTile(
                          leading: const Icon(Icons.play_circle_outline),
                          title: const Text('Continue Learning'),
                          subtitle: Text('Resume your most recent lesson'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push(
                            AppRoutes.learn(
                              history.first.entry.courseId,
                              lessonId: history.first.entry.lessonId,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.medium,
                      AppSpacing.small,
                      AppSpacing.medium,
                      0,
                    ),
                    child: Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.download_for_offline_outlined,
                        ),
                        title: const Text('Downloads & Offline Learning'),
                        subtitle: const Text(
                          'Manage downloaded lessons and offline storage',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(AppRoutes.downloads),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.medium,
                      AppSpacing.small,
                      AppSpacing.medium,
                      0,
                    ),
                    child: Card(
                      child: ListTile(
                        leading: const Icon(Icons.workspace_premium_outlined),
                        title: const Text('My Certificates'),
                        subtitle: const Text(
                          'View and verify your earned credentials',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/certificates'),
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.medium),
                    child: Text(
                      'Recently Viewed',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      children: [
                        SizedBox(
                          height: 460,
                          child: CourseGrid(
                            courses: courses,
                            bookmarkedIds: bookmarks,
                            onBookmark: ref
                                .read(bookmarksProvider.notifier)
                                .toggle,
                          ),
                        ),
                        if (history.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.medium),
                            child: Text(
                              'Learning history',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ),
                          for (final item in history)
                            ListTile(
                              leading: const Icon(Icons.history),
                              title: Text(item.lessonTitle),
                              subtitle: Text(item.courseTitle),
                              onTap: () => context.push(
                                AppRoutes.learn(
                                  item.entry.courseId,
                                  lessonId: item.entry.lessonId,
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
