import 'package:flutter_test/flutter_test.dart';
import 'package:learning_platform/features/commerce/domain/coupon.dart';

void main() {
  group('Coupon Domain Tests', () {
    test('calculates percentage discounts accurately', () {
      final now = DateTime.now().toUtc();
      final coupon = Coupon(
        code: 'SAVE20',
        discountType: DiscountType.percentage,
        discountValue: 20,
        validUntil: now.add(const Duration(days: 10)),
      );

      expect(coupon.isUsableAt(now), isTrue);
      expect(coupon.calculateDiscountedPrice(10000), 8000);
      expect(coupon.calculateSavings(10000), 2000);
    });

    test('calculates fixed amount discounts accurately', () {
      final now = DateTime.now().toUtc();
      final coupon = Coupon(
        code: 'TENOFF',
        discountType: DiscountType.fixedAmount,
        discountValue: 1000, // $10.00 in cents
        validUntil: now.add(const Duration(days: 10)),
      );

      expect(coupon.calculateDiscountedPrice(5000), 4000);
      expect(coupon.calculateSavings(5000), 1000);

      // Floor at 0 if discount exceeds price
      expect(coupon.calculateDiscountedPrice(500), 0);
    });

    test('verifies product applicability and date validity', () {
      final now = DateTime.now().toUtc();
      final coupon = Coupon(
        code: 'COURSEONLY',
        discountType: DiscountType.percentage,
        discountValue: 15,
        validUntil: now.subtract(const Duration(days: 1)),
        applicableProductIds: {'prod_course_1'},
      );

      // Expired
      expect(coupon.isUsableAt(now), isFalse);

      final validCoupon = Coupon(
        code: 'COURSEONLY_VALID',
        discountType: DiscountType.percentage,
        discountValue: 15,
        validUntil: now.add(const Duration(days: 5)),
        applicableProductIds: {'prod_course_1'},
      );

      expect(validCoupon.isUsableAt(now, productId: 'prod_course_1'), isTrue);
      expect(validCoupon.isUsableAt(now, productId: 'prod_course_2'), isFalse);
    });
  });
}
