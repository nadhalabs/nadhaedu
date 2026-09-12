enum AccessReason {
  /// Content is inherently free.
  freeContent,

  /// Content is marked as a free preview.
  previewAccess,

  /// Free override configured at the module/section level.
  moduleFreeOverride,

  /// Free override configured at the lesson level.
  lessonFreeOverride,

  /// Covered by an active subscription plan.
  activeSubscription,

  /// Purchased directly by the learner.
  individualPurchase,

  /// Included in an owned course bundle.
  bundleInclusion,

  /// Active during a trial period.
  activeTrial,

  /// Granted via an active promotional campaign.
  promotionalAccess,

  /// Granted via coupon redemption.
  couponAccess,

  /// Granted via scholarship or educational organization grant.
  scholarshipGrant,

  /// Granted directly by platform administration.
  administrativeGrant,

  /// Granted for a bounded time window.
  timeLimitedAccess,

  /// Content is locked and requires an entitlement or purchase.
  locked,

  /// Access was previously available but the subscription expired.
  subscriptionExpired,

  /// Access was previously available but the trial period expired.
  trialExpired,

  /// Time-limited access window has expired.
  timeLimitExpired,

  /// Entitlement was revoked or cancelled.
  revoked,

  /// User is not authenticated.
  unauthenticated,

  /// Content is unavailable.
  unavailable;

  bool get isGranted =>
      this == freeContent ||
      this == previewAccess ||
      this == moduleFreeOverride ||
      this == lessonFreeOverride ||
      this == activeSubscription ||
      this == individualPurchase ||
      this == bundleInclusion ||
      this == activeTrial ||
      this == promotionalAccess ||
      this == couponAccess ||
      this == scholarshipGrant ||
      this == administrativeGrant ||
      this == timeLimitedAccess;
}
