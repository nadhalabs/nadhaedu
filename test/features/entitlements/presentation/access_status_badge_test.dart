import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_platform/features/entitlements/domain/access_decision.dart';
import 'package:learning_platform/features/entitlements/presentation/widgets/access_status_badge.dart';

void main() {
  group('AccessStatusBadge', () {
    for (final state in AccessState.values) {
      testWidgets('renders badge and semantics for state: ${state.name}', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: AccessStatusBadge(state: state)),
          ),
        );

        final label = switch (state) {
          AccessState.free => 'Free',
          AccessState.preview => 'Preview',
          AccessState.locked => 'Locked',
          AccessState.included => 'Included',
          AccessState.purchased => 'Purchased',
          AccessState.subscribed => 'Subscribed',
          AccessState.expired => 'Expired',
          AccessState.unavailable => 'Unavailable',
        };

        expect(find.text(label), findsOneWidget);
        expect(
          tester.getSemantics(find.byType(AccessStatusBadge)),
          matchesSemantics(label: 'Access status: $label'),
        );
      });
    }

    testWidgets('compact mode renders smaller layout', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AccessStatusBadge(
              state: AccessState.subscribed,
              compact: true,
            ),
          ),
        ),
      );

      expect(find.text('Subscribed'), findsOneWidget);
    });
  });
}
