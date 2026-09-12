import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:learning_platform/core/widgets/responsive_layout.dart';

void main() {
  testWidgets('selects an expanded composition at desktop width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: ResponsiveLayout(
          compact: Text('compact'),
          medium: Text('medium'),
          expanded: Text('expanded'),
        ),
      ),
    );
    expect(find.text('expanded'), findsOneWidget);
  });
}
