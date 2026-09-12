import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_platform/core/motion/app_motion.dart';
import 'package:learning_platform/core/theme/app_spacing.dart';
import 'package:learning_platform/core/theme/app_tokens.dart';
import 'package:learning_platform/core/widgets/learning_artwork.dart';
import 'package:learning_platform/core/widgets/learning_feedback.dart';
import 'package:learning_platform/features/content_catalog/domain/course.dart';
import 'package:learning_platform/features/entitlements/application/entitlement_providers.dart';
import 'package:learning_platform/features/entitlements/domain/resource_type.dart';
import 'package:learning_platform/features/entitlements/presentation/widgets/access_status_badge.dart';

class CourseCard extends ConsumerWidget {
  const CourseCard({
    required this.course,
    required this.onTap,
    required this.isBookmarked,
    required this.onBookmark,
    super.key,
  });

  final CourseSummary course;
  final VoidCallback onTap;
  final bool isBookmarked;
  final VoidCallback onBookmark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(
      accessDecisionProvider((
        resourceType: ResourceType.course,
        resourceId: course.id,
        policy: course.effectivePolicy,
        categoryIds: course.categoryIds,
        courseId: course.id,
      )),
    );

    return Semantics(
      button: true,
      onTap: onTap,
      label:
          '${course.title}, rated ${course.rating.toStringAsFixed(1)} out of 5, access ${access.state.name}',
      child: LearningLift(
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            excludeFromSemantics: true,
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(
                        color: AppPalette.artworkSurface(course.id),
                        child: LearningArtwork(
                          identity: course.id,
                          title: course.title,
                        ),
                      ),
                      if (course.coverReference != null)
                        Image.network(
                          course.coverReference!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      Positioned(
                        top: AppSpacing.small,
                        left: AppSpacing.small,
                        child: AccessStatusBadge(
                          state: access.state,
                          compact: true,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.medium,
                    AppSpacing.small,
                    AppSpacing.small,
                    AppSpacing.small,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              course.title,
                              style: Theme.of(context).textTheme.titleMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: AppSpacing.xSmall),
                            Text(
                              course.instructors
                                  .map((instructor) => instructor.name)
                                  .join(', '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            Text(
                              '${course.lessonCount} lessons · ${course.duration.inMinutes} min',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            if (course.progress case final progress?) ...[
                              const SizedBox(height: AppSpacing.small),
                              LearningProgress(
                                value: progress,
                                label: 'Course progress',
                              ),
                              const SizedBox(height: AppSpacing.xSmall),
                              Text(
                                progress >= 1
                                    ? 'Completed'
                                    : '${(progress * 100).round()}% complete',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: isBookmarked
                            ? 'Remove bookmark'
                            : 'Bookmark course',
                        onPressed: onBookmark,
                        icon: LearningSwitcher(
                          child: Icon(
                            isBookmarked
                                ? Icons.bookmark
                                : Icons.bookmark_outline,
                            key: ValueKey(isBookmarked),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
