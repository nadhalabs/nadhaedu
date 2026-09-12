import 'package:learning_platform/features/entitlements/domain/access_reason.dart';
import 'package:learning_platform/features/entitlements/domain/entitlement.dart';
import 'package:learning_platform/features/entitlements/domain/resource_type.dart';

enum AccessState {
  /// Open to everyone without restrictions.
  free,

  /// Free preview content within a premium resource.
  preview,

  /// Locked and requires an active entitlement or purchase.
  locked,

  /// Included as part of an active bundle, grant, promo, or scholarship.
  included,

  /// Purchased directly by the learner.
  purchased,

  /// Unlocked via an active subscription plan.
  subscribed,

  /// Previously accessible, but the entitlement has expired.
  expired,

  /// Resource is not accessible or currently unavailable.
  unavailable;

  bool get isAccessible =>
      this == free ||
      this == preview ||
      this == included ||
      this == purchased ||
      this == subscribed;
}

final class AccessDecision {
  const AccessDecision({
    required this.resourceType,
    required this.resourceId,
    required this.canAccess,
    required this.state,
    required this.reason,
    required this.evaluatedAt,
    this.grantingEntitlement,
    this.isStale = false,
    this.explanation = '',
  });

  final ResourceType resourceType;
  final String resourceId;
  final bool canAccess;
  final AccessState state;
  final AccessReason reason;
  final Entitlement? grantingEntitlement;
  final DateTime evaluatedAt;
  final bool isStale;
  final String explanation;

  AccessDecision copyWith({
    ResourceType? resourceType,
    String? resourceId,
    bool? canAccess,
    AccessState? state,
    AccessReason? reason,
    Entitlement? grantingEntitlement,
    DateTime? evaluatedAt,
    bool? isStale,
    String? explanation,
  }) => AccessDecision(
    resourceType: resourceType ?? this.resourceType,
    resourceId: resourceId ?? this.resourceId,
    canAccess: canAccess ?? this.canAccess,
    state: state ?? this.state,
    reason: reason ?? this.reason,
    grantingEntitlement: grantingEntitlement ?? this.grantingEntitlement,
    evaluatedAt: evaluatedAt ?? this.evaluatedAt,
    isStale: isStale ?? this.isStale,
    explanation: explanation ?? this.explanation,
  );

  @override
  String toString() =>
      'AccessDecision(resource: $resourceType:$resourceId, canAccess: $canAccess, state: $state, reason: $reason, isStale: $isStale)';
}
