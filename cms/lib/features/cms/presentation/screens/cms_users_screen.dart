import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nadha_cms/core/theme/app_breakpoints.dart';
import 'package:nadha_cms/features/cms/application/cms_providers.dart';
import 'package:nadha_cms/features/cms/application/cms_users_controller.dart';
import 'package:nadha_cms/features/cms/presentation/theme/cms_theme.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_badge.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_card.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_data_table.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_header.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_state_views.dart';

class CmsUsersScreen extends ConsumerWidget {
  const CmsUsersScreen({super.key, this.currentRoute});

  final String? currentRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cmsUsersControllerProvider);
    final route = currentRoute ?? _safeRoute(context, '/admin/users');
    final isMobile = MediaQuery.sizeOf(context).width < AppBreakpoints.medium;

    return Scaffold(
      backgroundColor: CmsTheme.canvasColor,
      body: Column(
        children: [
          CmsHeader(
            currentRoute: route,
            title: 'Learners & User Directory',
            subtitle:
                'Authoritative platform directory, roles, and enrollment participation',
            showMenuButton: isMobile,
            onMenuTap: () => Scaffold.of(context).openDrawer(),
            actions: [
              IconButton(
                tooltip: 'Refresh Users',
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
                    : () =>
                          ref.read(cmsUsersControllerProvider.notifier).load(),
              ),
            ],
          ),
          Expanded(child: _buildContent(context, ref, state)),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    CmsUsersState state,
  ) {
    if (state.isLoading && state.users.isEmpty) {
      return const CmsLoadingView(message: 'Loading user directory...');
    }
    if (state.errorMessage != null && state.users.isEmpty) {
      return CmsErrorView(
        message: state.errorMessage!,
        onRetry: () => ref.read(cmsUsersControllerProvider.notifier).load(),
      );
    }

    final filtered = state.filteredUsers;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter Toolbar
          CmsCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    onChanged: (val) => ref
                        .read(cmsUsersControllerProvider.notifier)
                        .setSearchQuery(val),
                    style: const TextStyle(
                      color: CmsTheme.textPrimary,
                      fontSize: 13,
                    ),
                    decoration: const InputDecoration(
                      hintText:
                          'Search users by display name or email address...',
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
                Wrap(
                  spacing: 6,
                  children: [
                    _buildRoleChip(ref, state, 'all', 'All Roles'),
                    _buildRoleChip(ref, state, 'learner', 'Learners'),
                    _buildRoleChip(ref, state, 'admin', 'Admins'),
                    _buildRoleChip(
                      ref,
                      state,
                      'content_manager',
                      'Content Mgrs',
                    ),
                    _buildRoleChip(ref, state, 'support', 'Support'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Users Table
          CmsCard(
            title: 'Directory Records (${filtered.length})',
            subtitle: 'Users registered in authentication database',
            padding: EdgeInsets.zero,
            child: filtered.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'No user records match your filter criteria.',
                        style: TextStyle(
                          color: CmsTheme.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                : CmsDataTable(
                    columns: const [
                      CmsTableColumn(label: 'Identity', flex: 4),
                      CmsTableColumn(label: 'Role', flex: 2),
                      CmsTableColumn(label: 'Status', flex: 2),
                      CmsTableColumn(label: 'Enrollments', flex: 2),
                      CmsTableColumn(label: 'Registered', flex: 2),
                    ],
                    rows: filtered.map((u) {
                      return CmsTableRow(
                        cells: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                u.displayName,
                                style: const TextStyle(
                                  color: CmsTheme.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                u.email,
                                style: const TextStyle(
                                  color: CmsTheme.textMuted,
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                          CmsBadge.forRole(u.role.value),
                          CmsBadge(
                            label: u.isActive ? 'ACTIVE' : 'INACTIVE',
                            type: u.isActive
                                ? CmsBadgeType.success
                                : CmsBadgeType.danger,
                          ),
                          Text(
                            '${u.enrollmentCount} courses',
                            style: const TextStyle(
                              color: CmsTheme.textPrimary,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            _formatDate(u.createdAt),
                            style: const TextStyle(
                              color: CmsTheme.textSecondary,
                              fontSize: 12,
                            ),
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

  Widget _buildRoleChip(
    WidgetRef ref,
    CmsUsersState state,
    String value,
    String label,
  ) {
    final isSelected = state.selectedRole == value;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) =>
          ref.read(cmsUsersControllerProvider.notifier).setRole(value),
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

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

String _safeRoute(BuildContext context, String fallback) {
  try {
    return GoRouterState.of(context).uri.path;
  } on Object catch (_) {
    return fallback;
  }
}
