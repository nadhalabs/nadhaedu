import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_platform/features/content_protection/application/content_protection_service.dart';
import 'package:learning_platform/features/content_protection/data/content_protection_platform.dart';
import 'package:learning_platform/features/content_protection/domain/content_protection_policy.dart';
import 'package:learning_platform/features/content_protection/presentation/widgets/protected_content_gate.dart';

void main() {
  group('ProtectedContentGate Widget Tests', () {
    late MockContentProtectionPlatform mockPlatform;

    setUp(() {
      mockPlatform = MockContentProtectionPlatform();
    });

    tearDown(() {
      mockPlatform.dispose();
    });

    Widget createWidget({
      ContentProtectionPolicy policy =
          ContentProtectionPolicy.blockCaptureWhereSupported,
      ValueChanged<bool>? onCaptureChanged,
    }) {
      return ProviderScope(
        overrides: [
          contentProtectionPlatformProvider.overrideWithValue(mockPlatform),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ProtectedContentGate(
              policy: policy,
              onCaptureChanged: onCaptureChanged,
              child: const Text('Protected Premium Content'),
            ),
          ),
        ),
      );
    }

    testWidgets('renders protected content when screen capture is inactive', (
      tester,
    ) async {
      await tester.pumpWidget(createWidget());
      await tester.pump();

      expect(find.text('Protected Premium Content'), findsOneWidget);
      expect(find.text('Screen recording or sharing is active'), findsNothing);
      expect(mockPlatform.enableCallCount, 1);
    });

    testWidgets(
      'pauses and displays neutral redaction when screen capture starts',
      (tester) async {
        bool? lastCaptureStatus;

        await tester.pumpWidget(
          createWidget(
            onCaptureChanged: (isCaptured) => lastCaptureStatus = isCaptured,
          ),
        );
        await tester.pump();

        expect(find.text('Protected Premium Content'), findsOneWidget);

        // Native platform notifies active screen capture
        mockPlatform.simulateCaptureStateChanged(
          isCaptured: true,
          type: 'screen_recording',
        );
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text('Protected Premium Content'), findsNothing);
        expect(
          find.text('Screen recording or sharing is active'),
          findsOneWidget,
        );
        expect(
          find.text('Stop screen capture to continue this protected lesson.'),
          findsOneWidget,
        );
        expect(lastCaptureStatus, isTrue);

        // Native platform notifies capture stopped
        mockPlatform.simulateCaptureStateChanged(isCaptured: false);
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text('Protected Premium Content'), findsOneWidget);
        expect(
          find.text('Screen recording or sharing is active'),
          findsNothing,
        );
        expect(lastCaptureStatus, isFalse);
      },
    );

    testWidgets('disposes and releases protection lock on unmount', (
      tester,
    ) async {
      await tester.pumpWidget(createWidget());
      await tester.pump();
      expect(mockPlatform.enableCallCount, 1);

      // Navigate away / unmount
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            contentProtectionPlatformProvider.overrideWithValue(mockPlatform),
          ],
          child: const MaterialApp(
            home: Scaffold(body: Text('Catalog Screen')),
          ),
        ),
      );
      await tester.pump();

      expect(mockPlatform.disableCallCount, 1);
    });

    testWidgets('Policy.none does not acquire lock or redact on capture', (
      tester,
    ) async {
      await tester.pumpWidget(
        createWidget(policy: ContentProtectionPolicy.none),
      );
      await tester.pump();

      expect(mockPlatform.enableCallCount, 0);

      mockPlatform.simulateCaptureStateChanged(isCaptured: true);
      await tester.pump();

      expect(find.text('Protected Premium Content'), findsOneWidget);
      expect(find.text('Screen recording or sharing is active'), findsNothing);
    });
  });
}
