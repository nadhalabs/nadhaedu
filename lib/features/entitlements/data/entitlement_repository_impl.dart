import 'dart:async';
import 'dart:convert';

import 'package:learning_platform/core/persistence/key_value_store.dart';
import 'package:learning_platform/features/entitlements/data/entitlement_data_source.dart';
import 'package:learning_platform/features/entitlements/domain/access_decision.dart';
import 'package:learning_platform/features/entitlements/domain/access_evaluator.dart';
import 'package:learning_platform/features/entitlements/domain/access_policy.dart';
import 'package:learning_platform/features/entitlements/domain/entitlement.dart';
import 'package:learning_platform/features/entitlements/domain/entitlement_repository.dart';
import 'package:learning_platform/features/entitlements/domain/entitlement_source.dart';
import 'package:learning_platform/features/entitlements/domain/entitlement_status.dart';
import 'package:learning_platform/features/entitlements/domain/resource_type.dart';

final class EntitlementRepositoryImpl implements EntitlementRepository {
  EntitlementRepositoryImpl({
    required EntitlementDataSource remote,
    required KeyValueStore localStore,
    required String learnerId,
  }) : _remote = remote,
       _localStore = localStore,
       _learnerId = learnerId;

  final EntitlementDataSource _remote;
  final KeyValueStore _localStore;
  final String _learnerId;

  final StreamController<List<Entitlement>> _streamController =
      StreamController<List<Entitlement>>.broadcast();

  List<Entitlement>? _cachedEntitlements;
  bool _isStale = false;

  @override
  bool get isCacheStale => _isStale;

  String get _storageKey => 'entitlements.v1.$_learnerId';

  @override
  Future<List<Entitlement>> getEntitlements({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedEntitlements != null && !_isStale) {
      return _cachedEntitlements!;
    }

    try {
      final remoteList = (await _remote.fetchEntitlements(
        _learnerId,
      )).where((item) => item.learnerId == _learnerId).toList(growable: false);
      _cachedEntitlements = remoteList;
      _isStale = false;
      await _writeToCache(remoteList);
      _streamController.add(remoteList);
      return remoteList;
    } on Object {
      // Offline fallback from local persistent store
      final cached = await _readFromCache();
      if (cached != null) {
        _cachedEntitlements = cached;
        _isStale = true;
        _streamController.add(cached);
        return cached;
      }
      rethrow;
    }
  }

  @override
  Stream<List<Entitlement>> watchEntitlements() => _streamController.stream;

  @override
  Future<AccessDecision> evaluateAccess({
    required ResourceType resourceType,
    required String resourceId,
    required AccessPolicy policy,
    Set<String>? categoryIds,
    String? courseId,
  }) async {
    try {
      return await _remote.fetchAccessDecision(
        learnerId: _learnerId,
        resourceType: resourceType,
        targetId: resourceId,
        effectivePolicy: policy,
        categoryIds: categoryIds,
        courseId: courseId,
      );
    } on Object {
      final list = await getEntitlements();
      return AccessEvaluator.evaluate(
        resourceType: resourceType,
        resourceId: resourceId,
        effectivePolicy: policy,
        entitlements: list,
        categoryIds: categoryIds,
        courseId: courseId,
        isStale: true,
      );
    }
  }

  @override
  Future<void> refreshEntitlements() => getEntitlements(forceRefresh: true);

  Future<List<Entitlement>?> _readFromCache() async {
    final raw = await _localStore.readString(_storageKey);
    if (raw == null) return null;
    try {
      final list = jsonDecode(raw) as List<Object?>;
      return list
          .map((item) => _entitlementFromJson(item! as Map<String, Object?>))
          .where((item) => item.learnerId == _learnerId)
          .toList(growable: false);
    } on Object {
      return null;
    }
  }

  Future<void> _writeToCache(List<Entitlement> entitlements) async {
    final encoded = jsonEncode(
      entitlements.map(_entitlementToJson).toList(growable: false),
    );
    await _localStore.writeString(_storageKey, encoded);
  }
}

// -----------------------------------------------------------------------------
// JSON Serialization Helpers
// -----------------------------------------------------------------------------

Map<String, Object?> _entitlementToJson(Entitlement e) => {
  'id': e.id,
  'learnerId': e.learnerId,
  'status': e.status.name,
  'validFrom': e.validFrom.toIso8601String(),
  'validUntil': e.validUntil?.toIso8601String(),
  'targetType': e.targetType?.name,
  'targetId': e.targetId,
  'categoryIds': e.categoryIds.toList(growable: false),
  'metadata': e.metadata,
  'source': _sourceToJson(e.source),
};

