import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_platform/core/routing/app_router.dart';
import 'package:learning_platform/core/theme/app_spacing.dart';
import 'package:learning_platform/core/theme/app_tokens.dart';
import 'package:learning_platform/core/widgets/content_states.dart';
import 'package:learning_platform/core/widgets/learning_artwork.dart';
import 'package:learning_platform/core/widgets/learning_feedback.dart';
import 'package:learning_platform/features/academic/academic_profile.dart';
import 'package:learning_platform/features/content_catalog/application/catalog_providers.dart';
import 'package:learning_platform/features/content_catalog/domain/course.dart';
import 'package:learning_platform/features/downloads/presentation/widgets/download_action_button.dart';
import 'package:learning_platform/features/entitlements/application/entitlement_providers.dart';
import 'package:learning_platform/features/entitlements/domain/access_policy.dart';
import 'package:learning_platform/features/entitlements/domain/resource_type.dart';
import 'package:learning_platform/features/entitlements/presentation/widgets/access_status_badge.dart';
import 'package:learning_platform/features/learning_progress/application/learning_providers.dart';
import 'package:learning_platform/features/learning_progress/domain/learning_progress.dart';

class CourseDetailScreen extends ConsumerWidget {
  const CourseDetailScreen({required this.courseId, super.key});
  final String courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(academicContextKeyProvider, (previous, next) {
      if (previous != null &&
          previous != 'loading' &&
          previous != 'unavailable' &&
          next != 'loading' &&
          next != 'unavailable' &&
          previous != next) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) context.go(AppRoutes.home);
        });
      }
    });
    final state = ref.watch(courseDetailProvider(courseId));
    final bookmarkState = ref.watch(bookmarksProvider);
    if (state.isLoading && state.course == null) {
      return const LoadingView(label: 'Loading course');
    }
    if (state.failure != null && state.course == null) {
      return Scaffold(
        appBar: AppBar(),
        body: ErrorView(
          onAction: ref.read(courseDetailProvider(courseId).notifier).load,
        ),
      );
    }
    final course = state.course;
    if (course == null) {
      return const EmptyView();
    }
    final summary = course.summary;
    final learning = ref.watch(
      learningControllerProvider((courseId: courseId, lessonId: null)),
    );
    final outline = learning.outline;
    final progress = learning.progress;
    final accessQuery = (
      resourceType: ResourceType.course,
      resourceId: courseId,
      policy: summary.effectivePolicy,
      categoryIds: summary.categoryIds,
      courseId: courseId,
    );
    final cachedCourseAccess = ref.watch(accessDecisionProvider(accessQuery));
    final courseAccess =
        ref
            .watch(authoritativeAccessDecisionProvider(accessQuery))
            .valueOrNull ??
        cachedCourseAccess;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your learning path'),
        actions: [
          IconButton(
            tooltip: bookmarkState.ids.contains(courseId)
                ? 'Remove bookmark'
                : 'Bookmark course',
            onPressed: () =>
                ref.read(bookmarksProvider.notifier).toggle(courseId),
            icon: Icon(
              bookmarkState.ids.contains(courseId)
                  ? Icons.bookmark
                  : Icons.bookmark_outline,
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppSpacing.maxContentWidth,
          ),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.large),
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.large),
                decoration: BoxDecoration(
                  color: AppPalette.softSurface(
                    context,
                    AppPalette.accent(courseId),
                  ),
                  borderRadius: BorderRadius.circular(AppRadii.large),
                  boxShadow: AppShadows.surface,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final copy = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            summary.title,
                            style: Theme.of(context).textTheme.displaySmall,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.small),
                        Text(
                          summary.subtitle,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    );
                    final art = SizedBox(
                      height: 180,
                      child: LearningArtwork(
                        identity: courseId,
                        title: summary.title,
                      ),
                    );
                    return constraints.maxWidth >= 620
                        ? Row(
                            children: [
                              Expanded(flex: 3, child: copy),
                              const SizedBox(width: AppSpacing.large),
                              Expanded(flex: 2, child: art),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [art, copy],
                          );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.medium),
              Wrap(
                spacing: AppSpacing.medium,
                runSpacing: AppSpacing.small,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '★ ${summary.rating.toStringAsFixed(1)} (${summary.ratingCount})',
                  ),
                  Text('${summary.duration.inHours} hours'),
                  Text('${summary.lessonCount} lessons'),
                  Text(_levelLabel(summary.level)),
                  AccessStatusBadge(state: courseAccess.state),
                ],
              ),
              const SizedBox(height: AppSpacing.large),
              if (outline != null && progress != null) ...[
                LearningProgress(
                  value: CourseProgressCalculator.fraction(outline, progress),
                ),
                const SizedBox(height: AppSpacing.small),
                Text(
                  '${outline.lessons.where((lesson) => progress.lessons[lesson.id]?.completed ?? false).length} of ${outline.lessons.length} steps explored',
                ),
              ],
              const SizedBox(height: AppSpacing.large),
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppSpacing.touchTarget,
                ),
                child: FilledButton.icon(
                  onPressed: () => context.push(AppRoutes.learn(courseId)),
                  icon: Icon(
                    courseAccess.canAccess
                        ? Icons.play_arrow
                        : Icons.lock_open_outlined,
                  ),
                  label: Text(
                    courseAccess.canAccess
                        ? 'Start or continue learning'
                        : 'Preview course or unlock access',
                  ),
                ),
              ),
              const Divider(height: AppSpacing.xLarge),
              Text(
                'About this course',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.small),
              Text(course.description),
              const SizedBox(height: AppSpacing.large),
              Text(
                'What you will learn',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              for (final outcome in course.learningOutcomes)
                ListTile(
                  leading: const Icon(Icons.check_circle_outline),
                  title: Text(outcome),
                ),
              const SizedBox(height: AppSpacing.large),
              Text(
                'Your path, one step at a time',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              for (final (moduleIndex, module) in course.modules.indexed)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.medium),
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: ExpansionTile(
                      initiallyExpanded: module.lessons.any(
                        (lesson) => lesson.id == learning.selectedLessonId,
                      ),
                      shape: const Border(),
                      collapsedShape: const Border(),
                      leading: CircleAvatar(
                        backgroundColor: AppPalette.softSurface(
                          context,
                          AppPalette.accent(module.id),
                        ),
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onSurface,
                        child: Text('${moduleIndex + 1}'),
                      ),
                      title: Text(
                        'Chapter ${moduleIndex + 1}: ${module.title}',
                      ),
                      subtitle: Text('${module.lessons.length} lessons'),
                      children: [
                        for (final lesson in module.lessons)
                          _LessonTile(
                            courseId: courseId,
                            coursePolicy: summary.effectivePolicy,
                            modulePolicy: module.policy,
                            categoryIds: summary.categoryIds,
                            lesson: lesson,
                            completed:
                                progress?.lessons[lesson.id]?.completed ??
                                false,
                            current: lesson.id == learning.selectedLessonId,
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _levelLabel(CourseLevel level) => switch (level) {
    CourseLevel.beginner => 'Beginner',
    CourseLevel.intermediate => 'Intermediate',
    CourseLevel.advanced => 'Advanced',
    CourseLevel.allLevels => 'All levels',
  };
}

class _LessonTile extends ConsumerWidget {
  const _LessonTile({
    required this.courseId,
    required this.coursePolicy,
    required this.modulePolicy,
    required this.categoryIds,
    required this.lesson,
    required this.completed,
    required this.current,
  });

  final String courseId;
  final AccessPolicy coursePolicy;
  final AccessPolicy? modulePolicy;
  final Set<String> categoryIds;
  final Lesson lesson;
  final bool completed;
  final bool current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectivePolicy = AccessPolicy.resolve(
      coursePolicy: coursePolicy,
      modulePolicy: modulePolicy,
      lessonPolicy: lesson.effectivePolicy,
    );

    final access = ref.watch(
      accessDecisionProvider((
        resourceType: ResourceType.lesson,
        resourceId: lesson.id,
        policy: effectivePolicy,
        categoryIds: categoryIds,
        courseId: courseId,
      )),
    );

    final (icon, type) = switch (lesson.content) {
      VideoLessonContent() => (Icons.play_circle_outline, 'Video'),
      ArticleLessonContent() => (Icons.article_outlined, 'Article'),
      ResourceLessonContent() => (Icons.picture_as_pdf_outlined, 'Resource'),
      QuizLessonContent() => (Icons.quiz_outlined, 'Quiz'),
      AssignmentLessonContent() => (Icons.assignment_outlined, 'Assignment'),
      LiveClassLessonContent() => (Icons.live_tv_outlined, 'Live class'),
      ProjectLessonContent() => (Icons.build_outlined, 'Project'),
    };

    return ListTile(
      selected: current,
      selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
      iconColor: completed
          ? (Theme.of(context).brightness == Brightness.dark
                ? AppPalette.mint
                : AppPalette.success)
          : null,
      leading: Icon(
        completed
            ? Icons.check_circle
            : !access.canAccess
            ? Icons.lock_outline
            : current
            ? Icons.play_circle_fill
            : icon,
        semanticLabel: completed
            ? 'Completed'
            : !access.canAccess
            ? 'Locked'
            : current
            ? 'Your next step'
            : type,
      ),
      title: Text(lesson.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${completed
                ? 'Completed'
                : current
                ? 'Your next step'
                : type} · ${lesson.estimatedDuration.inMinutes} min',
          ),
          const SizedBox(height: AppSpacing.xSmall),
          Wrap(
            spacing: AppSpacing.small,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AccessStatusBadge(state: access.state, compact: true),
              if (lesson.content case VideoLessonContent(
                assetId: final assetId,
              ))
                DownloadActionButton(
                  resourceId: assetId,
                  courseId: courseId,
                  lessonId: lesson.id,
                  title: lesson.title,
                  courseTitle: '',
                  compact: true,
                ),
            ],
          ),
        ],
      ),
      onTap: () => context.push(AppRoutes.learn(courseId, lessonId: lesson.id)),
    );
  }
}
