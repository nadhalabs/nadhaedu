import 'package:flutter_test/flutter_test.dart';

import 'package:learning_platform/core/theme/app_breakpoints.dart';

void main() {
  test('maps boundary widths to stable size classes', () {
    expect(AppBreakpoints.fromWidth(599), WindowSizeClass.compact);
    expect(AppBreakpoints.fromWidth(600), WindowSizeClass.medium);
    expect(AppBreakpoints.fromWidth(1023), WindowSizeClass.medium);
    expect(AppBreakpoints.fromWidth(1024), WindowSizeClass.expanded);
  });
}
