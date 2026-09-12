import 'package:learning_platform/features/entitlements/domain/access_decision.dart';
import 'package:learning_platform/features/entitlements/domain/access_policy.dart';
import 'package:learning_platform/features/entitlements/domain/access_reason.dart';
import 'package:learning_platform/features/entitlements/domain/entitlement.dart';
import 'package:learning_platform/features/entitlements/domain/entitlement_source.dart';
import 'package:learning_platform/features/entitlements/domain/entitlement_status.dart';
import 'package:learning_platform/features/entitlements/domain/resource_type.dart';

/// Centralized, deterministic domain evaluator for freemium access decisions.
abstract final class AccessEvaluator {
  /// Evaluates access for a specific resource given the resolved effective policy
  /// and the learner's set of entitlements.
  static AccessDecision evaluate({
    required ResourceType resourceType,
    required String resourceId,
    required AccessPolicy effectivePolicy,
    required List<Entitlement> entitlements,
    Set<String>? categoryIds,
    String? courseId,
    DateTime? at,
    bool isStale = false,
  }) {
    final now = at ?? DateTime.now().toUtc();

    if (effectivePolicy.isUnavailable) {
      return AccessDecision(
        resourceType: resourceType,
        resourceId: resourceId,
        canAccess: false,
        state: AccessState.unavailable,
        reason: AccessReason.unavailable,
        evaluatedAt: now,
        isStale: isStale,
        explanation: 'This content is currently unavailable.',
      );
    }

    // 1. Inherent or override free access
    if (effectivePolicy.isFree) {
      return AccessDecision(
        resourceType: resourceType,
        resourceId: resourceId,
        canAccess: true,
        state: AccessState.free,
        reason: AccessReason.freeContent,
        evaluatedAt: now,
        isStale: isStale,
        explanation: 'This content is freely accessible.',
      );
    }

    // 2. Free preview access
    if (effectivePolicy.isPreview) {
      return AccessDecision(
        resourceType: resourceType,
        resourceId: resourceId,
        canAccess: true,
        state: AccessState.preview,
        reason: AccessReason.previewAccess,
        evaluatedAt: now,
        isStale: isStale,
        explanation: 'Free preview access available.',
      );
    }

    // 3. Premium evaluation: check active/usable entitlements covering this resource
    final coveringUsable = entitlements
        .where(
          (e) =>
              e.isUsableAt(now) &&
              _satisfiesPolicy(e, effectivePolicy) &&
              e.covers(
                resourceType: resourceType,
                resourceId: resourceId,
                itemCategoryIds: categoryIds,
                courseId: courseId,
              ),
        )
        .toList(growable: false);

    if (coveringUsable.isNotEmpty) {
      final best = _selectPrecedentEntitlement(coveringUsable);
      final (reason, state, explanation) = _mapSourceToDecision(best.source);

      return AccessDecision(
        resourceType: resourceType,
        resourceId: resourceId,
        canAccess: true,
        state: state,
        reason: reason,
        grantingEntitlement: best,
        evaluatedAt: now,
        isStale: isStale,
        explanation: explanation,
      );
    }

    // 4. Check for expired entitlements
    final coveringExpired = entitlements
        .where(
          (e) =>
              e.isExpiredAt(now) &&
              e.covers(
                resourceType: resourceType,
                resourceId: resourceId,
                itemCategoryIds: categoryIds,
                courseId: courseId,
              ),
        )
        .toList(growable: false);

    if (coveringExpired.isNotEmpty) {
      final latestExpired = coveringExpired.reduce(
        (a, b) =>
            (a.validUntil ?? a.validFrom).isAfter(b.validUntil ?? b.validFrom)
            ? a
            : b,
      );

      final (expiredReason, explanation) = switch (latestExpired.source) {
        SubscriptionEntitlementSource() => (
          AccessReason.subscriptionExpired,
          'Your subscription has expired. Renew to access this content.',
        ),
        TrialEntitlementSource() => (
          AccessReason.trialExpired,
          'Your free trial has ended. Subscribe to continue learning.',
        ),
        TimeLimitedAccessEntitlementSource() => (
          AccessReason.timeLimitExpired,
          'Your time-limited access window has expired.',
        ),
        _ => (AccessReason.locked, 'Your previous access grant has expired.'),
      };

      return AccessDecision(
        resourceType: resourceType,
        resourceId: resourceId,
        canAccess: false,
        state: AccessState.expired,
        reason: expiredReason,
        grantingEntitlement: latestExpired,
        evaluatedAt: now,
        isStale: isStale,
        explanation: explanation,
      );
    }

    // 5. Check for revoked entitlements
    final hasRevoked = entitlements.any(
      (e) =>
          e.status == EntitlementStatus.revoked &&
          e.covers(
            resourceType: resourceType,
            resourceId: resourceId,
            itemCategoryIds: categoryIds,
            courseId: courseId,
          ),
    );

    if (hasRevoked) {
      return AccessDecision(
        resourceType: resourceType,
        resourceId: resourceId,
        canAccess: false,
        state: AccessState.locked,
        reason: AccessReason.revoked,
        evaluatedAt: now,
        isStale: isStale,
        explanation: 'Access to this content was revoked.',
      );
    }

    // 6. Default locked state
    return AccessDecision(
      resourceType: resourceType,
      resourceId: resourceId,
      canAccess: false,
      state: AccessState.locked,
      reason: AccessReason.locked,
      evaluatedAt: now,
      isStale: isStale,
      explanation:
          'Content is locked. An active subscription or purchase is required.',
    );
  }

