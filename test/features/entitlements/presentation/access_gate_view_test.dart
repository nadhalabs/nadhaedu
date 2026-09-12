import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_platform/features/entitlements/domain/access_decision.dart';
import 'package:learning_platform/features/entitlements/domain/access_reason.dart';
import 'package:learning_platform/features/entitlements/domain/resource_type.dart';
import 'package:learning_platform/features/entitlements/presentation/widgets/access_gate_view.dart';

void main() {
  group('AccessGateView', () {
    testWidgets('renders locked paywall gate with unlock action callback', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool unlockClicked = false;
      final decision = AccessDecision(
        resourceType: ResourceType.lesson,
        resourceId: 'lesson-1',
        canAccess: false,
        state: AccessState.locked,
        reason: AccessReason.locked,
        evaluatedAt: DateTime.now().toUtc(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccessGateView(
              decision: decision,
              resourceTitle: 'Advanced State Architecture',
              onUnlock: () {
                unlockClicked = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Premium Content Locked'), findsOneWidget);
      expect(find.text('Advanced State Architecture'), findsOneWidget);
      expect(find.text('Unlock with Subscription'), findsOneWidget);

      await tester.tap(find.text('Unlock with Subscription'));
      expect(unlockClicked, isTrue);
    });

    testWidgets('renders subscription expired messaging and renew action', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final decision = AccessDecision(
        resourceType: ResourceType.lesson,
        resourceId: 'lesson-1',
        canAccess: false,
        state: AccessState.expired,
        reason: AccessReason.subscriptionExpired,
        evaluatedAt: DateTime.now().toUtc(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AccessGateView(decision: decision)),
        ),
      );

      expect(find.text('Subscription Expired'), findsOneWidget);
      expect(find.text('Renew Subscription'), findsOneWidget);
    });
  });
}
