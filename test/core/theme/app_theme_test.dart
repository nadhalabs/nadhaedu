import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:learning_platform/core/theme/app_theme.dart';

void main() {
  test('provides Material 3 light and dark themes', () {
    expect(AppTheme.light().brightness, Brightness.light);
    expect(AppTheme.dark().brightness, Brightness.dark);
    expect(AppTheme.light().useMaterial3, isTrue);
  });
}
