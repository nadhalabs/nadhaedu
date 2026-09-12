import 'package:flutter_test/flutter_test.dart';
import 'package:learning_platform/features/commerce/data/foundation_commerce_data_source.dart';
import 'package:learning_platform/features/commerce/domain/payment_transaction.dart';
import 'package:learning_platform/features/commerce/domain/subscription.dart';

void main() {
  group('FoundationCommerceDataSource Tests', () {
    late FoundationCommerceDataSource dataSource;

    setUp(() {
      dataSource = FoundationCommerceDataSource();
    });

    test('fetches seed subscription plans and products', () async {
      final plans = await dataSource.fetchSubscriptionPlans();
      final courses = await dataSource.fetchCourseProducts();
      final bundles = await dataSource.fetchBundleProducts();

      expect(plans, isNotEmpty);
      expect(courses, isNotEmpty);
      expect(bundles, isNotEmpty);

      final proAnnual = plans.firstWhere((p) => p.id == 'plan_pro_annual');
      expect(proAnnual.tier, SubscriptionTier.pro);
      expect(proAnnual.billingInterval, BillingInterval.annual);
      expect(proAnnual.hasSavings, isTrue);
    });

    test('validates valid and invalid coupons', () async {
      final validCoupon = await dataSource.validateCoupon('SAVE20');
      expect(validCoupon, isNotNull);
      expect(validCoupon!.discountValue, 20);

      final invalidCoupon = await dataSource.validateCoupon('INVALID_CODE');
      expect(invalidCoupon, isNull);
    });

    test(
      'verifies successful subscription transaction and grants entitlement',
      () async {
        final tx = PaymentTransaction(
          id: 'tx_sub_test',
          provider: CommerceProvider.mock,
          providerTransactionId: 'plan_pro_annual',
          receiptPayload: 'payload',
          status: PaymentTransactionStatus.success,
          timestamp: DateTime.now().toUtc(),
        );

        final result = await dataSource.verifyTransaction(
          transaction: tx,
          learnerId: 'learner_100',
        );

        expect(result.isSuccess, isTrue);
        expect(result.subscription, isNotNull);
        expect(result.subscription!.planId, 'plan_pro_annual');
        expect(result.grantedEntitlements, isNotEmpty);
        expect(result.grantedEntitlements.first.status.isUsable, isTrue);

        final activeSub = await dataSource.fetchLearnerActiveSubscription(
          'learner_100',
        );
        expect(activeSub, isNotNull);
        expect(activeSub!.id, result.subscription!.id);
      },
    );

    test(
      'verifies course product purchase and grants perpetual course entitlement',
      () async {
        final tx = PaymentTransaction(
          id: 'tx_course_test',
          provider: CommerceProvider.mock,
          providerTransactionId: 'prod_course_1',
          receiptPayload: 'payload',
          status: PaymentTransactionStatus.success,
          timestamp: DateTime.now().toUtc(),
        );

        final result = await dataSource.verifyTransaction(
          transaction: tx,
          learnerId: 'learner_101',
        );

        expect(result.isSuccess, isTrue);
        expect(result.purchase, isNotNull);
        expect(result.purchase!.productId, 'prod_course_1');
        expect(result.grantedEntitlements, isNotEmpty);
        expect(result.grantedEntitlements.first.isPerpetual, isTrue);

        final purchases = await dataSource.fetchLearnerPurchases('learner_101');
        expect(purchases.length, 1);
      },
    );

    test('cancels active subscription', () async {
      final tx = PaymentTransaction(
        id: 'tx_sub_cancel',
        provider: CommerceProvider.mock,
        providerTransactionId: 'plan_pro_monthly',
        receiptPayload: 'payload',
        status: PaymentTransactionStatus.success,
        timestamp: DateTime.now().toUtc(),
      );

      final result = await dataSource.verifyTransaction(
        transaction: tx,
        learnerId: 'learner_102',
      );

      final cancelled = await dataSource.cancelSubscription(
        subscriptionId: result.subscription!.id,
        learnerId: 'learner_102',
        reason: 'Too expensive',
      );

      expect(cancelled.status, SubscriptionStatus.cancelled);
      expect(cancelled.cancelAtPeriodEnd, isTrue);
      expect(cancelled.cancellationReason, 'Too expensive');
    });
  });
}
