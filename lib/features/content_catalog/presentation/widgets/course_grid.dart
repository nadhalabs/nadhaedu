import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:learning_platform/core/routing/app_router.dart';
import 'package:learning_platform/core/theme/app_spacing.dart';
import 'package:learning_platform/features/content_catalog/domain/course.dart';
import 'package:learning_platform/features/content_catalog/presentation/widgets/course_card.dart';

class CourseGrid extends StatelessWidget {
  const CourseGrid({
    required this.courses,
    required this.bookmarkedIds,
    required this.onBookmark,
    this.footer,
    super.key,
  });

  final List<CourseSummary> courses;
  final Set<String> bookmarkedIds;
  final ValueChanged<String> onBookmark;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 1100
          ? 4
          : constraints.maxWidth >= 760
          ? 3
          : constraints.maxWidth >= 480
          ? 2
          : 1;
      return CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.medium),
            sliver: SliverGrid.builder(
              itemCount: courses.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: AppSpacing.medium,
                crossAxisSpacing: AppSpacing.medium,
                mainAxisExtent:
                    330 + (MediaQuery.textScalerOf(context).scale(14) - 14) * 9,
              ),
              itemBuilder: (context, index) {
                final course = courses[index];
                return CourseCard(
                  course: course,
                  isBookmarked: bookmarkedIds.contains(course.id),
                  onBookmark: () => onBookmark(course.id),
                  onTap: () => context.push(AppRoutes.course(course.id)),
                );
              },
            ),
          ),
          if (footer != null) SliverToBoxAdapter(child: footer),
        ],
      );
    },
  );
}
