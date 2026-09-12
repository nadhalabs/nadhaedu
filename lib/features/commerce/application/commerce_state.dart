import 'package:flutter/foundation.dart';
import 'package:learning_platform/core/errors/app_failure.dart';
import 'package:learning_platform/features/commerce/domain/commerce_product.dart';
import 'package:learning_platform/features/commerce/domain/coupon.dart';
import 'package:learning_platform/features/commerce/domain/payment_transaction.dart';
import 'package:learning_platform/features/commerce/domain/purchase.dart';
import 'package:learning_platform/features/commerce/domain/subscription.dart';

@immutable
final class CommerceState {
  const CommerceState({
    this.plans = const [],
    this.courseProducts = const [],
    this.bundleProducts = const [],
    this.activeSubscription,
    this.purchases = const [],
    this.appliedCoupon,
    this.isLoading = false,
    this.isProcessingPurchase = false,
    this.isRestoringPurchases = false,
    this.inProgressProductId,
    this.failure,
    this.successMessage,
    this.lastTransaction,
  });

  const CommerceState.initial() : this();

  final List<SubscriptionPlan> plans;
  final List<CourseProduct> courseProducts;
  final List<BundleProduct> bundleProducts;
  final Subscription? activeSubscription;
  final List<Purchase> purchases;
  final Coupon? appliedCoupon;
  final bool isLoading;
  final bool isProcessingPurchase;
  final bool isRestoringPurchases;
  final String? inProgressProductId;
  final AppFailure? failure;
  final String? successMessage;
  final PaymentTransaction? lastTransaction;

  bool get hasActiveSubscription => activeSubscription?.isUsable ?? false;
  bool get isBusy => isLoading || isProcessingPurchase || isRestoringPurchases;

  bool hasPurchasedCourse(String courseId) {
    return purchases.any((p) => p.isActive && p.productId == courseId);
  }

  CommerceState copyWith({
    List<SubscriptionPlan>? plans,
    List<CourseProduct>? courseProducts,
    List<BundleProduct>? bundleProducts,
    Subscription? Function()? activeSubscription,
    List<Purchase>? purchases,
    Coupon? Function()? appliedCoupon,
    bool? isLoading,
    bool? isProcessingPurchase,
    bool? isRestoringPurchases,
    String? Function()? inProgressProductId,
    AppFailure? Function()? failure,
    String? Function()? successMessage,
    PaymentTransaction? Function()? lastTransaction,
  }) {
    return CommerceState(
      plans: plans ?? this.plans,
      courseProducts: courseProducts ?? this.courseProducts,
      bundleProducts: bundleProducts ?? this.bundleProducts,
      activeSubscription: activeSubscription != null
          ? activeSubscription()
          : this.activeSubscription,
      purchases: purchases ?? this.purchases,
      appliedCoupon: appliedCoupon != null
          ? appliedCoupon()
          : this.appliedCoupon,
      isLoading: isLoading ?? this.isLoading,
      isProcessingPurchase: isProcessingPurchase ?? this.isProcessingPurchase,
      isRestoringPurchases: isRestoringPurchases ?? this.isRestoringPurchases,
      inProgressProductId: inProgressProductId != null
          ? inProgressProductId()
          : this.inProgressProductId,
      failure: failure != null ? failure() : this.failure,
      successMessage: successMessage != null
          ? successMessage()
          : this.successMessage,
      lastTransaction: lastTransaction != null
          ? lastTransaction()
          : this.lastTransaction,
    );
  }
}
