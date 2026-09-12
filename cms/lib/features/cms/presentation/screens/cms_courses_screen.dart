import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nadha_cms/core/theme/app_breakpoints.dart';
import 'package:nadha_cms/features/cms/academic.dart';
import 'package:nadha_cms/features/cms/application/cms_courses_controller.dart';
import 'package:nadha_cms/features/cms/application/cms_providers.dart';
import 'package:nadha_cms/features/cms/presentation/theme/cms_theme.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_badge.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_card.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_confirm_dialog.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_data_table.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_header.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_state_views.dart';

class CmsCoursesScreen extends ConsumerWidget {
  const CmsCoursesScreen({super.key, this.currentRoute});

  final String? currentRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cmsCoursesControllerProvider);
    final route = currentRoute ?? _safeRoute(context, '/admin/courses');
    final isMobile = MediaQuery.sizeOf(context).width < AppBreakpoints.medium;

    return Scaffold(
      backgroundColor: CmsTheme.canvasColor,
      body: Column(
        children: [
          CmsHeader(
            currentRoute: route,
            title: 'Course Catalog & Content',
            subtitle:
                'Manage course lifecycle states, access policies, and curriculum structure',
            showMenuButton: isMobile,
            onMenuTap: () => Scaffold.of(context).openDrawer(),
            actions: [
              OutlinedButton(
                onPressed: () => context.go('/admin/academic'),
                child: const Text('Academic catalog'),
              ),
              FilledButton.icon(
                onPressed: () => context.go('/admin/courses/new'),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Create Course'),
                style: FilledButton.styleFrom(
                  backgroundColor: CmsTheme.primaryAccent,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Refresh Courses',
                icon: state.isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: CmsTheme.primaryAccent,
                        ),
                      )
                    : const Icon(Icons.refresh, size: 18),
                color: CmsTheme.primaryAccent,
                onPressed: state.isLoading
                    ? null
                    : () => ref
                          .read(cmsCoursesControllerProvider.notifier)
                          .load(),
              ),
            ],
          ),
          if (state.successMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              color: CmsTheme.successBg,
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    size: 16,
                    color: CmsTheme.successText,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.successMessage!,
                      style: const TextStyle(
                        color: CmsTheme.successText,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(child: _buildContent(context, ref, state)),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    CmsCoursesState state,
  ) {
    if (state.isLoading && state.courses.isEmpty) {
      return const CmsLoadingView(message: 'Loading course catalog...');
    }
    if (state.errorMessage != null && state.courses.isEmpty) {
      return CmsErrorView(
        message: state.errorMessage!,
        onRetry: () => ref.read(cmsCoursesControllerProvider.notifier).load(),
      );
    }

    final filtered = state.filteredCourses;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter and Search Toolbar
          AcademicSelectors(
            value: state.academic,
            onChanged: ref
                .read(cmsCoursesControllerProvider.notifier)
                .setAcademic,
          ),
          const SizedBox(height: 16),
          CmsCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Search box
                Expanded(
                  flex: 3,
                  child: TextField(
                    onChanged: (val) => ref
                        .read(cmsCoursesControllerProvider.notifier)
                        .setSearchQuery(val),
                    style: const TextStyle(
                      color: CmsTheme.textPrimary,
                      fontSize: 13,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Search courses by title or subtitle...',
                      prefixIcon: Icon(
                        Icons.search,
                        size: 18,
                        color: CmsTheme.textMuted,
                      ),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Filter chips
                Wrap(
                  spacing: 6,
                  children: [
                    _buildFilterChip(ref, state, 'all', 'All'),
                    _buildFilterChip(ref, state, 'published', 'Published'),
                    _buildFilterChip(ref, state, 'draft', 'Drafts'),
                    _buildFilterChip(ref, state, 'archived', 'Archived'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Courses Data Table
          CmsCard(
            title: 'Catalog Inventory (${filtered.length})',
            subtitle: 'Authoritative server-managed courses',
            padding: EdgeInsets.zero,
            child: filtered.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'No courses match your filter criteria.',
                        style: TextStyle(
                          color: CmsTheme.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                : CmsDataTable(
                    columns: const [
                      CmsTableColumn(label: 'Course', flex: 4),
                      CmsTableColumn(label: 'Level', flex: 2),
                      CmsTableColumn(label: 'Policy', flex: 2),
                      CmsTableColumn(label: 'Structure', flex: 2),
                      CmsTableColumn(label: 'Enrollments', flex: 2),
                      CmsTableColumn(label: 'Status', flex: 2),
                      CmsTableColumn(
                        label: 'Actions',
                        width: 90,
                        alignment: Alignment.centerRight,
                      ),
                    ],
                    rows: filtered.map((course) {
                      return CmsTableRow(
                        cells: [
                          InkWell(
                            onTap: () =>
                                context.go('/admin/courses/${course.id}'),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  course.title,
                                  style: const TextStyle(
                                    color: CmsTheme.primaryAccent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (course.subtitle.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    course.subtitle,
                                    style: const TextStyle(
                                      color: CmsTheme.textMuted,
                                      fontSize: 11,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Text(
                            course.level,
                            style: const TextStyle(
                              color: CmsTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            course.policyKind.toUpperCase(),
                            style: TextStyle(
                              color: course.policyKind == 'premium'
                                  ? const Color(0xFFFBBF24)
                                  : CmsTheme.infoText,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${course.moduleCount} mods • ${course.lessonCount} lessons',
                            style: const TextStyle(
                              color: CmsTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '${course.enrollmentCount} learners',
                            style: const TextStyle(
                              color: CmsTheme.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          CmsBadge.forStatus(course.status),
                          PopupMenuButton<String>(
                            color: CmsTheme.cardColor,
                            shape: RoundedRectangleBorder(
                              side: const BorderSide(
                                color: CmsTheme.borderColor,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            icon: const Icon(
                              Icons.more_vert,
                              size: 18,
                              color: CmsTheme.textMuted,
                            ),
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit_curriculum',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.edit,
                                      size: 16,
                                      color: CmsTheme.primaryAccent,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Edit Curriculum & Details',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              if (course.status != 'published')
                                const PopupMenuItem(
                                  value: 'published',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.publish,
                                        size: 16,
                                        color: CmsTheme.successColor,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Publish Course',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              if (course.status != 'draft')
                                const PopupMenuItem(
                                  value: 'draft',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.edit_note,
                                        size: 16,
                                        color: CmsTheme.warningColor,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Move to Draft',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              if (course.status != 'archived')
                                const PopupMenuItem(
                                  value: 'archived',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.archive,
                                        size: 16,
                                        color: CmsTheme.textMuted,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Archive Course',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                            onSelected: (targetStatus) async {
                              if (targetStatus == 'edit_curriculum') {
                                context.go('/admin/courses/${course.id}');
                                return;
                              }
                              final reason = await CmsConfirmDialog.show(
                                context,
                                title: 'Change Course Status',
                                message:
                                    'Are you sure you want to change the status of "${course.title}" from "${course.status}" to "$targetStatus"? This action will be audited.',
                                confirmLabel: 'Update Status',
                                requireReason: true,
                              );
                              if (reason != null) {
                                await ref
                                    .read(cmsCoursesControllerProvider.notifier)
                                    .updateStatus(
                                      courseId: course.id,
                                      status: targetStatus,
                                      reason: reason,
                                    );
                              }
                            },
                          ),
                        ],
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    WidgetRef ref,
    CmsCoursesState state,
    String value,
    String label,
  ) {
    final isSelected = state.selectedFilter == value;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) =>
          ref.read(cmsCoursesControllerProvider.notifier).setFilter(value),
      selectedColor: CmsTheme.primaryAccent.withValues(alpha: 0.2),
      backgroundColor: CmsTheme.cardColor,
      labelStyle: TextStyle(
        color: isSelected ? CmsTheme.primaryAccent : CmsTheme.textSecondary,
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(
          color: isSelected
              ? CmsTheme.primaryAccent.withValues(alpha: 0.5)
              : CmsTheme.borderColor,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }
}

String _safeRoute(BuildContext context, String fallback) {
  try {
    return GoRouterState.of(context).uri.path;
  } on Object catch (_) {
    return fallback;
  }
}
