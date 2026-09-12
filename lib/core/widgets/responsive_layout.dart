import 'package:flutter/widgets.dart';

import 'package:learning_platform/core/theme/app_breakpoints.dart';

class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    required this.compact,
    required this.medium,
    required this.expanded,
    super.key,
  });

  final Widget compact;
  final Widget medium;
  final Widget expanded;

  @override
  Widget build(BuildContext context) {
    final sizeClass = AppBreakpoints.fromWidth(
      MediaQuery.sizeOf(context).width,
    );
    return switch (sizeClass) {
      WindowSizeClass.compact => compact,
      WindowSizeClass.medium => medium,
      WindowSizeClass.expanded => expanded,
    };
  }
}
