import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_platform/features/content_protection/application/content_protection_service.dart';
import 'package:learning_platform/features/content_protection/data/content_protection_platform.dart';
import 'package:learning_platform/features/content_protection/domain/content_protection_policy.dart';
import 'package:learning_platform/features/content_protection/presentation/widgets/protected_content_gate.dart';

void main() {
  group('Unprotected Screens Screenshot Capability Tests', () {
    late MockContentProtectionPlatform mockPlatform;

    setUp(() {
      mockPlatform = MockContentProtectionPlatform();
    });

    tearDown(() {
      mockPlatform.dispose();
    });

    testWidgets('Ordinary UI screens do not invoke enableProtection', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            contentProtectionPlatformProvider.overrideWithValue(mockPlatform),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  Text('Course Catalog Home'),
                  Text('Learner Profile'),
                  Text('Marketing Free Page'),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Course Catalog Home'), findsOneWidget);
      expect(mockPlatform.enableCallCount, 0);
      expect(mockPlatform.disableCallCount, 0);
    });

    testWidgets('Free preview video lessons do not lock window', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            contentProtectionPlatformProvider.overrideWithValue(mockPlatform),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ProtectedContentGate(
                policy: ContentProtectionPolicy.none,
                child: Text('Free Preview Lesson Video'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Free Preview Lesson Video'), findsOneWidget);
      expect(mockPlatform.enableCallCount, 0);
    });
  });
}
