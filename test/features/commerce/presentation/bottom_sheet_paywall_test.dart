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
import 'package:learning_platform/features/commerce/presentation/widgets/bottom_sheet_paywall.dart';

void main() {
  group('BottomSheetPaywall Widget Tests', () {
    late FoundationCommerceDataSource dataSource;
    late CommerceRepositoryImpl repository;
    late FoundationPlatformBillingService billingService;
    late CommerceController controller;

    setUp(() async {
      dataSource = FoundationCommerceDataSource();
      repository = CommerceRepositoryImpl(
        dataSource: dataSource,
        learnerId: 'learner_modal_test',
      );
      billingService = FoundationPlatformBillingService();
      controller = CommerceController(
        repository: repository,
        billingService: billingService,
        analytics: const CommerceAnalyticsTracker(NoopAnalyticsService()),
        learnerId: 'learner_modal_test',
      );
      await controller.initialize();
    });

    testWidgets('renders modal bottom sheet with plans and promo code input', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            commerceControllerProvider.overrideWith((ref) => controller),
          ],
          child: const MaterialApp(home: Scaffold(body: BottomSheetPaywall())),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Choose Your Plan'), findsOneWidget);
      expect(find.text('Restore Purchases'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Apply'), findsOneWidget);

      // Enter coupon code
      await tester.enterText(find.byType(TextField), 'SAVE20');
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Coupon applied: SAVE20'), findsOneWidget);
    });

    testWidgets(
      'renders single course unlock view when courseProduct is provided',
      (tester) async {
        final course = (await dataSource.fetchCourseProducts()).first;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              commerceControllerProvider.overrideWith((ref) => controller),
            ],
            child: MaterialApp(
              home: Scaffold(body: BottomSheetPaywall(courseProduct: course)),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Unlock Course'), findsOneWidget);
        expect(find.text(course.title), findsOneWidget);
        expect(find.text('Buy Now · ${course.formattedPrice}'), findsOneWidget);
      },
    );
  });
}
