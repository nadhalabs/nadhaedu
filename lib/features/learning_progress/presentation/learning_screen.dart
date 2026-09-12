import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_platform/bootstrap/providers.dart';
import 'package:learning_platform/core/errors/result.dart';
import 'package:learning_platform/core/motion/app_motion.dart';
import 'package:learning_platform/core/routing/app_router.dart';
import 'package:learning_platform/core/theme/app_spacing.dart';
import 'package:learning_platform/core/theme/app_tokens.dart';
import 'package:learning_platform/core/widgets/content_states.dart';
import 'package:learning_platform/core/widgets/learning_artwork.dart';
import 'package:learning_platform/core/widgets/learning_feedback.dart';
import 'package:learning_platform/features/academic/academic_profile.dart';
import 'package:learning_platform/features/assessments/presentation/assessment_screen.dart';
import 'package:learning_platform/features/content_catalog/domain/course.dart';
import 'package:learning_platform/features/content_protection/domain/content_protection_policy.dart';
import 'package:learning_platform/features/downloads/presentation/widgets/download_action_button.dart';
import 'package:learning_platform/features/entitlements/application/entitlement_providers.dart';
import 'package:learning_platform/features/entitlements/domain/access_decision.dart';
import 'package:learning_platform/features/entitlements/domain/access_policy.dart';
import 'package:learning_platform/features/entitlements/domain/resource_type.dart';
import 'package:learning_platform/features/entitlements/presentation/widgets/access_gate_view.dart';
import 'package:learning_platform/features/entitlements/presentation/widgets/access_status_badge.dart';
import 'package:learning_platform/features/learning_progress/application/learning_controller.dart';
import 'package:learning_platform/features/learning_progress/application/learning_providers.dart';
import 'package:learning_platform/features/learning_progress/domain/learning_progress.dart';
import 'package:learning_platform/features/learning_progress/presentation/lesson_content_items.dart';
import 'package:learning_platform/features/learning_progress/presentation/video_lesson_player.dart';

