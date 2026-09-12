import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nadha_cms/features/authentication/application/auth_providers.dart';
import 'package:nadha_cms/features/cms/presentation/theme/cms_theme.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_badge.dart';

class CmsHeader extends ConsumerWidget {
  const CmsHeader({
    super.key,
    required this.currentRoute,
    this.title,
    this.subtitle,
    this.actions,
    this.onMenuTap,
    this.showMenuButton = false,
  });

  final String currentRoute;
  final String? title;
  final String? subtitle;
  final List<Widget>? actions;
  final VoidCallback? onMenuTap;
  final bool showMenuButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.session?.identity;
    final breadcrumbs = _getBreadcrumbs(currentRoute);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: CmsTheme.surfaceColor,
        border: Border(
          bottom: BorderSide(color: CmsTheme.borderColor, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top bar: breadcrumbs & status + user menu
          Row(
            children: [
              if (showMenuButton) ...[
                IconButton(
                  icon: const Icon(Icons.menu, size: 20),
                  color: CmsTheme.textPrimary,
                  onPressed: onMenuTap,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 12),
              ],
              // Breadcrumbs
              Expanded(
                child: Row(
                  children: [
                    for (int i = 0; i < breadcrumbs.length; i++) ...[
                      if (i > 0) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.chevron_right,
                          size: 14,
                          color: CmsTheme.textMuted,
                        ),
                        const SizedBox(width: 6),
                      ],
                      InkWell(
                        onTap: breadcrumbs[i].route != null
                            ? () => context.go(breadcrumbs[i].route!)
                            : null,
                        child: Text(
                          breadcrumbs[i].label,
                          style: TextStyle(
                            color: i == breadcrumbs.length - 1
                                ? CmsTheme.textPrimary
                                : CmsTheme.textMuted,
                            fontSize: 12,
                            fontWeight: i == breadcrumbs.length - 1
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // System health pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF064E3B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: CmsTheme.successColor.withValues(alpha: 0.4),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 6, color: CmsTheme.successColor),
                    SizedBox(width: 6),
                    Text(
                      'Systems Ready',
                      style: TextStyle(
                        color: CmsTheme.successText,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // User avatar & logout popup menu
              PopupMenuButton<String>(
                color: CmsTheme.cardColor,
                offset: const Offset(0, 36),
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: CmsTheme.borderColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    enabled: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.displayName ?? 'Admin',
                          style: const TextStyle(
                            color: CmsTheme.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          user?.email ?? '',
                          style: const TextStyle(
                            color: CmsTheme.textMuted,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (user != null) CmsBadge.forRole(user.role),
                        const Divider(color: CmsTheme.borderColor, height: 16),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(
                          Icons.logout,
                          size: 16,
                          color: CmsTheme.dangerColor,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Sign Out',
                          style: TextStyle(
                            color: CmsTheme.dangerColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) async {
                  if (value == 'logout') {
                    await ref.read(authControllerProvider.notifier).signOut();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: CmsTheme.cardColor,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: CmsTheme.borderColor),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: CmsTheme.primaryAccent.withValues(
                          alpha: 0.2,
                        ),
                        child: Text(
                          user?.displayName.isNotEmpty == true
                              ? user!.displayName[0].toUpperCase()
                              : 'A',
                          style: const TextStyle(
                            color: CmsTheme.primaryAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.keyboard_arrow_down,
                        size: 14,
                        color: CmsTheme.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (title != null) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title!,
                        style: const TextStyle(
                          color: CmsTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            color: CmsTheme.textSecondary,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (actions != null && actions!.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Row(mainAxisSize: MainAxisSize.min, children: actions!),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  List<({String label, String? route})> _getBreadcrumbs(String route) {
    final list = <({String label, String? route})>[
      (label: 'CMS', route: '/admin/dashboard'),
    ];

    if (route.startsWith('/admin/dashboard')) {
      list.add((label: 'Dashboard', route: null));
    } else if (route.startsWith('/admin/courses')) {
      list.add((label: 'Courses & Content', route: null));
    } else if (route.startsWith('/admin/users')) {
      list.add((label: 'Learners & Users', route: null));
    } else if (route.startsWith('/admin/audit-logs')) {
      list.add((label: 'Audit Trail', route: null));
    } else if (route.startsWith('/admin/system')) {
      list.add((label: 'System & Health', route: null));
    }
    return list;
  }
}
