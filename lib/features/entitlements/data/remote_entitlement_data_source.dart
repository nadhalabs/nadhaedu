import 'package:learning_platform/core/errors/result.dart';
import 'package:learning_platform/core/networking/api_client.dart';
import 'package:learning_platform/features/entitlements/data/entitlement_data_source.dart';
import 'package:learning_platform/features/entitlements/domain/access_decision.dart';
import 'package:learning_platform/features/entitlements/domain/access_policy.dart';
import 'package:learning_platform/features/entitlements/domain/access_reason.dart';
import 'package:learning_platform/features/entitlements/domain/entitlement.dart';
import 'package:learning_platform/features/entitlements/domain/entitlement_source.dart';
import 'package:learning_platform/features/entitlements/domain/entitlement_status.dart';
import 'package:learning_platform/features/entitlements/domain/resource_type.dart';

final class RemoteEntitlementDataSource implements EntitlementDataSource {
  const RemoteEntitlementDataSource(this._client);
  final ApiClient _client;
  @override
  Future<List<Entitlement>> fetchEntitlements(String learnerId) async {
    final json = await _get('/api/v1/entitlements');
    return _list(
      json,
      'items',
    ).map((x) => _entitlement(_valueMap(x))).toList(growable: false);
  }

  @override
  Future<bool> verifyAccess({
    required String learnerId,
    required ResourceType resourceType,
    required String targetId,
    required AccessPolicy effectivePolicy,
    Set<String>? categoryIds,
    String? courseId,
  }) async {
    return (await fetchAccessDecision(
      learnerId: learnerId,
      resourceType: resourceType,
      targetId: targetId,
      effectivePolicy: effectivePolicy,
      categoryIds: categoryIds,
      courseId: courseId,
    )).canAccess;
  }

  @override
  Future<AccessDecision> fetchAccessDecision({
    required String learnerId,
    required ResourceType resourceType,
    required String targetId,
    required AccessPolicy effectivePolicy,
    Set<String>? categoryIds,
    String? courseId,
  }) async {
    final type = resourceType == ResourceType.quiz
        ? 'assessment'
        : resourceType.name;
    final json = await _get(
      '/api/v1/access-decisions/$type/${Uri.encodeComponent(targetId)}',
    );
    return AccessDecision(
      resourceType: resourceType,
      resourceId: targetId,
      canAccess: json['allowed']! as bool,
      state: _state(json['accessLevel']! as String),
      reason: _reason(json['reason']! as String),
      evaluatedAt: DateTime.parse(json['evaluatedAt']! as String).toUtc(),
      isStale: false,
      explanation: '',
    );
  }

  Future<Map<String, Object?>> _get(String p) async =>
      switch (await _client.get(p)) {
        Success(value: final v) => v,
        Failure(failure: final f) => throw _error(f),
      };
}

Entitlement _entitlement(Map<String, Object?> j) {
  final metadata =
      (j['metadata'] as Map?)?.cast<String, Object?>() ??
      const <String, Object?>{};
  final sourceId = j['id']! as String;
  return Entitlement(
    id: sourceId,
    learnerId: j['learnerId']! as String,
    source: _source(j['source']! as String, sourceId, metadata),
    status: EntitlementStatus.values.byName(j['status']! as String),
    targetType: j['targetType'] == null
        ? null
        : _resource(j['targetType']! as String),
    targetId: j['targetId'] as String?,
    validFrom: DateTime.parse(j['validFrom']! as String).toUtc(),
    validUntil: j['validUntil'] == null
        ? null
        : DateTime.parse(j['validUntil']! as String).toUtc(),
    metadata: metadata,
  );
}

