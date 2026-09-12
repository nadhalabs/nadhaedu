import 'package:flutter/foundation.dart';
import 'package:learning_platform/features/commerce/domain/commerce_product.dart';
import 'package:learning_platform/features/commerce/domain/coupon.dart';
import 'package:learning_platform/features/commerce/domain/payment_transaction.dart';
import 'package:learning_platform/features/commerce/domain/platform_billing_service.dart';
import 'package:learning_platform/features/commerce/domain/purchase.dart';
import 'package:learning_platform/features/commerce/domain/subscription.dart';
import 'package:learning_platform/features/entitlements/domain/entitlement.dart';

@immutable
final class CommerceVerificationResult {
  const CommerceVerificationResult({
    required this.transaction,
    required this.isSuccess,
    this.purchase,
    this.subscription,
    this.grantedEntitlements = const [],
    this.errorMessage,
  });

  final PaymentTransaction transaction;
  final bool isSuccess;
  final Purchase? purchase;
  final Subscription? subscription;
  final List<Entitlement> grantedEntitlements;
  final String? errorMessage;
}

@immutable
final class RestorePurchasesResult {
  const RestorePurchasesResult({
    required this.restoredCount,
    required this.isSuccess,
    this.restoredPurchases = const [],
    this.activeSubscription,
    this.restoredEntitlements = const [],
    this.message,
  });

  final int restoredCount;
  final bool isSuccess;
  final List<Purchase> restoredPurchases;
  final Subscription? activeSubscription;
  final List<Entitlement> restoredEntitlements;
  final String? message;
}

abstract interface class CommerceRepository {
  Future<List<SubscriptionPlan>> getSubscriptionPlans({
    bool forceRefresh = false,
  });

  Future<List<CourseProduct>> getCourseProducts({bool forceRefresh = false});

  Future<List<BundleProduct>> getBundleProducts({bool forceRefresh = false});

  Future<SubscriptionPlan?> getSubscriptionPlanById(String planId);

  Future<CourseProduct?> getCourseProductById(String productId);

  Future<Coupon?> validateCoupon(String code, {String? productId});

  Future<CommerceVerificationResult> verifyAndProcessTransaction(
    PaymentTransaction transaction, {
    String? idempotencyKey,
    String? couponCode,
    String? learnerId,
  });

  Future<RestorePurchasesResult> restoreAndReconcilePurchases(
    List<PaymentTransaction> transactions, {
    required String learnerId,
  });

  Future<Subscription?> getLearnerActiveSubscription(String learnerId);

  Future<List<Purchase>> getLearnerPurchases(String learnerId);

  Future<Subscription> cancelSubscription(
    String subscriptionId, {
    String? reason,
  });

  Future<Subscription> changeSubscriptionPlan({
    required String currentSubscriptionId,
    required String newPlanId,
    ProrationMode? prorationMode,
  });
}
