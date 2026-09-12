import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_platform/features/commerce/domain/subscription.dart';
import 'package:learning_platform/features/commerce/presentation/widgets/inline_locked_state.dart';
import 'package:learning_platform/features/commerce/presentation/widgets/premium_badge.dart';
import 'package:learning_platform/features/commerce/presentation/widgets/upgrade_cta_button.dart';

void main() {
  group('Commerce Presentation Widgets Tests', () {
    testWidgets('PremiumBadge renders label and accessible semantics', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PremiumBadge(tier: SubscriptionTier.pro)),
        ),
      );

      expect(find.text('PRO'), findsOneWidget);
      expect(find.byIcon(Icons.stars_rounded), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(PremiumBadge)),
        matchesSemantics(label: 'PRO membership badge'),
      );
    });

    testWidgets('InlineLockedState renders locked view with unlock callback', (
      tester,
    ) async {
      bool unlockClicked = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InlineLockedState(
              title: 'Locked Quiz',
              description: 'Requires subscription',
              ctaLabel: 'Unlock Now',
              onUnlock: () => unlockClicked = true,
            ),
          ),
        ),
      );

      expect(find.text('Locked Quiz'), findsOneWidget);
      expect(find.text('Requires subscription'), findsOneWidget);
      expect(find.text('Unlock Now'), findsOneWidget);

      await tester.tap(find.text('Unlock Now'));
      await tester.pump();

      expect(unlockClicked, isTrue);
    });

    testWidgets('UpgradeCtaButton invokes onPressed callback', (tester) async {
      bool pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UpgradeCtaButton(
              label: 'Upgrade to Pro',
              onPressed: () => pressed = true,
            ),
          ),
        ),
      );

      expect(find.text('Upgrade to Pro'), findsOneWidget);

      await tester.tap(find.text('Upgrade to Pro'));
      await tester.pump();

      expect(pressed, isTrue);
    });
  });
}
