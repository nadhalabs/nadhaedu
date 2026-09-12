import 'package:flutter/foundation.dart';
import 'package:learning_platform/core/analytics/analytics_service.dart';
import 'package:learning_platform/features/commerce/domain/coupon.dart';
import 'package:learning_platform/features/commerce/domain/payment_transaction.dart';
import 'package:learning_platform/features/commerce/domain/platform_billing_service.dart';
import 'package:learning_platform/features/commerce/domain/purchase.dart';
import 'package:learning_platform/features/commerce/domain/subscription.dart';

@immutable
sealed class CommerceAnalyticsEvent {
  const CommerceAnalyticsEvent();

  String get eventName;
  Map<String, Object?> get properties;
}

final class PaywallViewedEvent extends CommerceAnalyticsEvent {
  const PaywallViewedEvent({
    required this.placement,
    this.source,
    this.campaignId,
  });

  final String placement;
  final String? source;
  final String? campaignId;

  @override
  String get eventName => 'paywall_viewed';

  @override
  Map<String, Object?> get properties => {
    'placement': placement,
    if (source != null) 'source': source,
    if (campaignId != null) 'campaign_id': campaignId,
  };
}

final class CheckoutStartedEvent extends CommerceAnalyticsEvent {
  const CheckoutStartedEvent({
    required this.productId,
    required this.productType,
    required this.priceCents,
    required this.currencyCode,
  });

  final String productId;
  final CommerceProductType productType;
  final int priceCents;
  final String currencyCode;

  @override
  String get eventName => 'checkout_started';

  @override
  Map<String, Object?> get properties => {
    'product_id': productId,
    'product_type': productType.name,
    'price_cents': priceCents,
    'currency_code': currencyCode,
  };
}

final class CouponAppliedEvent extends CommerceAnalyticsEvent {
  const CouponAppliedEvent({
    required this.couponCode,
    required this.discountType,
    required this.discountValue,
    required this.isValid,
  });

  final String couponCode;
  final DiscountType discountType;
  final int discountValue;
  final bool isValid;

  @override
  String get eventName => 'coupon_applied';

  @override
  Map<String, Object?> get properties => {
    'coupon_code': couponCode,
    'discount_type': discountType.name,
    'discount_value': discountValue,
    'is_valid': isValid,
  };
}

final class PurchaseInitiatedEvent extends CommerceAnalyticsEvent {
  const PurchaseInitiatedEvent({
    required this.productId,
    required this.idempotencyKey,
    required this.provider,
  });

  final String productId;
  final String idempotencyKey;
  final CommerceProvider provider;

  @override
  String get eventName => 'purchase_initiated';

  @override
  Map<String, Object?> get properties => {
    'product_id': productId,
    'idempotency_key': idempotencyKey,
    'provider': provider.name,
  };
}

final class PurchaseCompletedEvent extends CommerceAnalyticsEvent {
  const PurchaseCompletedEvent({
    required this.productId,
    required this.orderId,
    required this.transactionId,
    required this.amountCents,
    required this.currencyCode,
  });

  final String productId;
  final String orderId;
  final String transactionId;
  final int amountCents;
  final String currencyCode;

  @override
  String get eventName => 'purchase_completed';

  @override
  Map<String, Object?> get properties => {
    'product_id': productId,
    'order_id': orderId,
    'transaction_id': transactionId,
    'amount_cents': amountCents,
    'currency_code': currencyCode,
  };
}

final class PurchaseFailedEvent extends CommerceAnalyticsEvent {
  const PurchaseFailedEvent({
    required this.productId,
    required this.errorCode,
    required this.errorMessage,
  });

  final String productId;
  final String errorCode;
  final String errorMessage;

  @override
  String get eventName => 'purchase_failed';

  @override
  Map<String, Object?> get properties => {
    'product_id': productId,
    'error_code': errorCode,
    'error_message': errorMessage,
  };
}

final class SubscriptionStartedEvent extends CommerceAnalyticsEvent {
  const SubscriptionStartedEvent({
    required this.planId,
    required this.tier,
    required this.billingInterval,
    required this.hasTrial,
    this.introductoryPrice,
  });

  final String planId;
  final SubscriptionTier tier;
  final BillingInterval billingInterval;
  final bool hasTrial;
  final int? introductoryPrice;

  @override
  String get eventName => 'subscription_started';

  @override
  Map<String, Object?> get properties => {
    'plan_id': planId,
    'tier': tier.name,
    'billing_interval': billingInterval.name,
    'has_trial': hasTrial,
    if (introductoryPrice != null) 'introductory_price': introductoryPrice,
  };
}

final class SubscriptionRenewedEvent extends CommerceAnalyticsEvent {
  const SubscriptionRenewedEvent({
    required this.planId,
    required this.subscriptionId,
  });

  final String planId;
  final String subscriptionId;

  @override
  String get eventName => 'subscription_renewed';

  @override
  Map<String, Object?> get properties => {
    'plan_id': planId,
    'subscription_id': subscriptionId,
  };
}

final class SubscriptionCancelledEvent extends CommerceAnalyticsEvent {
  const SubscriptionCancelledEvent({
    required this.planId,
    required this.subscriptionId,
    this.reason,
  });

  final String planId;
  final String subscriptionId;
  final String? reason;

  @override
  String get eventName => 'subscription_cancelled';

  @override
  Map<String, Object?> get properties => {
    'plan_id': planId,
    'subscription_id': subscriptionId,
    if (reason != null) 'reason': reason,
  };
}

final class SubscriptionPlanChangedEvent extends CommerceAnalyticsEvent {
  const SubscriptionPlanChangedEvent({
    required this.fromPlanId,
    required this.toPlanId,
    this.prorationMode,
  });

  final String fromPlanId;
  final String toPlanId;
  final ProrationMode? prorationMode;

  @override
  String get eventName => 'subscription_plan_changed';

  @override
  Map<String, Object?> get properties => {
    'from_plan_id': fromPlanId,
    'to_plan_id': toPlanId,
    if (prorationMode != null) 'proration_mode': prorationMode!.name,
  };
}

final class PurchasesRestoredEvent extends CommerceAnalyticsEvent {
  const PurchasesRestoredEvent({
    required this.restoredCount,
    required this.success,
  });

  final int restoredCount;
  final bool success;

  @override
  String get eventName => 'purchases_restored';

  @override
  Map<String, Object?> get properties => {
    'restored_count': restoredCount,
    'success': success,
  };
}

final class CommerceAnalyticsTracker {
  const CommerceAnalyticsTracker(this._analyticsService);
  final AnalyticsService _analyticsService;

  Future<void> logEvent(CommerceAnalyticsEvent event) {
    return _analyticsService.track(
      event.eventName,
      properties: event.properties,
    );
  }
}
