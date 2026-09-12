import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:learning_platform/core/widgets/content_states.dart';

void main() {
  testWidgets('error view exposes a usable retry action', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(home: ErrorView(onAction: () => retries++)),
    );
    await tester.tap(find.text('Retry'));
    expect(retries, 1);
    expect(
      tester.getSize(find.byType(ElevatedButton)).height,
      greaterThanOrEqualTo(48),
    );
  });
}
