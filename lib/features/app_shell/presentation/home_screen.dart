import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_platform/core/motion/app_motion.dart';
import 'package:learning_platform/core/routing/app_router.dart';
import 'package:learning_platform/core/theme/app_spacing.dart';
import 'package:learning_platform/core/theme/app_tokens.dart';
import 'package:learning_platform/core/widgets/content_states.dart';
import 'package:learning_platform/core/widgets/learning_artwork.dart';
import 'package:learning_platform/core/widgets/learning_feedback.dart';
import 'package:learning_platform/features/authentication/application/auth_providers.dart';
import 'package:learning_platform/features/content_catalog/application/catalog_providers.dart';
import 'package:learning_platform/features/content_catalog/domain/course.dart';
import 'package:learning_platform/features/content_catalog/domain/home_feed.dart';
import 'package:learning_platform/features/content_catalog/presentation/widgets/course_card.dart';
import 'package:learning_platform/features/learning_progress/application/learning_providers.dart';
import 'package:learning_platform/features/notifications/presentation/widgets/notification_badge.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeFeedProvider);
    final learnerName = ref
        .watch(authControllerProvider)
        .session
        ?.identity
        .displayName;
    if (state.isLoading && state.feed == null) {
      return const LoadingView(label: 'Loading home');
    }
    if (state.failure != null && state.feed == null) {
      return ErrorView(
        onAction: () => ref.read(homeFeedProvider.notifier).load(),
      );
    }
    final feed = state.feed;
    if (feed == null || feed.sections.isEmpty) {
      return const EmptyView();
    }
    final history = ref.watch(learningHistoryViewProvider).valueOrNull;
    CourseSummary? continuing;
    for (final section in feed.sections) {
      if (section.kind == HomeSectionKind.continueLearning &&
          section.content is CourseSectionContent) {
        continuing =
            (section.content as CourseSectionContent).courses.firstOrNull;
      }
    }
    final sections = feed.sections
        .where((section) => section.kind != HomeSectionKind.continueLearning)
        .toList();
    return RefreshIndicator(
      onRefresh: () => ref.read(homeFeedProvider.notifier).load(refresh: true),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            floating: true,
            title: Text(
              learnerName == null
                  ? 'Your learning space'
                  : 'Hello, $learnerName',
            ),
            actions: [
              const NotificationBadgeButton(),
              IconButton(
                tooltip: 'Profile & Account',
                onPressed: () => context.push(AppRoutes.profile),
                icon: const Icon(Icons.account_circle_outlined),
              ),
            ],
          ),

          if (feed.isFromCache)
            const SliverToBoxAdapter(
              child: MaterialBanner(
                content: Text(
                  'Showing saved content. Some information may be out of date.',
                ),
                actions: [SizedBox.shrink()],
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.large),
              child: LearningEntrance(
                child: _NextStep(
                  course: continuing,
                  history: history?.firstOrNull,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.large),
              child: Wrap(
                spacing: AppSpacing.small,
                runSpacing: AppSpacing.small,
                children: [
                  ActionChip(
                    backgroundColor: AppPalette.softSurface(
                      context,
                      AppPalette.sky,
                    ),
                    avatar: const Icon(Icons.download_for_offline_outlined),
                    label: const Text('Learn offline'),
                    onPressed: () => context.push(AppRoutes.downloads),
                  ),
                  ActionChip(
                    backgroundColor: AppPalette.softSurface(
                      context,
                      AppPalette.sunshine,
                    ),
                    avatar: const Icon(Icons.workspace_premium_outlined),
                    label: const Text('Your achievements'),
                    onPressed: () => context.push(AppRoutes.certificates),
                  ),
                  ActionChip(
                    backgroundColor: AppPalette.softSurface(
                      context,
                      AppPalette.lilac,
                    ),
                    avatar: const Icon(Icons.bookmark_outline),
                    label: const Text('Saved for later'),
                    onPressed: () => context.push(AppRoutes.bookmarks),
                  ),
                ],
              ),
            ),
          ),
          SliverList.builder(
            itemCount: sections.length,
            itemBuilder: (context, index) =>
                _HomeSection(section: sections[index]),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.large)),
        ],
      ),
    );
  }
}