EntitlementSource _source(String type, String id, Map<String, Object?> m) =>
    switch (type) {
      'subscription' => SubscriptionEntitlementSource(
        sourceId: id,
        planId: m['planId'] as String? ?? 'plan',
        tier: m['tier'] as String? ?? 'premium',
      ),
      'purchase' => IndividualPurchaseEntitlementSource(
        sourceId: id,
        orderId: m['orderId'] as String? ?? id,
        purchasedAt:
            DateTime.tryParse(m['purchasedAt'] as String? ?? '')?.toUtc() ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      ),
      'bundle' => BundleEntitlementSource(
        sourceId: id,
        bundleId: m['bundleId'] as String? ?? id,
        bundleTitle: m['bundleTitle'] as String? ?? 'Bundle',
      ),
      'promotion' => PromotionEntitlementSource(
        sourceId: id,
        campaignId: m['campaignId'] as String? ?? id,
      ),
      'trial' => TrialEntitlementSource(
        sourceId: id,
        trialDays: m['trialDays'] as int? ?? 0,
      ),
      'scholarship' => ScholarshipEntitlementSource(
        sourceId: id,
        scholarshipId: m['scholarshipId'] as String? ?? id,
        organizationName: m['organizationName'] as String? ?? 'Organization',
      ),
      'admin_grant' => AdministrativeGrantEntitlementSource(
        sourceId: id,
        grantedBy: m['grantedBy'] as String? ?? 'administrator',
        reason: m['reason'] as String? ?? 'Access grant',
      ),
      'free' => TimeLimitedAccessEntitlementSource(
        sourceId: id,
        windowId: id,
        grantReason: 'Free access',
      ),
      _ => TimeLimitedAccessEntitlementSource(sourceId: id, windowId: id),
    };
ResourceType _resource(String v) => switch (v) {
  'assessment' => ResourceType.quiz,
  _ => ResourceType.values.byName(v),
};
AccessState _state(String v) => switch (v) {
  'free' => AccessState.free,
  'preview' => AccessState.preview,
  'purchased' => AccessState.purchased,
  'subscribed' => AccessState.subscribed,
  'included' => AccessState.included,
  'expired' => AccessState.expired,
  'unavailable' => AccessState.unavailable,
  _ => AccessState.locked,
};
AccessReason _reason(String v) => switch (v) {
  'FREE_CONTENT' => AccessReason.freeContent,
  'FREE_PREVIEW' => AccessReason.previewAccess,
  'ACTIVE_SUBSCRIPTION' => AccessReason.activeSubscription,
  'PURCHASED' => AccessReason.individualPurchase,
  'BUNDLE_ACCESS' => AccessReason.bundleInclusion,
  'PROMOTIONAL_ACCESS' => AccessReason.promotionalAccess,
  'TRIAL_ACCESS' => AccessReason.activeTrial,
  'SCHOLARSHIP_ACCESS' => AccessReason.scholarshipGrant,
  'ADMINISTRATIVE_GRANT' => AccessReason.administrativeGrant,
  'SUBSCRIPTION_EXPIRED' => AccessReason.subscriptionExpired,
  'CONTENT_UNAVAILABLE' => AccessReason.unavailable,
  _ => AccessReason.locked,
};
EntitlementDataException _error(Object f) => EntitlementDataException(
  f is ApiFailure && f.kind == ApiErrorKind.authenticationRequired
      ? EntitlementErrorKind.unauthenticated
      : f is ApiFailure &&
            (f.kind == ApiErrorKind.accessDenied ||
                f.kind == ApiErrorKind.entitlementRequired)
      ? EntitlementErrorKind.forbidden
      : f is ApiFailure && f.kind == ApiErrorKind.notFound
      ? EntitlementErrorKind.notFound
      : f is ApiFailure
      ? EntitlementErrorKind.network
      : EntitlementErrorKind.unknown,
  f is ApiFailure ? f.message : 'Entitlement request failed.',
);
Map<String, Object?> _valueMap(Object? v) =>
    Map<String, Object?>.from(v! as Map);
List<Object?> _list(Map<String, Object?> j, String k) =>
    (j[k] as List<Object?>?) ?? const [];