  /// Resolves multiple simultaneous entitlement sources by strict precedence order:
  /// Administrative Grant > Scholarship > Individual Purchase > Bundle > Subscription > Promotion > Coupon > Trial > Time-Limited
  static Entitlement _selectPrecedentEntitlement(List<Entitlement> list) {
    if (list.length == 1) return list.first;

    final sorted = [...list]
      ..sort((a, b) {
        final weightA = _sourcePrecedence(a.source);
        final weightB = _sourcePrecedence(b.source);
        if (weightA != weightB) {
          return weightB.compareTo(weightA); // higher precedence first
        }
        return b.validFrom.compareTo(a.validFrom); // newer first
      });

    return sorted.first;
  }

  static int _sourcePrecedence(EntitlementSource source) => switch (source) {
    AdministrativeGrantEntitlementSource() => 100,
    ScholarshipEntitlementSource() => 90,
    IndividualPurchaseEntitlementSource() => 80,
    BundleEntitlementSource() => 70,
    SubscriptionEntitlementSource() => 60,
    PromotionEntitlementSource() => 50,
    CouponEntitlementSource() => 40,
    TrialEntitlementSource() => 30,
    TimeLimitedAccessEntitlementSource() => 20,
  };

  static bool _satisfiesPolicy(Entitlement entitlement, AccessPolicy policy) {
    final source = entitlement.source;
    if (source case SubscriptionEntitlementSource(tier: final tier)) {
      final requiredTier = policy.requiredTier;
      if (requiredTier != null &&
          tier.toLowerCase() != requiredTier.toLowerCase()) {
        return false;
      }
    }
    if (source case TrialEntitlementSource(planId: final planId)) {
      final requiredTier = policy.requiredTier;
      if (requiredTier != null &&
          (planId == null ||
              !planId.toLowerCase().contains(requiredTier.toLowerCase()))) {
        return false;
      }
    }
    if (source case BundleEntitlementSource(bundleId: final bundleId)) {
      final requiredBundleId = policy.requiredBundleId;
      if (requiredBundleId != null && bundleId != requiredBundleId) {
        return false;
      }
    }
    return true;
  }

  static (AccessReason, AccessState, String) _mapSourceToDecision(
    EntitlementSource source,
  ) => switch (source) {
    AdministrativeGrantEntitlementSource() => (
      AccessReason.administrativeGrant,
      AccessState.included,
      'Access granted by platform administration.',
    ),
    ScholarshipEntitlementSource(organizationName: final org) => (
      AccessReason.scholarshipGrant,
      AccessState.included,
      'Access granted via $org scholarship.',
    ),
    IndividualPurchaseEntitlementSource() => (
      AccessReason.individualPurchase,
      AccessState.purchased,
      'You own this content via direct purchase.',
    ),
    BundleEntitlementSource(bundleTitle: final title) => (
      AccessReason.bundleInclusion,
      AccessState.included,
      'Included in your "$title" bundle.',
    ),
    SubscriptionEntitlementSource(tier: final tier) => (
      AccessReason.activeSubscription,
      AccessState.subscribed,
      'Included with your $tier subscription.',
    ),
    PromotionEntitlementSource() => (
      AccessReason.promotionalAccess,
      AccessState.included,
      'Unlocked via special promotional access.',
    ),
    CouponEntitlementSource() => (
      AccessReason.couponAccess,
      AccessState.included,
      'Unlocked via coupon code.',
    ),
    TrialEntitlementSource() => (
      AccessReason.activeTrial,
      AccessState.subscribed,
      'Accessible during your active free trial.',
    ),
    TimeLimitedAccessEntitlementSource() => (
      AccessReason.timeLimitedAccess,
      AccessState.included,
      'Accessible during your temporary access window.',
    ),
  };
}
