import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:learning_platform/bootstrap/providers.dart';
import 'package:learning_platform/core/routing/app_router.dart';
import 'package:learning_platform/core/theme/app_breakpoints.dart';
import 'package:learning_platform/core/theme/app_spacing.dart';

class AppShell extends ConsumerWidget {
  const AppShell({required this.child, super.key});
  final Widget child;

  static const _destinations = [
    _Destination('Home', Icons.home_outlined, AppRoutes.home),
    _Destination('Discover', Icons.explore_outlined, AppRoutes.discover),
    _Destination('Search', Icons.search, AppRoutes.search),
    _Destination('My Learning', Icons.school_outlined, AppRoutes.myLearning),
    _Destination('Profile', Icons.person_outline, AppRoutes.profile),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final selectedIndex = _destinations.indexWhere(
      (destination) => location.startsWith(destination.route),
    );
    final safeIndex = selectedIndex < 0 ? 0 : selectedIndex;
    final sizeClass = AppBreakpoints.fromWidth(
      MediaQuery.sizeOf(context).width,
    );
    if (sizeClass == WindowSizeClass.compact) {
      return Scaffold(
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: safeIndex,
          onDestinationSelected: (index) =>
              context.go(_destinations[index].route),
          destinations: [
            for (final destination in _destinations)
              NavigationDestination(
                icon: Icon(destination.icon),
                label: destination.label,
              ),
          ],
        ),
      );
    }
    final branding = ref.watch(brandingConfigProvider);
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: sizeClass == WindowSizeClass.expanded,
            selectedIndex: safeIndex,
            onDestinationSelected: (index) =>
                context.go(_destinations[index].route),
            leading: sizeClass == WindowSizeClass.expanded
                ? Padding(
                    padding: const EdgeInsets.all(AppSpacing.medium),
                    child: Text(
                      branding.wordmark,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  )
                : null,
            destinations: [
              for (final destination in _destinations)
                NavigationRailDestination(
                  icon: Icon(destination.icon),
                  label: Text(destination.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSpacing.maxContentWidth,
                ),
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _Destination {
  const _Destination(this.label, this.icon, this.route);
  final String label;
  final IconData icon;
  final String route;
}