class LearningScreen extends ConsumerWidget {
  const LearningScreen({
    required this.courseId,
    this.initialLessonId,
    super.key,
  });
  final String courseId;
  final String? initialLessonId;

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
    final args = (courseId: courseId, lessonId: initialLessonId);
    final state = ref.watch(learningControllerProvider(args));
    final controller = ref.read(learningControllerProvider(args).notifier);
    if (state.isLoading && state.course == null) {
      return const LoadingView(label: 'Loading lesson');
    }
    if (state.course == null ||
        state.outline == null ||
        state.progress == null) {
      return Scaffold(
        appBar: AppBar(),
        body: ErrorView(onAction: controller.load),
      );
    }
    final lesson = state.selectedLesson;
    final fraction = state.courseProgressFraction;
    return Scaffold(
      appBar: AppBar(
        title: Text(state.course!.summary.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(8),
          child: LearningProgress(value: fraction, label: 'Course progress'),
        ),
        actions: [
          if (state.isSyncing)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: lesson == null
          ? const MessageView(
              icon: Icons.menu_book_outlined,
              title: 'No lessons available',
              message: 'This course does not contain any lessons yet.',
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final module = state.outline!.moduleByLessonId[lesson.id]!;
                final effectivePolicy = AccessPolicy.resolve(
                  coursePolicy: state.course!.summary.effectivePolicy,
                  modulePolicy: module.policy,
                  lessonPolicy: lesson.effectivePolicy,
                );
                final accessQuery = (
                  resourceType: ResourceType.lesson,
                  resourceId: lesson.id,
                  policy: effectivePolicy,
                  categoryIds: state.course!.summary.categoryIds,
                  courseId: courseId,
                );
                final cachedAccess = ref.watch(
                  accessDecisionProvider(accessQuery),
                );
                final access =
                    ref
                        .watch(authoritativeAccessDecisionProvider(accessQuery))
                        .valueOrNull ??
                    cachedAccess;

                final content = _LessonContent(
                  key: ValueKey(lesson.id),
                  lesson: lesson,
                  courseId: courseId,
                  courseTitle: state.course!.summary.title,
                  courseProtectionPolicy:
                      state.course!.summary.effectiveProtectionPolicy,
                  access: access,
                  progress: state.progress!.lessons[lesson.id],
                  controller: controller,
                  isCompleting: state.isCompleting,
                  errorMessage: state.errorMessage,
                  courseCompleted: fraction >= 1,
                );
                if (constraints.maxWidth >= 900) {
                  return Row(
                    children: [
                      Expanded(child: LearningSwitcher(child: content)),
                      const VerticalDivider(width: 1),
                      SizedBox(
                        width: 360,
                        child: _CourseOutline(
                          state: state,
                          courseId: courseId,
                          coursePolicy: state.course!.summary.effectivePolicy,
                          categoryIds: state.course!.summary.categoryIds,
                          onSelected: controller.selectLesson,
                        ),
                      ),
                    ],
                  );
                }
                return Column(
                  children: [
                    Expanded(child: LearningSwitcher(child: content)),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.small),
                        child: SizedBox(
                          width: double.infinity,

                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.list),
                            label: const Text('Course content'),
                            onPressed: () => showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              builder: (_) => FractionallySizedBox(
                                heightFactor: 0.8,
                                child: _CourseOutline(
                                  state: state,
                                  courseId: courseId,
                                  coursePolicy:
                                      state.course!.summary.effectivePolicy,
                                  categoryIds:
                                      state.course!.summary.categoryIds,
                                  onSelected: controller.selectLesson,
                                  dismissOnSelect: true,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _LessonContent extends ConsumerWidget {
  const _LessonContent({
    required this.lesson,
    required this.courseId,
    required this.courseTitle,
    required this.courseProtectionPolicy,
    required this.access,
    required this.progress,
    required this.controller,
    required this.isCompleting,
    required this.courseCompleted,
    this.errorMessage,
    super.key,
  });
  final Lesson lesson;
  final String courseId;
  final String courseTitle;
  final ContentProtectionPolicy courseProtectionPolicy;
  final AccessDecision access;
  final LessonProgress? progress;
  final LearningController controller;
  final bool isCompleting;
  final bool courseCompleted;
  final String? errorMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!access.canAccess) {
      return AccessGateView(
        decision: access,
        resourceTitle: lesson.title,
        onUnlock: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Subscribe or purchase in account settings to access this lesson.',
              ),
            ),
          );
        },
      );
    }

    if (lesson.content case QuizLessonContent(
      assessmentId: final assessmentId,
    ) when !lesson.hasContentItems) {
      return AssessmentScreen(
        assessmentId: assessmentId,
        isEmbedded: true,
        onPassed: () {
          unawaited(controller.refreshAuthoritativeProgress());
        },
        onContinue: controller.selectNext,
      );
    }

    final effectiveProtection = lesson.resolveProtectionPolicy(
      courseProtectionPolicy,
    );

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.medium),
      children: [
        if (lesson.hasContentItems)
          LessonContentItems(
            lesson: lesson,
            courseId: courseId,
            courseTitle: courseTitle,
            controller: controller,
            policy: effectiveProtection,
            initialPosition: progress?.position ?? Duration.zero,
          )
        else if (lesson.content case VideoLessonContent(assetId: final assetId))
          VideoLessonPlayer(
            key: ValueKey(assetId),
            assetId: assetId,
            initialPosition: progress?.position ?? Duration.zero,
            onProgress: (position, duration) => controller.recordPosition(
              position,
              duration,
              lessonId: lesson.id,
            ),
            onFlush: controller.refreshAuthoritativeProgress,
            policy: effectiveProtection,
          )
        else
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ColoredBox(
              color: AppPalette.softSurface(
                context,
                AppPalette.accent(courseId),
              ),
              child: LearningArtwork(identity: courseId, title: courseTitle),
            ),
          ),
        if (errorMessage != null) ...[
          const SizedBox(height: AppSpacing.medium),
          MaterialBanner(
            content: Text(errorMessage!),
            actions: [
              TextButton(
                onPressed: controller.synchronize,
                child: const Text('Sync now'),
              ),
            ],
          ),
        ],
        if (courseCompleted) ...[
          const SizedBox(height: AppSpacing.medium),
          const LearningCelebration(
            title: 'Every step explored!',
            message:
                'Your progress is saved here. Sync to check your certificate.',
          ),
          TextButton.icon(
            onPressed: () => context.push(AppRoutes.certificates),
            icon: const Icon(Icons.workspace_premium_outlined),
            label: const Text('View certificates'),
          ),
        ],
        const SizedBox(height: AppSpacing.medium),
        Semantics(
          header: true,
          child: Text(
            lesson.title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        const SizedBox(height: AppSpacing.small),
        Wrap(
          spacing: AppSpacing.small,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AccessStatusBadge(state: access.state),
            if (!lesson.hasContentItems)
              DownloadActionButton(
                resourceId: lesson.content is VideoLessonContent
                    ? (lesson.content as VideoLessonContent).assetId
                    : lesson.id,
                courseId: courseId,
                lessonId: lesson.id,
                title: lesson.title,
                courseTitle: courseTitle,
              ),
          ],
        ),
        Text('${lesson.estimatedDuration.inMinutes} minutes'),
        const SizedBox(height: AppSpacing.medium),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: AppSpacing.small,
          runSpacing: AppSpacing.small,
          children: [
            OutlinedButton.icon(
              onPressed: !controller.hasPrevious
                  ? null
                  : controller.selectPrevious,
              icon: const Icon(Icons.chevron_left),
              label: const Text('Previous lesson'),
            ),
            if (lesson.contentItems.any(
                  (i) => i.type == 'note' || i.type == 'resource',
                ) ||
                (!lesson.contentItems.any((i) => i.type == 'video') &&
                    lesson.content is! VideoLessonContent))
              FilledButton.icon(
                onPressed:
                    isCompleting ||
                        (progress?.completed ?? false) ||
                        (lesson.hasContentItems && lesson.contentItems.isEmpty)
                    ? null
                    : () async {
                        if (lesson.contentItems.any((i) => i.type == 'quiz' || i.type == 'video')) {
                          final result = await ref
                              .read(apiClientProvider)
                              .get(
                                '/api/v1/lessons/${lesson.id}/completion-readiness',
                              );
                          if (!context.mounted) return;
                          if (result is! Success<Map<String, Object?>> ||
                              result.value['canComplete'] != true) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Connect, watch required videos and pass every quiz before completing this lesson.',
                                ),
                              ),
                            );
                            return;
                          }
                        }
                        await controller.toggleCompleted();
                      },
                icon: Icon(
                  progress?.completed ?? false
                      ? Icons.check_circle
                      : Icons.circle_outlined,
                ),
                label: Text(
                  isCompleting
                      ? 'Saving…'
                      : progress?.completed ?? false
                      ? 'Completed'
                      : 'Mark complete',
                ),
              ),
            OutlinedButton.icon(
              onPressed: !controller.hasNext ? null : controller.selectNext,
              icon: const Icon(Icons.chevron_right),
              label: const Text('Next lesson'),
            ),
          ],
        ),
      ],
    );
  }
}

