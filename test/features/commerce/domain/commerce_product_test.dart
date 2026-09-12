import 'package:flutter_test/flutter_test.dart';
import 'package:learning_platform/features/commerce/domain/commerce_product.dart';
import 'package:learning_platform/features/commerce/domain/subscription.dart';

void main() {
  group('CommerceProduct Domain Tests', () {
    test('SubscriptionPlan properties and savings evaluation', () {
      const plan = SubscriptionPlan(
        id: 'plan_1',
        tier: SubscriptionTier.pro,
        billingInterval: BillingInterval.annual,
        name: 'Pro Annual',
        description: 'Annual plan with savings',
        priceCents: 11999,
        formattedPrice: '\$119.99',
        currencyCode: 'USD',
        trialDays: 14,
        savingsPercent: 33,
        benefits: ['Feature 1', 'Feature 2'],
      );

      expect(plan.hasTrial, isTrue);
      expect(plan.trialDays, 14);
      expect(plan.hasSavings, isTrue);
      expect(plan.savingsPercent, 33);
      expect(plan.benefits.length, 2);
    });

    test('CourseProduct discount detection', () {
      const discountedCourse = CourseProduct(
        id: 'prod_1',
        courseId: 'course_1',
        title: 'Flutter Architecture',
        description: 'Advanced course',
        priceCents: 4900,
        formattedPrice: '\$49.00',
        currencyCode: 'USD',
        originalPriceCents: 6000,
        discountPercent: 18,
      );

      expect(discountedCourse.hasDiscount, isTrue);
      expect(discountedCourse.originalPriceCents, 6000);
      expect(discountedCourse.discountPercent, 18);
    });

    test('BundleProduct contains multiple courses and calculated discount', () {
      const bundle = BundleProduct(
        id: 'bundle_1',
        bundleId: 'bundle_mobile',
        title: 'Mobile Bundle',
        description: 'Two courses',
        courseIds: ['course_1', 'course_2'],
        priceCents: 7900,
        formattedPrice: '\$79.00',
        currencyCode: 'USD',
        originalPriceCents: 10000,
        discountPercent: 21,
      );

      expect(bundle.courseCount, 2);
      expect(bundle.hasDiscount, isTrue);
      expect(bundle.courseIds, contains('course_1'));
      expect(bundle.courseIds, contains('course_2'));
    });
  });
}
