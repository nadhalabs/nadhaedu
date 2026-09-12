import 'package:flutter/foundation.dart';

enum SubscriptionTier {
  standard,
  pro,
  student,
  family,
  institution;

  String get displayName => switch (this) {
    SubscriptionTier.standard => 'Standard',
    SubscriptionTier.pro => 'Pro',
    SubscriptionTier.student => 'Student',
    SubscriptionTier.family => 'Family',
    SubscriptionTier.institution => 'Institution',
  };
}

enum BillingInterval {
  monthly,
  quarterly,
  annual;

  String get displayName => switch (this) {
    BillingInterval.monthly => 'Monthly',
    BillingInterval.quarterly => 'Quarterly',
    BillingInterval.annual => 'Annual',
  };

  String get billingPeriodLabel => switch (this) {
    BillingInterval.monthly => '/ month',
    BillingInterval.quarterly => '/ 3 months',
    BillingInterval.annual => '/ year',
  };
}

enum SubscriptionStatus {
  active,
  trialing,
  inGracePeriod,
  billingRetry,
  cancelled,
  paused,
  expired,
  revoked;

  /// Returns true if the subscription currently grants full access rights.
  bool get isUsable => switch (this) {
    SubscriptionStatus.active ||
    SubscriptionStatus.trialing ||
    SubscriptionStatus.inGracePeriod => true,
    SubscriptionStatus.billingRetry ||
    SubscriptionStatus.cancelled ||
    SubscriptionStatus.paused ||
    SubscriptionStatus.expired ||
    SubscriptionStatus.revoked => false,
  };

  bool get requiresAttention => switch (this) {
    SubscriptionStatus.inGracePeriod || SubscriptionStatus.billingRetry => true,
    _ => false,
  };

  String get displayName => switch (this) {
    SubscriptionStatus.active => 'Active',
    SubscriptionStatus.trialing => 'Free Trial',
    SubscriptionStatus.inGracePeriod => 'Grace Period',
    SubscriptionStatus.billingRetry => 'Payment Pending',
    SubscriptionStatus.cancelled => 'Cancelled',
    SubscriptionStatus.paused => 'Paused',
    SubscriptionStatus.expired => 'Expired',
    SubscriptionStatus.revoked => 'Revoked',
  };
}

@immutable
final class TrialPeriod {
  const TrialPeriod({
    required this.startDate,
    required this.endDate,
    required this.durationDays,
  });

  final DateTime startDate;
  final DateTime endDate;
  final int durationDays;

  bool isActiveAt(DateTime now) {
    return now.isAfter(startDate) && now.isBefore(endDate);
  }

  int remainingDays(DateTime now) {
    if (now.isAfter(endDate)) return 0;
    return endDate.difference(now).inDays + 1;
  }
}

@immutable
final class Subscription {
  const Subscription({
    required this.id,
    required this.learnerId,
    required this.planId,
    required this.tier,
    required this.billingInterval,
    required this.status,
    required this.currentPeriodStart,
    required this.currentPeriodEnd,
    this.cancelAtPeriodEnd = false,
    this.renewsAt,
    this.trialPeriod,
    this.introductoryPriceCents,
    this.cancellationReason,
    this.originalTransactionId,
    this.latestTransactionId,
    this.metadata = const {},
  });

  final String id;
  final String learnerId;
  final String planId;
  final SubscriptionTier tier;
  final BillingInterval billingInterval;
  final SubscriptionStatus status;
  final DateTime currentPeriodStart;
  final DateTime currentPeriodEnd;
  final bool cancelAtPeriodEnd;
  final DateTime? renewsAt;
  final TrialPeriod? trialPeriod;
  final int? introductoryPriceCents;
  final String? cancellationReason;
  final String? originalTransactionId;
  final String? latestTransactionId;
  final Map<String, Object?> metadata;

  bool get isUsable => status.isUsable;
  bool get requiresAttention => status.requiresAttention;
  bool get isInGracePeriod => status == SubscriptionStatus.inGracePeriod;
  bool get isBillingRetry => status == SubscriptionStatus.billingRetry;
  bool get isTrialing => status == SubscriptionStatus.trialing;

  bool isUsableAt(DateTime now) {
    if (!status.isUsable) return false;
    if (now.isBefore(currentPeriodStart)) return false;
    if (now.isAfter(currentPeriodEnd)) {
      // In grace period, grace duration is typically 7-16 days
      return isInGracePeriod;
    }
    return true;
  }

  Subscription copyWith({
    String? id,
    String? learnerId,
    String? planId,
    SubscriptionTier? tier,
    BillingInterval? billingInterval,
    SubscriptionStatus? status,
    DateTime? currentPeriodStart,
    DateTime? currentPeriodEnd,
    bool? cancelAtPeriodEnd,
    DateTime? renewsAt,
    TrialPeriod? trialPeriod,
    int? introductoryPriceCents,
    String? cancellationReason,
    String? originalTransactionId,
    String? latestTransactionId,
    Map<String, Object?>? metadata,
  }) {
    return Subscription(
      id: id ?? this.id,
      learnerId: learnerId ?? this.learnerId,
      planId: planId ?? this.planId,
      tier: tier ?? this.tier,
      billingInterval: billingInterval ?? this.billingInterval,
      status: status ?? this.status,
      currentPeriodStart: currentPeriodStart ?? this.currentPeriodStart,
      currentPeriodEnd: currentPeriodEnd ?? this.currentPeriodEnd,
      cancelAtPeriodEnd: cancelAtPeriodEnd ?? this.cancelAtPeriodEnd,
      renewsAt: renewsAt ?? this.renewsAt,
      trialPeriod: trialPeriod ?? this.trialPeriod,
      introductoryPriceCents:
          introductoryPriceCents ?? this.introductoryPriceCents,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      originalTransactionId:
          originalTransactionId ?? this.originalTransactionId,
      latestTransactionId: latestTransactionId ?? this.latestTransactionId,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Subscription &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          learnerId == other.learnerId &&
          planId == other.planId &&
          status == other.status &&
          currentPeriodEnd == other.currentPeriodEnd;

  @override
  int get hashCode =>
      Object.hash(id, learnerId, planId, status, currentPeriodEnd);
}