class _CourseOutline extends ConsumerWidget {
  const _CourseOutline({
    required this.state,
    required this.courseId,
    required this.coursePolicy,
    required this.categoryIds,
    required this.onSelected,
    this.dismissOnSelect = false,
  });

  final LearningState state;
  final String courseId;
  final AccessPolicy coursePolicy;
  final Set<String> categoryIds;
  final ValueChanged<String> onSelected;
  final bool dismissOnSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outline = state.outline!;
    return ListView.builder(
      itemCount: outline.lessons.length,
      itemBuilder: (context, index) {
        final lesson = outline.lessons[index];
        final module = outline.moduleByLessonId[lesson.id]!;
        final previousModule = index == 0
            ? null
            : outline.moduleByLessonId[outline.lessons[index - 1].id];
        final showHeader = module.id != previousModule?.id;

        final effectivePolicy = AccessPolicy.resolve(
          coursePolicy: coursePolicy,
          modulePolicy: module.policy,
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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showHeader)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Semantics(
                  header: true,
                  child: Text(
                    module.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
            ListTile(
              selected: lesson.id == state.selectedLessonId,
              selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
              leading: Icon(
                state.progress!.lessons[lesson.id]?.completed ?? false
                    ? Icons.check_circle
                    : Icons.circle_outlined,
                semanticLabel:
                    state.progress!.lessons[lesson.id]?.completed ?? false
                    ? 'Completed'
                    : 'Not completed',
              ),
              title: Text(lesson.title),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AccessStatusBadge(state: access.state, compact: true),
                  DownloadActionButton(
                    resourceId: lesson.content is VideoLessonContent
                        ? (lesson.content as VideoLessonContent).assetId
                        : lesson.id,
                    courseId: courseId,
                    lessonId: lesson.id,
                    title: lesson.title,
                    courseTitle: state.course!.summary.title,
                    compact: true,
                  ),
                ],
              ),
              onTap: () {
                onSelected(lesson.id);
                if (dismissOnSelect) Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
