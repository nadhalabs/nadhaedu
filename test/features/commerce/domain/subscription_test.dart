import 'package:flutter_test/flutter_test.dart';
import 'package:learning_platform/features/commerce/domain/subscription.dart';

void main() {
  group('Subscription Domain Tests', () {
    final now = DateTime.now().toUtc();

    test('verifies active subscription lifecycle and status checks', () {
      final sub = Subscription(
        id: 'sub_1',
        learnerId: 'learner_1',
        planId: 'plan_pro_annual',
        tier: SubscriptionTier.pro,
        billingInterval: BillingInterval.annual,
        status: SubscriptionStatus.active,
        currentPeriodStart: now.subtract(const Duration(days: 30)),
        currentPeriodEnd: now.add(const Duration(days: 335)),
        renewsAt: now.add(const Duration(days: 335)),
      );

      expect(sub.isUsable, isTrue);
      expect(sub.isUsableAt(now), isTrue);
      expect(sub.isInGracePeriod, isFalse);
      expect(sub.isBillingRetry, isFalse);
      expect(sub.isTrialing, isFalse);
    });

    test('verifies grace period and billing retry states', () {
      final graceSub = Subscription(
        id: 'sub_grace',
        learnerId: 'learner_1',
        planId: 'plan_pro_monthly',
        tier: SubscriptionTier.pro,
        billingInterval: BillingInterval.monthly,
        status: SubscriptionStatus.inGracePeriod,
        currentPeriodStart: now.subtract(const Duration(days: 35)),
        currentPeriodEnd: now.subtract(const Duration(days: 5)),
      );

      expect(graceSub.isInGracePeriod, isTrue);
      expect(graceSub.isUsable, isTrue);
      expect(graceSub.requiresAttention, isTrue);
      expect(graceSub.isUsableAt(now), isTrue);

      final retrySub = Subscription(
        id: 'sub_retry',
        learnerId: 'learner_1',
        planId: 'plan_pro_monthly',
        tier: SubscriptionTier.pro,
        billingInterval: BillingInterval.monthly,
        status: SubscriptionStatus.billingRetry,
        currentPeriodStart: now.subtract(const Duration(days: 45)),
        currentPeriodEnd: now.subtract(const Duration(days: 15)),
      );

      expect(retrySub.isBillingRetry, isTrue);
      expect(retrySub.isUsable, isFalse);
      expect(retrySub.requiresAttention, isTrue);
      expect(retrySub.isUsableAt(now), isFalse);
    });

    test('TrialPeriod correctly checks active window and remaining days', () {
      final trial = TrialPeriod(
        startDate: now.subtract(const Duration(days: 3)),
        endDate: now.add(const Duration(days: 4)),
        durationDays: 7,
      );

      expect(trial.isActiveAt(now), isTrue);
      expect(trial.remainingDays(now), greaterThan(0));

      final expiredTrial = TrialPeriod(
        startDate: now.subtract(const Duration(days: 10)),
        endDate: now.subtract(const Duration(days: 3)),
        durationDays: 7,
      );

      expect(expiredTrial.isActiveAt(now), isFalse);
      expect(expiredTrial.remainingDays(now), 0);
    });
  });
}
