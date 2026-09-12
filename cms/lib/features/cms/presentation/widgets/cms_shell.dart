import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nadha_cms/core/theme/app_breakpoints.dart';
import 'package:nadha_cms/features/cms/presentation/theme/cms_theme.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_sidebar.dart';

class CmsShell extends StatefulWidget {
  const CmsShell({super.key, required this.child, this.currentRoute});

  final Widget child;
  final String? currentRoute;

  @override
  State<CmsShell> createState() => _CmsShellState();
}

class _CmsShellState extends State<CmsShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final route =
        widget.currentRoute ?? _safeRoute(context, '/admin/dashboard');
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= AppBreakpoints.expanded;
    final isTablet =
        width >= AppBreakpoints.medium && width < AppBreakpoints.expanded;

    return Theme(
      data: CmsTheme.darkTheme,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: CmsTheme.canvasColor,
        drawer: !isDesktop && !isTablet
            ? Drawer(
                backgroundColor: CmsTheme.surfaceColor,
                child: SafeArea(
                  child: CmsSidebar(currentRoute: route, isCompact: false),
                ),
              )
            : null,
        body: SafeArea(
          child: Row(
            children: [
              if (isDesktop)
                CmsSidebar(currentRoute: route, isCompact: false)
              else if (isTablet)
                CmsSidebar(currentRoute: route, isCompact: true),
              Expanded(child: widget.child),
            ],
          ),
        ),
      ),
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