Entitlement _entitlementFromJson(Map<String, Object?> json) => Entitlement(
  id: json['id']! as String,
  learnerId: json['learnerId']! as String,
  status: EntitlementStatus.values.byName(json['status']! as String),
  validFrom: DateTime.parse(json['validFrom']! as String),
  validUntil: json['validUntil'] != null
      ? DateTime.parse(json['validUntil']! as String)
      : null,
  targetType: json['targetType'] != null
      ? ResourceType.values.byName(json['targetType']! as String)
      : null,
  targetId: json['targetId'] as String?,
  categoryIds: ((json['categoryIds'] as List<Object?>?) ?? const [])
      .cast<String>()
      .toSet(),
  metadata: (json['metadata'] as Map<String, Object?>?) ?? const {},
  source: _sourceFromJson(json['source']! as Map<String, Object?>),
);

Map<String, Object?> _sourceToJson(EntitlementSource source) =>
    switch (source) {
      final SubscriptionEntitlementSource s => {
        'type': 'subscription',
        'sourceId': s.sourceId,
        'planId': s.planId,
        'tier': s.tier,
        'renewsAt': s.renewsAt?.toIso8601String(),
        'autoRenewing': s.autoRenewing,
      },
      final IndividualPurchaseEntitlementSource p => {
        'type': 'purchase',
        'sourceId': p.sourceId,
        'orderId': p.orderId,
        'purchasedAt': p.purchasedAt.toIso8601String(),
        'amountCents': p.amountCents,
        'currencyCode': p.currencyCode,
      },
      final BundleEntitlementSource b => {
        'type': 'bundle',
        'sourceId': b.sourceId,
        'bundleId': b.bundleId,
        'bundleTitle': b.bundleTitle,
      },
      final PromotionEntitlementSource pr => {
        'type': 'promotion',
        'sourceId': pr.sourceId,
        'campaignId': pr.campaignId,
        'promoCode': pr.promoCode,
      },
      final TrialEntitlementSource t => {
        'type': 'trial',
        'sourceId': t.sourceId,
        'trialDays': t.trialDays,
        'planId': t.planId,
        'convertedToSubscription': t.convertedToSubscription,
      },
      final CouponEntitlementSource c => {
        'type': 'coupon',
        'sourceId': c.sourceId,
        'code': c.code,
        'campaignId': c.campaignId,
      },
      final ScholarshipEntitlementSource sc => {
        'type': 'scholarship',
        'sourceId': sc.sourceId,
        'scholarshipId': sc.scholarshipId,
        'organizationName': sc.organizationName,
        'grantor': sc.grantor,
      },
      final AdministrativeGrantEntitlementSource a => {
        'type': 'admin',
        'sourceId': a.sourceId,
        'grantedBy': a.grantedBy,
        'reason': a.reason,
        'ticketId': a.ticketId,
      },
      final TimeLimitedAccessEntitlementSource tl => {
        'type': 'time_limited',
        'sourceId': tl.sourceId,
        'windowId': tl.windowId,
        'grantReason': tl.grantReason,
      },
    };

EntitlementSource _sourceFromJson(Map<String, Object?> json) {
  final type = json['type']! as String;
  final sourceId = json['sourceId']! as String;
  return switch (type) {
    'subscription' => SubscriptionEntitlementSource(
      sourceId: sourceId,
      planId: json['planId']! as String,
      tier: json['tier']! as String,
      renewsAt: json['renewsAt'] != null
          ? DateTime.parse(json['renewsAt']! as String)
          : null,
      autoRenewing: (json['autoRenewing'] as bool?) ?? true,
    ),
    'purchase' => IndividualPurchaseEntitlementSource(
      sourceId: sourceId,
      orderId: json['orderId']! as String,
      purchasedAt: DateTime.parse(json['purchasedAt']! as String),
      amountCents: json['amountCents'] as int?,
      currencyCode: json['currencyCode'] as String?,
    ),
    'bundle' => BundleEntitlementSource(
      sourceId: sourceId,
      bundleId: json['bundleId']! as String,
      bundleTitle: json['bundleTitle']! as String,
    ),
    'promotion' => PromotionEntitlementSource(
      sourceId: sourceId,
      campaignId: json['campaignId']! as String,
      promoCode: json['promoCode'] as String?,
    ),
    'trial' => TrialEntitlementSource(
      sourceId: sourceId,
      trialDays: json['trialDays']! as int,
      planId: json['planId'] as String?,
      convertedToSubscription:
          (json['convertedToSubscription'] as bool?) ?? false,
    ),
    'coupon' => CouponEntitlementSource(
      sourceId: sourceId,
      code: json['code']! as String,
      campaignId: json['campaignId'] as String?,
    ),
    'scholarship' => ScholarshipEntitlementSource(
      sourceId: sourceId,
      scholarshipId: json['scholarshipId']! as String,
      organizationName: json['organizationName']! as String,
      grantor: json['grantor'] as String?,
    ),
    'admin' => AdministrativeGrantEntitlementSource(
      sourceId: sourceId,
      grantedBy: json['grantedBy']! as String,
      reason: json['reason']! as String,
      ticketId: json['ticketId'] as String?,
    ),
    'time_limited' => TimeLimitedAccessEntitlementSource(
      sourceId: sourceId,
      windowId: json['windowId']! as String,
      grantReason: json['grantReason'] as String?,
    ),
    _ => throw FormatException('Unknown EntitlementSource type: $type'),
  };
}
