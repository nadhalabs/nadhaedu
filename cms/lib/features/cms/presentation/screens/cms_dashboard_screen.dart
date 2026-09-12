import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nadha_cms/core/theme/app_breakpoints.dart';
import 'package:nadha_cms/features/cms/application/cms_providers.dart';
import 'package:nadha_cms/features/cms/domain/cms_dashboard_data.dart';
import 'package:nadha_cms/features/cms/presentation/theme/cms_theme.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_badge.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_card.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_data_table.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_header.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_state_views.dart';

class CmsDashboardScreen extends ConsumerWidget {
  const CmsDashboardScreen({super.key, this.currentRoute});

  final String? currentRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cmsDashboardControllerProvider);
    final route = currentRoute ?? _safeRoute(context, '/admin/dashboard');
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < AppBreakpoints.medium;

    return Scaffold(
      backgroundColor: CmsTheme.canvasColor,
      body: Column(
        children: [
          CmsHeader(
            currentRoute: route,
            title: 'Platform Operations Dashboard',
            subtitle:
                'Real-time authoritative platform telemetry and operational health',
            showMenuButton: isMobile,
            onMenuTap: () => Scaffold.of(context).openDrawer(),
            actions: [
              IconButton(
                tooltip: 'Refresh Telemetry',
                icon: state.isRefreshing
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
                onPressed: state.isRefreshing
                    ? null
                    : () => ref
                          .read(cmsDashboardControllerProvider.notifier)
                          .refresh(),
              ),
            ],
          ),
          Expanded(child: _buildBody(context, ref, state)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, dynamic state) {
    if (state.isLoading) {
      return const CmsLoadingView(
        message: 'Aggregating platform telemetry from backend...',
      );
    }
    if (state.errorMessage != null && state.data == null) {
      return CmsErrorView(
        message: state.errorMessage!,
        onRetry: () => ref.read(cmsDashboardControllerProvider.notifier).load(),
      );
    }
    final data = state.data as CmsDashboardData?;
    if (data == null) {
      return const CmsEmptyView(
        title: 'No Data Available',
        message: 'No platform telemetry could be retrieved from the backend.',
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Platform & Readiness Warnings
          if (data.systemReadiness.warnings.isNotEmpty) ...[
            _buildReadinessWarningBanner(context, data.systemReadiness),
            const SizedBox(height: 20),
          ],

          // 2. Core Operational Metrics Grid
          _buildMetricsGrid(context, data.metrics),
          const SizedBox(height: 24),

          // 3. Tables Row / Column (Recent Privileged Activity & Recent Purchases)
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 1000) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 6,
                      child: _buildRecentActivityCard(
                        context,
                        data.recentActivity,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 5,
                      child: _buildRecentPurchasesCard(
                        context,
                        data.recentPurchases,
                      ),
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildRecentActivityCard(context, data.recentActivity),
                    const SizedBox(height: 20),
                    _buildRecentPurchasesCard(context, data.recentPurchases),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReadinessWarningBanner(
    BuildContext context,
    CmsSystemReadiness readiness,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2E1C0C),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: CmsTheme.warningColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: CmsTheme.warningColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Operational Environment Notice',
                  style: TextStyle(
                    color: CmsTheme.warningText,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                for (final w in readiness.warnings)
                  Text(
                    '• ${w.message}',
                    style: const TextStyle(
                      color: Color(0xFFFDE68A),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
              ],
            ),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: CmsTheme.warningText,
              side: const BorderSide(color: CmsTheme.warningColor),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            onPressed: () => context.go('/admin/system'),
            child: const Text(
              'View Diagnostics',
              style: TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(BuildContext context, CmsDashboardMetrics m) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 1100
            ? 6
            : (constraints.maxWidth >= 750 ? 3 : 2);

        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.4,
          children: [
            CmsMetricCard(
              title: 'Total Users',
              value: m.totalUsers.toString(),
              subtitle: '${m.totalLearners} learners',
              icon: Icons.people_outline,
              iconColor: CmsTheme.primaryAccent,
            ),
            CmsMetricCard(
              title: 'Active Learners',
              value: m.activeLearners.toString(),
              subtitle: 'Last 30 days active',
              icon: Icons.bolt,
              iconColor: CmsTheme.successColor,
              badge: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: CmsTheme.successColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            CmsMetricCard(
              title: 'Total Courses',
              value: m.totalCourses.toString(),
              subtitle:
                  '${m.publishedCourses} published, ${m.draftCourses} draft',
              icon: Icons.menu_book_outlined,
              iconColor: const Color(0xFFA5B4FC),
            ),
            CmsMetricCard(
              title: 'Enrollments',
              value: m.totalEnrollments.toString(),
              subtitle: 'Course registrations',
              icon: Icons.assignment_ind_outlined,
              iconColor: CmsTheme.infoColor,
            ),
            CmsMetricCard(
              title: 'Commerce Volume',
              value: m.totalPurchases.toString(),
              subtitle: '${m.activeSubscriptions} active subs',
              icon: Icons.receipt_long_outlined,
              iconColor: const Color(0xFFFBBF24),
            ),
            CmsMetricCard(
              title: 'Certificates',
              value: m.totalCertificatesIssued.toString(),
              subtitle: '${m.recentCompletions} recent lesson completions',
              icon: Icons.workspace_premium_outlined,
              iconColor: const Color(0xFF34D399),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRecentActivityCard(
    BuildContext context,
    List<CmsRecentActivity> activities,
  ) {
    return CmsCard(
      title: 'Recent Privileged Admin Activity',
      subtitle: 'Authoritative audit trail of recent operational mutations',
      padding: EdgeInsets.zero,
      action: TextButton.icon(
        onPressed: () => context.go('/admin/audit-logs'),
        icon: const Icon(Icons.arrow_forward, size: 14),
        label: const Text('View All', style: TextStyle(fontSize: 12)),
      ),
      child: activities.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No privileged admin activity recorded yet.',
                  style: TextStyle(color: CmsTheme.textMuted, fontSize: 13),
                ),
              ),
            )
          : CmsDataTable(
              columns: const [
                CmsTableColumn(label: 'Actor', flex: 3),
                CmsTableColumn(label: 'Action', flex: 3),
                CmsTableColumn(label: 'Target', flex: 2),
                CmsTableColumn(label: 'Result', flex: 2),
              ],
              rows: activities.take(8).map((a) {
                return CmsTableRow(
                  cells: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          a.actorName ?? a.actorEmail ?? 'System',
                          style: const TextStyle(
                            color: CmsTheme.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _timeAgo(a.timestamp),
                          style: const TextStyle(
                            color: CmsTheme.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      a.action,
                      style: const TextStyle(
                        color: CmsTheme.textPrimary,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${a.targetEntity}:${a.targetId.substring(0, a.targetId.length.clamp(0, 8))}',
                      style: const TextStyle(
                        color: CmsTheme.textSecondary,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    CmsBadge(
                      label: a.result.toUpperCase(),
                      type: a.result == 'success'
                          ? CmsBadgeType.success
                          : CmsBadgeType.danger,
                    ),
                  ],
                );
              }).toList(),
            ),
    );
  }

  Widget _buildRecentPurchasesCard(
    BuildContext context,
    List<CmsRecentPurchase> purchases,
  ) {
    return CmsCard(
      title: 'Recent Transactions',
      subtitle: 'Authoritative server-verified commerce events',
      padding: EdgeInsets.zero,
      child: purchases.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No verified transactions recorded yet.',
                  style: TextStyle(color: CmsTheme.textMuted, fontSize: 13),
                ),
              ),
            )
          : CmsDataTable(
              columns: const [
                CmsTableColumn(label: 'Order ID', flex: 3),
                CmsTableColumn(label: 'Learner', flex: 3),
                CmsTableColumn(label: 'Amount', flex: 2),
                CmsTableColumn(label: 'Status', flex: 2),
              ],
              rows: purchases.take(8).map((p) {
                return CmsTableRow(
                  cells: [
                    Text(
                      p.orderId,
                      style: const TextStyle(
                        color: CmsTheme.textPrimary,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                    Text(
                      p.learnerEmail ?? p.learnerId,
                      style: const TextStyle(
                        color: CmsTheme.textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      p.formattedPrice,
                      style: const TextStyle(
                        color: CmsTheme.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    CmsBadge(
                      label: p.status.toUpperCase(),
                      type: p.status == 'completed'
                          ? CmsBadgeType.success
                          : CmsBadgeType.warning,
                    ),
                  ],
                );
              }).toList(),
            ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

String _safeRoute(BuildContext context, String fallback) {
  try {
    return GoRouterState.of(context).uri.path;
  } on Object catch (_) {
    return fallback;
  }
}
