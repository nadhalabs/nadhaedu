import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_platform/core/errors/app_failure.dart';
import 'package:learning_platform/features/commerce/application/commerce_state.dart';
import 'package:learning_platform/features/commerce/domain/commerce_analytics.dart';
import 'package:learning_platform/features/commerce/domain/commerce_product.dart';
import 'package:learning_platform/features/commerce/domain/commerce_repository.dart';
import 'package:learning_platform/features/commerce/domain/coupon.dart';
import 'package:learning_platform/features/commerce/domain/payment_transaction.dart';
import 'package:learning_platform/features/commerce/domain/platform_billing_service.dart';
import 'package:learning_platform/features/commerce/domain/purchase.dart';
import 'package:learning_platform/features/entitlements/application/entitlement_controller.dart';

final class CommerceController extends StateNotifier<CommerceState> {
  CommerceController({
    required CommerceRepository repository,
    required PlatformBillingService billingService,
    required CommerceAnalyticsTracker analytics,
    EntitlementController? entitlementController,
    required String learnerId,
  }) : _repository = repository,
       _billingService = billingService,
       _analytics = analytics,
       _entitlementController = entitlementController,
       _learnerId = learnerId,
       super(const CommerceState.initial());

  final CommerceRepository _repository;
  final PlatformBillingService _billingService;
  final CommerceAnalyticsTracker _analytics;
  final EntitlementController? _entitlementController;
  final String _learnerId;

  String _generateIdempotencyKey() {
    final rand = math.Random().nextInt(999999).toString().padLeft(6, '0');
    return 'idemp_${DateTime.now().microsecondsSinceEpoch}_$rand';
  }

  Future<void> initialize() async {
    state = state.copyWith(isLoading: true, failure: () => null);
    try {
      await _billingService.initialize();
      final plans = await _repository.getSubscriptionPlans();
      final courseProducts = await _repository.getCourseProducts();
      final bundleProducts = await _repository.getBundleProducts();
      final activeSub = await _repository.getLearnerActiveSubscription(
        _learnerId,
      );
      final purchases = await _repository.getLearnerPurchases(_learnerId);

      state = state.copyWith(
        plans: plans,
        courseProducts: courseProducts,
        bundleProducts: bundleProducts,
        activeSubscription: () => activeSub,
        purchases: purchases,
        isLoading: false,
        failure: () => null,
      );
    } on AppFailure catch (failure) {
      state = state.copyWith(isLoading: false, failure: () => failure);
    } on Object catch (e) {
      state = state.copyWith(
        isLoading: false,
        failure: () => UnexpectedFailure(
          code: 'commerce_init_failed',
          message: 'Failed to initialize commerce catalog.',
          cause: e,
        ),
      );
    }
  }

  Future<bool> applyCoupon(String code, {String? productId}) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return false;

