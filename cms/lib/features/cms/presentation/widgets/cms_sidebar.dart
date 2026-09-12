import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nadha_cms/features/authentication/application/auth_providers.dart';
import 'package:nadha_cms/features/cms/presentation/theme/cms_theme.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_badge.dart';

class CmsSidebarItem {
  const CmsSidebarItem({
    required this.title,
    required this.icon,
    required this.route,
  });

  final String title;
  final IconData icon;
  final String route;
}

const cmsNavigationItems = [
  CmsSidebarItem(
    title: 'Academic Catalog',
    icon: Icons.school_outlined,
    route: '/admin/academic',
  ),
  CmsSidebarItem(
    title: 'Dashboard',
    icon: Icons.dashboard_outlined,
    route: '/admin/dashboard',
  ),
  CmsSidebarItem(
    title: 'Courses & Content',
    icon: Icons.auto_stories_outlined,
    route: '/admin/courses',
  ),
  CmsSidebarItem(
    title: 'Learner Operations',
    icon: Icons.people_outline,
    route: '/admin/learners',
  ),
  CmsSidebarItem(
    title: 'Commerce',
    icon: Icons.payments_outlined,
    route: '/admin/commerce',
  ),
  CmsSidebarItem(
    title: 'Entitlements',
    icon: Icons.vpn_key_outlined,
    route: '/admin/entitlements',
  ),
  CmsSidebarItem(
    title: 'Notifications',
    icon: Icons.notifications_outlined,
    route: '/admin/notifications',
  ),
  CmsSidebarItem(
    title: 'Audit Trail',
    icon: Icons.history_edu_outlined,
    route: '/admin/audit-logs',
  ),
  CmsSidebarItem(
    title: 'System & Health',
    icon: Icons.health_and_safety_outlined,
    route: '/admin/system',
  ),
];

const cmsUltimateControlItems = [
  CmsSidebarItem(
    title: 'Admins',
    icon: Icons.admin_panel_settings_outlined,
    route: '/admin/super/admins',
  ),
  CmsSidebarItem(
    title: 'Platform Controls',
    icon: Icons.warning_amber_outlined,
    route: '/admin/super/controls',
  ),
  CmsSidebarItem(
    title: 'Integrations',
    icon: Icons.hub_outlined,
    route: '/admin/super/integrations',
  ),
  CmsSidebarItem(
    title: 'Readiness',
    icon: Icons.monitor_heart_outlined,
    route: '/admin/super/readiness',
  ),
];

class CmsSidebar extends ConsumerWidget {
  const CmsSidebar({
    super.key,
    required this.currentRoute,
    this.isCompact = false,
  });

  final String currentRoute;
  final bool isCompact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.session?.identity;

    return Container(
      width: isCompact ? 72 : 240,
      decoration: const BoxDecoration(
        color: CmsTheme.surfaceColor,
        border: Border(
          right: BorderSide(color: CmsTheme.borderColor, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Logo & brand
          Container(
            height: 64,
            padding: EdgeInsets.symmetric(horizontal: isCompact ? 12 : 16),
            alignment: Alignment.centerLeft,
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: CmsTheme.borderColor, width: 1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: CmsTheme.primaryAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: CmsTheme.primaryAccent.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings,
                    color: CmsTheme.primaryAccent,
                    size: 18,
                  ),
                ),
                if (!isCompact) ...[
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NADHA EDU',
                          style: TextStyle(
                            color: CmsTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'CMS • OPERATIONS CONTROL',
                          style: TextStyle(
                            color: CmsTheme.textMuted,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Nav items
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              itemCount:
                  cmsNavigationItems.length +
                  (user?.isSuperAdmin ?? false
                      ? cmsUltimateControlItems.length
                      : 0),
              separatorBuilder: (context, index) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final item = index < cmsNavigationItems.length
                    ? cmsNavigationItems[index]
                    : cmsUltimateControlItems[index -
                          cmsNavigationItems.length];
                final isSelected = currentRoute.startsWith(item.route);

                if (isCompact) {
                  return Tooltip(
                    message: item.title,
                    child: InkWell(
                      onTap: () => context.go(item.route),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? CmsTheme.primaryAccent.withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: isSelected
                              ? Border.all(
                                  color: CmsTheme.primaryAccent.withValues(
                                    alpha: 0.5,
                                  ),
                                )
                              : null,
                        ),
                        child: Icon(
                          item.icon,
                          color: isSelected
                              ? CmsTheme.primaryAccent
                              : CmsTheme.textSecondary,
                          size: 20,
                        ),
                      ),
                    ),
                  );
                }

                return InkWell(
                  onTap: () => context.go(item.route),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? CmsTheme.primaryAccent.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: isSelected
                          ? Border.all(
                              color: CmsTheme.primaryAccent.withValues(
                                alpha: 0.4,
                              ),
                            )
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          item.icon,
                          color: isSelected
                              ? CmsTheme.primaryAccent
                              : CmsTheme.textSecondary,
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              color: isSelected
                                  ? CmsTheme.textPrimary
                                  : CmsTheme.textSecondary,
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // User & return footer
          Container(
            padding: EdgeInsets.all(isCompact ? 8 : 12),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: CmsTheme.borderColor, width: 1),
              ),
            ),
            child: Column(
              children: [
                if (!isCompact && user != null) ...[
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: CmsTheme.cardColor,
                        child: Text(
                          user.displayName.isNotEmpty
                              ? user.displayName[0].toUpperCase()
                              : 'A',
                          style: const TextStyle(
                            color: CmsTheme.primaryAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.displayName,
                              style: const TextStyle(
                                color: CmsTheme.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            CmsBadge.forRole(user.role),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
