import 'package:learning_platform/features/commerce/data/commerce_data_source.dart';
import 'package:learning_platform/features/commerce/domain/commerce_product.dart';
import 'package:learning_platform/features/commerce/domain/commerce_repository.dart';
import 'package:learning_platform/features/commerce/domain/coupon.dart';
import 'package:learning_platform/features/commerce/domain/payment_transaction.dart';
import 'package:learning_platform/features/commerce/domain/platform_billing_service.dart';
import 'package:learning_platform/features/commerce/domain/purchase.dart';
import 'package:learning_platform/features/commerce/domain/subscription.dart';

final class UnconfiguredCommerceDataSource implements CommerceDataSource {
  const UnconfiguredCommerceDataSource();

  @override
  Future<List<SubscriptionPlan>> fetchSubscriptionPlans() async {
    throw const CommerceDataException(
      CommerceErrorKind.unconfigured,
      'Commerce server is unconfigured.',
    );
  }

  @override
  Future<List<CourseProduct>> fetchCourseProducts() async {
    throw const CommerceDataException(
      CommerceErrorKind.unconfigured,
      'Commerce server is unconfigured.',
    );
  }

  @override
  Future<List<BundleProduct>> fetchBundleProducts() async {
    throw const CommerceDataException(
      CommerceErrorKind.unconfigured,
      'Commerce server is unconfigured.',
    );
  }

  @override
  Future<Coupon?> validateCoupon(String code, {String? productId}) async {
    throw const CommerceDataException(
      CommerceErrorKind.unconfigured,
      'Commerce server is unconfigured.',
    );
  }

  @override
  Future<CommerceVerificationResult> verifyTransaction({
    required PaymentTransaction transaction,
    required String learnerId,
    String? idempotencyKey,
    String? couponCode,
  }) async {
    throw const CommerceDataException(
      CommerceErrorKind.unconfigured,
      'Commerce server is unconfigured.',
    );
  }

  @override
  Future<RestorePurchasesResult> restorePurchases({
    required List<PaymentTransaction> transactions,
    required String learnerId,
  }) async {
    throw const CommerceDataException(
      CommerceErrorKind.unconfigured,
      'Commerce server is unconfigured.',
    );
  }

  @override
  Future<Subscription?> fetchLearnerActiveSubscription(String learnerId) async {
    throw const CommerceDataException(
      CommerceErrorKind.unconfigured,
      'Commerce server is unconfigured.',
    );
  }

  @override
  Future<List<Purchase>> fetchLearnerPurchases(String learnerId) async {
    throw const CommerceDataException(
      CommerceErrorKind.unconfigured,
      'Commerce server is unconfigured.',
    );
  }

  @override
  Future<Subscription> cancelSubscription({
    required String subscriptionId,
    required String learnerId,
    String? reason,
  }) async {
    throw const CommerceDataException(
      CommerceErrorKind.unconfigured,
      'Commerce server is unconfigured.',
    );
  }

  @override
  Future<Subscription> changeSubscriptionPlan({
    required String currentSubscriptionId,
    required String newPlanId,
    required String learnerId,
    ProrationMode? prorationMode,
  }) async {
    throw const CommerceDataException(
      CommerceErrorKind.unconfigured,
      'Commerce server is unconfigured.',
    );
  }
}
