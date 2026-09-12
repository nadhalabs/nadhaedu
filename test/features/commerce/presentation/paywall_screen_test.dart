import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_platform/bootstrap/providers.dart';
import 'package:learning_platform/config/branding_config.dart';
import 'package:learning_platform/core/analytics/analytics_service.dart';
import 'package:learning_platform/features/commerce/application/commerce_controller.dart';
import 'package:learning_platform/features/commerce/application/commerce_providers.dart';
import 'package:learning_platform/features/commerce/data/commerce_repository_impl.dart';
import 'package:learning_platform/features/commerce/data/foundation_commerce_data_source.dart';
import 'package:learning_platform/features/commerce/data/foundation_platform_billing_service.dart';
import 'package:learning_platform/features/commerce/domain/commerce_analytics.dart';
import 'package:learning_platform/features/commerce/presentation/screens/paywall_screen.dart';

void main() {
  group('PaywallScreen Widget Tests', () {
    late FoundationCommerceDataSource dataSource;
    late CommerceRepositoryImpl repository;
    late FoundationPlatformBillingService billingService;
    late CommerceController controller;

    setUp(() async {
      dataSource = FoundationCommerceDataSource();
      repository = CommerceRepositoryImpl(
        dataSource: dataSource,
        learnerId: 'learner_paywall_test',
      );
      billingService = FoundationPlatformBillingService();
      controller = CommerceController(
        repository: repository,
        billingService: billingService,
        analytics: const CommerceAnalyticsTracker(NoopAnalyticsService()),
        learnerId: 'learner_paywall_test',
      );
      await controller.initialize();
    });

    testWidgets(
      'renders full-screen paywall with plans and store disclaimers',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              brandingConfigProvider.overrideWithValue(
                const BrandingConfig(displayName: 'Test Platform'),
              ),
              commerceControllerProvider.overrideWith((ref) => controller),
              commerceAnalyticsTrackerProvider.overrideWithValue(
                const CommerceAnalyticsTracker(NoopAnalyticsService()),
              ),
            ],
            child: const MaterialApp(home: PaywallScreen()),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Test Platform Pro'), findsOneWidget);
        expect(
          find.text('Unlock Your Full Learning Potential'),
          findsOneWidget,
        );
        expect(find.text('Unlimited Course Catalog Access'), findsOneWidget);
        expect(find.text('Official Verified Certificates'), findsOneWidget);
        expect(find.text('Restore'), findsOneWidget);
        expect(
          find.textContaining('Subscriptions automatically renew'),
          findsOneWidget,
        );

        // Verify plans are displayed
        expect(find.text('Pro Annual'), findsOneWidget);
        expect(find.text('Pro Monthly'), findsOneWidget);
      },
    );

    testWidgets('user can select a plan and initiate purchase', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            brandingConfigProvider.overrideWithValue(
              const BrandingConfig(displayName: 'Test Platform'),
            ),
            commerceControllerProvider.overrideWith((ref) => controller),
            commerceAnalyticsTrackerProvider.overrideWithValue(
              const CommerceAnalyticsTracker(NoopAnalyticsService()),
            ),
          ],
          child: const MaterialApp(home: PaywallScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on Pro Monthly plan
      await tester.tap(find.text('Pro Monthly'));
      await tester.pumpAndSettle();

      // Tap on Subscribe button
      final subscribeBtn = find.widgetWithText(
        FilledButton,
        'Start 7-Day Free Trial',
      );
      expect(subscribeBtn, findsOneWidget);

      await tester.tap(subscribeBtn);
      await tester.pumpAndSettle();

      expect(controller.state.activeSubscription, isNotNull);
    });
  });
}
