sealed class EntitlementSource {
  const EntitlementSource({required this.sourceId});

  final String sourceId;
  String get name;
}

final class SubscriptionEntitlementSource extends EntitlementSource {
  const SubscriptionEntitlementSource({
    required super.sourceId,
    required this.planId,
    required this.tier,
    this.renewsAt,
    this.autoRenewing = true,
  });

  final String planId;
  final String tier;
  final DateTime? renewsAt;
  final bool autoRenewing;

  @override
  String get name => 'Subscription ($tier)';
}

final class IndividualPurchaseEntitlementSource extends EntitlementSource {
  const IndividualPurchaseEntitlementSource({
    required super.sourceId,
    required this.orderId,
    required this.purchasedAt,
    this.amountCents,
    this.currencyCode,
  });

  final String orderId;
  final DateTime purchasedAt;
  final int? amountCents;
  final String? currencyCode;

  @override
  String get name => 'Individual Purchase';
}

final class BundleEntitlementSource extends EntitlementSource {
  const BundleEntitlementSource({
    required super.sourceId,
    required this.bundleId,
    required this.bundleTitle,
  });

  final String bundleId;
  final String bundleTitle;

  @override
  String get name => 'Bundle ($bundleTitle)';
}

final class PromotionEntitlementSource extends EntitlementSource {
  const PromotionEntitlementSource({
    required super.sourceId,
    required this.campaignId,
    this.promoCode,
  });

  final String campaignId;
  final String? promoCode;

  @override
  String get name => 'Promotion';
}

final class TrialEntitlementSource extends EntitlementSource {
  const TrialEntitlementSource({
    required super.sourceId,
    required this.trialDays,
    this.planId,
    this.convertedToSubscription = false,
  });

  final int trialDays;
  final String? planId;
  final bool convertedToSubscription;

  @override
  String get name => 'Trial';
}

final class CouponEntitlementSource extends EntitlementSource {
  const CouponEntitlementSource({
    required super.sourceId,
    required this.code,
    this.campaignId,
  });

  final String code;
  final String? campaignId;

  @override
  String get name => 'Coupon ($code)';
}

final class ScholarshipEntitlementSource extends EntitlementSource {
  const ScholarshipEntitlementSource({
    required super.sourceId,
    required this.scholarshipId,
    required this.organizationName,
    this.grantor,
  });

  final String scholarshipId;
  final String organizationName;
  final String? grantor;

  @override
  String get name => 'Scholarship ($organizationName)';
}

final class AdministrativeGrantEntitlementSource extends EntitlementSource {
  const AdministrativeGrantEntitlementSource({
    required super.sourceId,
    required this.grantedBy,
    required this.reason,
    this.ticketId,
  });

  final String grantedBy;
  final String reason;
  final String? ticketId;

  @override
  String get name => 'Administrative Grant';
}

final class TimeLimitedAccessEntitlementSource extends EntitlementSource {
  const TimeLimitedAccessEntitlementSource({
    required super.sourceId,
    required this.windowId,
    this.grantReason,
  });

  final String windowId;
  final String? grantReason;

  @override
  String get name => 'Time-limited Access';
}