    state = state.copyWith(isLoading: true, failure: () => null);
    try {
      final coupon = await _repository.validateCoupon(
        trimmed,
        productId: productId,
      );
      if (coupon == null) {
        unawaited(
          _analytics.logEvent(
            CouponAppliedEvent(
              couponCode: trimmed,
              discountType: DiscountType.percentage,
              discountValue: 0,
              isValid: false,
            ),
          ),
        );
        state = state.copyWith(
          isLoading: false,
          failure: () => const ValidationFailure(
            code: 'invalid_coupon',
            message: 'This promo code is invalid or has expired.',
          ),
        );
        return false;
      }

      unawaited(
        _analytics.logEvent(
          CouponAppliedEvent(
            couponCode: coupon.code,
            discountType: coupon.discountType,
            discountValue: coupon.discountValue,
            isValid: true,
          ),
        ),
      );

      state = state.copyWith(
        isLoading: false,
        appliedCoupon: () => coupon,
        successMessage: () => 'Promo code applied successfully!',
        failure: () => null,
      );
      return true;
    } on AppFailure catch (failure) {
      state = state.copyWith(isLoading: false, failure: () => failure);
      return false;
    }
  }

  void removeCoupon() {
    state = state.copyWith(
      appliedCoupon: () => null,
      successMessage: () => null,
    );
  }

  Future<bool> purchaseSubscriptionPlan(SubscriptionPlan plan) async {
    // 1. Concurrency guard: prevent duplicate purchase submissions
    if (state.isBusy) return false;

    final idempotencyKey = _generateIdempotencyKey();
    final storeProductId = plan.storeProductId ?? plan.id;

    state = state.copyWith(
      isProcessingPurchase: true,
      inProgressProductId: () => plan.id,
      failure: () => null,
      successMessage: () => null,
    );

    unawaited(
      _analytics.logEvent(
        CheckoutStartedEvent(
          productId: plan.id,
          productType: CommerceProductType.course,
          priceCents: plan.priceCents,
          currencyCode: plan.currencyCode,
        ),
      ),
    );

    unawaited(
      _analytics.logEvent(
        PurchaseInitiatedEvent(
          productId: plan.id,
          idempotencyKey: idempotencyKey,
          provider: CommerceProvider.mock,
        ),
      ),
    );

    try {
      // 2. Request native platform billing transaction
      final billingResult = await _billingService.purchaseProduct(
        storeProductId,
      );

      final transaction = switch (billingResult) {
        PlatformPurchaseSuccess(transaction: final tx) => tx,
        PlatformPurchaseUserCancelled() => null,
        PlatformPurchasePending() => null,
        PlatformPurchaseError(errorCode: final code, errorMessage: final msg) =>
          throw ValidationFailure(code: code, message: msg),
      };

      if (transaction == null) {
        // User cancelled or transaction is pending
        state = state.copyWith(
          isProcessingPurchase: false,
          inProgressProductId: () => null,
        );
        return false;
      }

      // 3. Server verification flow determines authoritative commerce state
      final verificationResult = await _repository.verifyAndProcessTransaction(
        transaction,
        idempotencyKey: idempotencyKey,
        couponCode: state.appliedCoupon?.code,
        learnerId: _learnerId,
      );

      if (!verificationResult.isSuccess) {
        unawaited(
          _analytics.logEvent(
            PurchaseFailedEvent(
              productId: plan.id,
              errorCode: 'verification_failed',
              errorMessage:
                  verificationResult.errorMessage ?? 'Verification failed.',
            ),
          ),
        );
        state = state.copyWith(
          isProcessingPurchase: false,
          inProgressProductId: () => null,
          failure: () => ValidationFailure(
            code: 'verification_failed',
            message:
                verificationResult.errorMessage ??
                'Payment verification failed on the server.',
          ),
        );
        return false;
      }

      // 4. Server authoritative entitlement grant: update EntitlementController
      if (_entitlementController != null) {
        await _entitlementController.refresh();
      }

      unawaited(
        _analytics.logEvent(
          PurchaseCompletedEvent(
            productId: plan.id,
            orderId: verificationResult.subscription?.id ?? transaction.id,
            transactionId: transaction.id,
            amountCents: plan.priceCents,
            currencyCode: plan.currencyCode,
          ),
        ),
      );

      unawaited(
        _analytics.logEvent(
          SubscriptionStartedEvent(
            planId: plan.id,
            tier: plan.tier,
            billingInterval: plan.billingInterval,
            hasTrial: plan.hasTrial,
          ),
        ),
      );

      state = state.copyWith(
        isProcessingPurchase: false,
        inProgressProductId: () => null,
        activeSubscription: () => verificationResult.subscription,
        appliedCoupon: () => null,
        successMessage: () => 'Subscription activated successfully!',
        lastTransaction: () => transaction,
        failure: () => null,
      );
      return true;
    } on AppFailure catch (failure) {
      unawaited(
        _analytics.logEvent(
          PurchaseFailedEvent(
            productId: plan.id,
            errorCode: failure.code,
            errorMessage: failure.message,
          ),
        ),
      );
      state = state.copyWith(
        isProcessingPurchase: false,
        inProgressProductId: () => null,
        failure: () => failure,
      );
      return false;
    } on Object catch (e) {
      state = state.copyWith(
        isProcessingPurchase: false,
        inProgressProductId: () => null,
        failure: () => UnexpectedFailure(
          code: 'purchase_error',
          message: 'An unexpected error occurred during purchase.',
          cause: e,
        ),
      );
      return false;
    }
  }

  Future<bool> purchaseCourseProduct(CourseProduct product) async {
    if (state.isBusy) return false;

    final idempotencyKey = _generateIdempotencyKey();
    final storeProductId = product.storeProductId ?? product.id;

    state = state.copyWith(
      isProcessingPurchase: true,
      inProgressProductId: () => product.id,
      failure: () => null,
      successMessage: () => null,
    );

    unawaited(
      _analytics.logEvent(
        CheckoutStartedEvent(
          productId: product.id,
          productType: CommerceProductType.course,
          priceCents: product.priceCents,
          currencyCode: product.currencyCode,
        ),
      ),
    );

    unawaited(
      _analytics.logEvent(
        PurchaseInitiatedEvent(
          productId: product.id,
          idempotencyKey: idempotencyKey,
          provider: CommerceProvider.mock,
        ),
      ),
    );

    try {
      final billingResult = await _billingService.purchaseProduct(
        storeProductId,
      );

      final transaction = switch (billingResult) {
        PlatformPurchaseSuccess(transaction: final tx) => tx,
        PlatformPurchaseUserCancelled() => null,
        PlatformPurchasePending() => null,
        PlatformPurchaseError(errorCode: final code, errorMessage: final msg) =>
          throw ValidationFailure(code: code, message: msg),
      };

      if (transaction == null) {
        state = state.copyWith(
          isProcessingPurchase: false,
          inProgressProductId: () => null,
        );
        return false;
      }

      final verificationResult = await _repository.verifyAndProcessTransaction(
        transaction,
        idempotencyKey: idempotencyKey,
        couponCode: state.appliedCoupon?.code,
        learnerId: _learnerId,
      );

      if (!verificationResult.isSuccess) {
        state = state.copyWith(
          isProcessingPurchase: false,
          inProgressProductId: () => null,
          failure: () => ValidationFailure(
            code: 'verification_failed',
            message:
                verificationResult.errorMessage ??
                'Payment verification failed on the server.',
          ),
        );
        return false;
      }

      if (_entitlementController != null) {
        await _entitlementController.refresh();
      }

      unawaited(
        _analytics.logEvent(
          PurchaseCompletedEvent(
            productId: product.id,
            orderId: verificationResult.purchase?.orderId ?? transaction.id,
            transactionId: transaction.id,
            amountCents: product.priceCents,
            currencyCode: product.currencyCode,
          ),
        ),
      );

      final updatedPurchases = List<Purchase>.from(state.purchases);
      if (verificationResult.purchase != null) {
        updatedPurchases.add(verificationResult.purchase!);
      }

      state = state.copyWith(
        isProcessingPurchase: false,
        inProgressProductId: () => null,
        purchases: updatedPurchases,
        appliedCoupon: () => null,
        successMessage: () => 'Course unlocked successfully!',
        lastTransaction: () => transaction,
        failure: () => null,
      );
      return true;
    } on AppFailure catch (failure) {
      state = state.copyWith(
        isProcessingPurchase: false,
        inProgressProductId: () => null,
        failure: () => failure,
      );
      return false;
    }
  }

  Future<bool> restorePurchases() async {
    if (state.isBusy) return false;

    state = state.copyWith(
      isRestoringPurchases: true,
      failure: () => null,
      successMessage: () => null,
    );

    try {
      final transactions = await _billingService.restorePurchases();
      final result = await _repository.restoreAndReconcilePurchases(
        transactions,
        learnerId: _learnerId,
      );

      if (_entitlementController != null) {
        await _entitlementController.refresh();
      }

      unawaited(
        _analytics.logEvent(
          PurchasesRestoredEvent(
            restoredCount: result.restoredCount,
            success: result.isSuccess,
          ),
        ),
      );

      state = state.copyWith(
        isRestoringPurchases: false,
        activeSubscription: () =>
            result.activeSubscription ?? state.activeSubscription,
        purchases: result.restoredPurchases.isNotEmpty
            ? result.restoredPurchases
            : state.purchases,
        successMessage: () =>
            result.message ?? 'Purchases restored successfully.',
        failure: () => null,
      );
      return true;
    } on AppFailure catch (failure) {
      state = state.copyWith(
        isRestoringPurchases: false,
        failure: () => failure,
      );
      return false;
    }
  }

  Future<bool> changeSubscriptionPlan({
    required String newPlanId,
    ProrationMode prorationMode = ProrationMode.immediateWithTimeProration,
  }) async {
    final currentSub = state.activeSubscription;
    if (currentSub == null || state.isBusy) return false;

    state = state.copyWith(isProcessingPurchase: true, failure: () => null);

    try {
      final updatedSub = await _repository.changeSubscriptionPlan(
        currentSubscriptionId: currentSub.id,
        newPlanId: newPlanId,
        prorationMode: prorationMode,
      );

      if (_entitlementController != null) {
        await _entitlementController.refresh();
      }

      unawaited(
        _analytics.logEvent(
          SubscriptionPlanChangedEvent(
            fromPlanId: currentSub.planId,
            toPlanId: newPlanId,
            prorationMode: prorationMode,
          ),
        ),
      );

      state = state.copyWith(
        isProcessingPurchase: false,
        activeSubscription: () => updatedSub,
        successMessage: () => 'Subscription plan updated.',
        failure: () => null,
      );
      return true;
    } on AppFailure catch (failure) {
      state = state.copyWith(
        isProcessingPurchase: false,
        failure: () => failure,
      );
      return false;
    }
  }

  Future<bool> cancelSubscription({String? reason}) async {
    final currentSub = state.activeSubscription;
    if (currentSub == null || state.isBusy) return false;

    state = state.copyWith(isLoading: true, failure: () => null);

    try {
      final updatedSub = await _repository.cancelSubscription(
        currentSub.id,
        reason: reason,
      );

      unawaited(
        _analytics.logEvent(
          SubscriptionCancelledEvent(
            planId: currentSub.planId,
            subscriptionId: currentSub.id,
            reason: reason,
          ),
        ),
      );

      state = state.copyWith(
        isLoading: false,
        activeSubscription: () => updatedSub,
        successMessage: () =>
            'Subscription cancelled. Access remains active until the end of your billing cycle.',
        failure: () => null,
      );
      return true;
    } on AppFailure catch (failure) {
      state = state.copyWith(isLoading: false, failure: () => failure);
      return false;
    }
  }

  Future<void> openPlatformSubscriptionManagement() {
    return _billingService.presentManageSubscriptions();
  }

  Future<void> openPlatformCodeRedemption() {
    return _billingService.presentCodeRedemptionSheet();
  }

  void clearMessages() {
    state = state.copyWith(failure: () => null, successMessage: () => null);
  }
}