class _HomeSection extends ConsumerWidget {
  const _HomeSection({required this.section});
  final HomeFeedSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarks = ref.watch(bookmarksProvider).ids;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.large),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.medium),
            child: Semantics(
              header: true,
              child: Text(
                section.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.small),
          if (section.failure != null)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.medium),
              child: Text(
                'This collection is taking a break. Explore another below.',
              ),
            )
          else
            switch (section.content) {
              CourseSectionContent(courses: final courses) => SizedBox(
                height:
                    330 + (MediaQuery.textScalerOf(context).scale(14) - 14) * 9,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.large,
                  ),
                  scrollDirection: Axis.horizontal,
                  itemCount: courses.length,
                  itemBuilder: (context, index) {
                    final course = courses[index];
                    return SizedBox(
                      width: 260,
                      child: Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.small),
                        child: CourseCard(
                          course: course,
                          isBookmarked: bookmarks.contains(course.id),
                          onBookmark: () => ref
                              .read(bookmarksProvider.notifier)
                              .toggle(course.id),
                          onTap: () =>
                              context.push(AppRoutes.course(course.id)),
                        ),
                      ),
                    );
                  },
                ),
              ),
              CategorySectionContent(categories: final categories) =>
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.large,
                  ),
                  child: Row(
                    children: [
                      for (final category in categories)
                        Padding(
                          padding: const EdgeInsets.only(
                            right: AppSpacing.small,
                          ),
                          child: ActionChip(
                            backgroundColor: AppPalette.softSurface(
                              context,
                              AppPalette.accent(category.id),
                            ),
                            label: Text(category.name),
                            onPressed: () async {
                              final catalog = ref.read(catalogProvider);
                              await ref
                                  .read(catalogProvider.notifier)
                                  .updateQuery(
                                    catalog.query.copyWith(
                                      categoryId: category.id,
                                    ),
                                  );
                              if (context.mounted) {
                                context.go(AppRoutes.discover);
                              }
                            },
                          ),
                        ),
                    ],
                  ),
                ),
            },
        ],
      ),
    );
  }
}

class _NextStep extends StatelessWidget {
  const _NextStep({this.course, this.history});
  final CourseSummary? course;
  final LearningHistoryViewItem? history;
  @override
  Widget build(BuildContext context) {
    final continuing = course != null || history != null;
    final title =
        history?.courseTitle ??
        course?.title ??
        'What will you discover today?';
    final identity = history?.entry.courseId ?? course?.id ?? 'discovery';
    final progress = history == null || history!.entry.courseId == course?.id
        ? course?.progress
        : null;
    Future<void> continueLearning() async {
      if (continuing) {
        await context.push<void>(
          AppRoutes.learn(
            history?.entry.courseId ?? course!.id,
            lessonId: history?.entry.lessonId,
          ),
        );
      } else {
        context.go(AppRoutes.discover);
      }
    }

    return LearningLift(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppPalette.heroGradient,
          borderRadius: BorderRadius.circular(AppRadii.large),
          boxShadow: AppShadows.hero,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.large),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: continueLearning,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.large),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 620;
                  final artwork = LearningArtwork(
                    identity: identity,
                    title: title,
                    onBlue: true,
                  );
                  final copy = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.bolt_rounded,
                            color: AppPalette.sunshine,
                            size: 22,
                          ),
                          const SizedBox(width: AppSpacing.small),
                          Expanded(
                            child: Text(
                              continuing
                                  ? 'CONTINUE LEARNING'
                                  : 'FOLLOW YOUR CURIOSITY',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                    letterSpacing: 1.1,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      if (!wide)
                        SizedBox(
                          height: 120,
                          width: double.infinity,
                          child: artwork,
                        ),
                      if (wide) const SizedBox(height: AppSpacing.large),
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineLarge
                            ?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: AppSpacing.small),
                      Text(
                        history?.lessonTitle ??
                            (continuing
                                ? 'Your next discovery is one lesson away.'
                                : 'Make something. Solve a puzzle. Follow an idea.'),
                        style: Theme.of(
                          context,
                        ).textTheme.bodyLarge?.copyWith(color: Colors.white),
                      ),
                      if (progress != null) ...[
                        const SizedBox(height: AppSpacing.large),
                        LearningProgress(
                          value: progress,
                          color: AppPalette.sunshine,
                          trackColor: Colors.white.withValues(alpha: 0.22),
                        ),
                        const SizedBox(height: AppSpacing.small),
                        Text(
                          '${(progress * 100).round()}% complete',
                          style: Theme.of(
                            context,
                          ).textTheme.labelLarge?.copyWith(color: Colors.white),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.large),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppPalette.ocean,
                          shadowColor: Colors.black26,
                        ),
                        onPressed: continueLearning,
                        icon: Icon(
                          continuing
                              ? Icons.play_arrow_rounded
                              : Icons.explore_outlined,
                        ),
                        label: Text(
                          continuing
                              ? 'Let’s continue'
                              : 'Find your first course',
                        ),
                      ),
                    ],
                  );
                  return wide
                      ? Row(
                          children: [
                            Expanded(flex: 3, child: copy),
                            const SizedBox(width: AppSpacing.large),
                            Expanded(
                              flex: 2,
                              child: SizedBox(height: 240, child: artwork),
                            ),
                          ],
                        )
                      : copy;
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
