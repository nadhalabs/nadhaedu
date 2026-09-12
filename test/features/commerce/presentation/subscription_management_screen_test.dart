import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_platform/core/analytics/analytics_service.dart';
import 'package:learning_platform/features/commerce/application/commerce_controller.dart';
import 'package:learning_platform/features/commerce/application/commerce_providers.dart';
import 'package:learning_platform/features/commerce/data/commerce_repository_impl.dart';
import 'package:learning_platform/features/commerce/data/foundation_commerce_data_source.dart';
import 'package:learning_platform/features/commerce/data/foundation_platform_billing_service.dart';
import 'package:learning_platform/features/commerce/domain/commerce_analytics.dart';
import 'package:learning_platform/features/commerce/presentation/screens/subscription_management_screen.dart';

void main() {
  group('SubscriptionManagementScreen Widget Tests', () {
    late FoundationCommerceDataSource dataSource;
    late CommerceRepositoryImpl repository;
    late FoundationPlatformBillingService billingService;
    late CommerceController controller;

    setUp(() async {
      dataSource = FoundationCommerceDataSource();
      repository = CommerceRepositoryImpl(
        dataSource: dataSource,
        learnerId: 'learner_mgmt_test',
      );
      billingService = FoundationPlatformBillingService();
      controller = CommerceController(
        repository: repository,
        billingService: billingService,
        analytics: const CommerceAnalyticsTracker(NoopAnalyticsService()),
        learnerId: 'learner_mgmt_test',
      );
      await controller.initialize();
    });

    testWidgets('renders empty state when no subscription is active', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            commerceControllerProvider.overrideWith((ref) => controller),
          ],
          child: const MaterialApp(home: SubscriptionManagementScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Manage Subscription'), findsOneWidget);
      expect(
        find.text('You do not currently have an active subscription.'),
        findsOneWidget,
      );
      expect(find.text('View Available Plans'), findsOneWidget);
    });

    testWidgets('renders active subscription details and cancellation button', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Purchase a plan first
      final plan = controller.state.plans.firstWhere(
        (p) => p.id == 'plan_pro_annual',
      );
      await controller.purchaseSubscriptionPlan(plan);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            commerceControllerProvider.overrideWith((ref) => controller),
          ],
          child: const MaterialApp(home: SubscriptionManagementScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Pro Annual'), findsOneWidget);
      expect(find.text('Status: Free Trial'), findsOneWidget);
      expect(find.text('Cancel Subscription'), findsOneWidget);
      expect(find.text('Manage in App Store / Play Store'), findsOneWidget);
    });
  });
}
