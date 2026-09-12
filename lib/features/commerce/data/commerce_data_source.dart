import 'package:learning_platform/features/commerce/domain/commerce_product.dart';
import 'package:learning_platform/features/commerce/domain/commerce_repository.dart';
import 'package:learning_platform/features/commerce/domain/coupon.dart';
import 'package:learning_platform/features/commerce/domain/payment_transaction.dart';
import 'package:learning_platform/features/commerce/domain/platform_billing_service.dart';
import 'package:learning_platform/features/commerce/domain/purchase.dart';
import 'package:learning_platform/features/commerce/domain/subscription.dart';

enum CommerceErrorKind {
  unauthenticated,
  forbidden,
  notFound,
  invalidTransaction,
  duplicateTransaction,
  invalidCoupon,
  paymentFailed,
  network,
  unconfigured,
  unknown,
}

final class CommerceDataException implements Exception {
  const CommerceDataException(this.kind, [this.message = '']);

  final CommerceErrorKind kind;
  final String message;

  @override
  String toString() => 'CommerceDataException($kind): $message';
}

abstract interface class CommerceDataSource {
  Future<List<SubscriptionPlan>> fetchSubscriptionPlans();

  Future<List<CourseProduct>> fetchCourseProducts();

  Future<List<BundleProduct>> fetchBundleProducts();

  Future<Coupon?> validateCoupon(String code, {String? productId});

  Future<CommerceVerificationResult> verifyTransaction({
    required PaymentTransaction transaction,
    required String learnerId,
    String? idempotencyKey,
    String? couponCode,
  });

  Future<RestorePurchasesResult> restorePurchases({
    required List<PaymentTransaction> transactions,
    required String learnerId,
  });

  Future<Subscription?> fetchLearnerActiveSubscription(String learnerId);

  Future<List<Purchase>> fetchLearnerPurchases(String learnerId);

  Future<Subscription> cancelSubscription({
    required String subscriptionId,
    required String learnerId,
    String? reason,
  });

  Future<Subscription> changeSubscriptionPlan({
    required String currentSubscriptionId,
    required String newPlanId,
    required String learnerId,
    ProrationMode? prorationMode,
  });
}
