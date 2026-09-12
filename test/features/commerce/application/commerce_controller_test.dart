import 'package:flutter_test/flutter_test.dart';
import 'package:learning_platform/core/analytics/analytics_service.dart';
import 'package:learning_platform/features/commerce/application/commerce_controller.dart';
import 'package:learning_platform/features/commerce/data/commerce_repository_impl.dart';
import 'package:learning_platform/features/commerce/data/foundation_commerce_data_source.dart';
import 'package:learning_platform/features/commerce/data/foundation_platform_billing_service.dart';
import 'package:learning_platform/features/commerce/domain/commerce_analytics.dart';
import 'package:learning_platform/features/commerce/domain/subscription.dart';

void main() {
  group('CommerceController Application Tests', () {
    late CommerceController controller;
    late FoundationCommerceDataSource dataSource;
    late CommerceRepositoryImpl repository;
    late FoundationPlatformBillingService billingService;
    late _RecordingAnalyticsService analyticsService;

    setUp(() async {
      dataSource = FoundationCommerceDataSource();
      repository = CommerceRepositoryImpl(
        dataSource: dataSource,
        learnerId: 'learner_ctrl_test',
      );
      billingService = FoundationPlatformBillingService();
      analyticsService = _RecordingAnalyticsService();

      controller = CommerceController(
        repository: repository,
        billingService: billingService,
        analytics: CommerceAnalyticsTracker(analyticsService),
        learnerId: 'learner_ctrl_test',
      );
      await controller.initialize();
    });

    test('initializes with loaded plans and products', () {
      expect(controller.state.plans, isNotEmpty);
      expect(controller.state.courseProducts, isNotEmpty);
      expect(controller.state.isLoading, isFalse);
    });

    test('applies valid coupon and rejects invalid coupon', () async {
      final valid = await controller.applyCoupon('SAVE20');
      expect(valid, isTrue);
      expect(controller.state.appliedCoupon?.code, 'SAVE20');

      controller.removeCoupon();
      expect(controller.state.appliedCoupon, isNull);

      final invalid = await controller.applyCoupon('INVALID_COUPON');
      expect(invalid, isFalse);
      expect(controller.state.failure, isNotNull);
    });

    test(
      'purchases subscription plan and prevents concurrent double-submission',
      () async {
        final plan = controller.state.plans.firstWhere(
          (p) => p.id == 'plan_pro_annual',
        );

        final success = await controller.purchaseSubscriptionPlan(plan);
        expect(success, isTrue);
        expect(controller.state.activeSubscription, isNotNull);
        expect(controller.state.activeSubscription!.planId, 'plan_pro_annual');
        expect(controller.state.hasActiveSubscription, isTrue);

        // Verify analytics events emitted
        expect(
          analyticsService.events.any((e) => e.name == 'subscription_started'),
          isTrue,
        );
        expect(
          analyticsService.events.any((e) => e.name == 'purchase_completed'),
          isTrue,
        );
      },
    );

    test('handles user cancellation during billing flow gracefully', () async {
      billingService.shouldSimulateUserCancellation = true;
      final plan = controller.state.plans.first;

      final result = await controller.purchaseSubscriptionPlan(plan);
      expect(result, isFalse);
      expect(controller.state.isProcessingPurchase, isFalse);
      expect(controller.state.failure, isNull);
    });

    test('purchases single course product successfully', () async {
      final course = controller.state.courseProducts.first;

      final success = await controller.purchaseCourseProduct(course);
      expect(success, isTrue);
      expect(controller.state.purchases.length, 1);
      expect(controller.state.hasPurchasedCourse(course.id), isTrue);
    });

    test('changes subscription plan with proration', () async {
      final planAnnual = controller.state.plans.firstWhere(
        (p) => p.id == 'plan_pro_annual',
      );
      await controller.purchaseSubscriptionPlan(planAnnual);

      final changed = await controller.changeSubscriptionPlan(
        newPlanId: 'plan_pro_monthly',
      );
      expect(changed, isTrue);
      expect(controller.state.activeSubscription?.planId, 'plan_pro_monthly');
    });

    test('cancels active subscription', () async {
      final plan = controller.state.plans.first;
      await controller.purchaseSubscriptionPlan(plan);

      final cancelled = await controller.cancelSubscription(
        reason: 'User request',
      );
      expect(cancelled, isTrue);
      expect(
        controller.state.activeSubscription?.status,
        SubscriptionStatus.cancelled,
      );
      expect(controller.state.activeSubscription?.cancelAtPeriodEnd, isTrue);
    });

    test('restores purchases successfully', () async {
      final plan = controller.state.plans.first;
      await controller.purchaseSubscriptionPlan(plan);

      final restored = await controller.restorePurchases();
      expect(restored, isTrue);
      expect(controller.state.activeSubscription, isNotNull);
      expect(
        analyticsService.events.any((e) => e.name == 'purchases_restored'),
        isTrue,
      );
    });
  });
}

final class _RecordingAnalyticsService implements AnalyticsService {
  final List<({String name, Map<String, Object?> properties})> events = [];

  @override
  Future<void> track(
    String event, {
    Map<String, Object?> properties = const {},
  }) async {
    events.add((name: event, properties: properties));
  }
}
