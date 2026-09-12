import 'package:flutter_test/flutter_test.dart';
import 'package:learning_platform/features/entitlements/data/entitlement_data_source.dart';
import 'package:learning_platform/features/entitlements/data/entitlement_repository_impl.dart';
import 'package:learning_platform/features/entitlements/domain/access_decision.dart';
import 'package:learning_platform/features/entitlements/domain/access_policy.dart';
import 'package:learning_platform/features/entitlements/domain/access_reason.dart';
import 'package:learning_platform/features/entitlements/domain/entitlement.dart';
import 'package:learning_platform/features/entitlements/domain/entitlement_source.dart';
import 'package:learning_platform/features/entitlements/domain/entitlement_status.dart';
import 'package:learning_platform/features/entitlements/domain/resource_type.dart';

import '../../../helpers/memory_key_value_store.dart';

final class _FakeEntitlementDataSource implements EntitlementDataSource {
  _FakeEntitlementDataSource(this.entitlements);

  List<Entitlement> entitlements;
  bool shouldThrow = false;

  @override
  Future<List<Entitlement>> fetchEntitlements(String learnerId) async {
    if (shouldThrow) {
      throw const EntitlementDataException(
        EntitlementErrorKind.network,
        'Network error',
      );
    }
    return entitlements;
  }

  @override
  Future<bool> verifyAccess({
    required String learnerId,
    required ResourceType resourceType,
    required String targetId,
    required AccessPolicy effectivePolicy,
    Set<String>? categoryIds,
    String? courseId,
  }) async => true;

  @override
  Future<AccessDecision> fetchAccessDecision({
    required String learnerId,
    required ResourceType resourceType,
    required String targetId,
    required AccessPolicy effectivePolicy,
    Set<String>? categoryIds,
    String? courseId,
  }) async {
    if (shouldThrow) {
      throw const EntitlementDataException(
        EntitlementErrorKind.network,
        'Network error',
      );
    }
    return AccessDecision(
      resourceType: resourceType,
      resourceId: targetId,
      canAccess: true,
      state: AccessState.subscribed,
      reason: AccessReason.activeSubscription,
      evaluatedAt: DateTime.now().toUtc(),
    );
  }
}

void main() {
  group('EntitlementRepositoryImpl', () {
    test(
      'fetches from remote, caches to local store, and evaluates access',
      () async {
        final localStore = MemoryKeyValueStore();
        final sampleEntitlements = [
          Entitlement(
            id: 'ent-1',
            learnerId: 'learner-alpha',
            source: SubscriptionEntitlementSource(
              sourceId: 'src-1',
              planId: 'plan_pro',
              tier: 'Pro',
              renewsAt: DateTime.utc(2026, 12, 31),
            ),
            status: EntitlementStatus.active,
            validFrom: DateTime.utc(2026, 1, 1),
            validUntil: DateTime.utc(2026, 12, 31),
          ),
        ];

        final fakeRemote = _FakeEntitlementDataSource(sampleEntitlements);
        final repository = EntitlementRepositoryImpl(
          remote: fakeRemote,
          localStore: localStore,
          learnerId: 'learner-alpha',
        );

        final list = await repository.getEntitlements();
        expect(list.length, equals(1));
        expect(list.first.id, equals('ent-1'));

        // Check evaluation
        final decision = await repository.evaluateAccess(
          resourceType: ResourceType.course,
          resourceId: 'course-1',
          policy: const AccessPolicy.premium(),
        );
        expect(decision.canAccess, isTrue);
        expect(decision.isStale, isFalse);

        // Verify persistent cache exists
        final cachedJson = await localStore.readString(
          'entitlements.v1.learner-alpha',
        );
        expect(cachedJson, isNotNull);
        expect(cachedJson, contains('ent-1'));
      },
    );

    test(
      'falls back to local cache with isStale=true during network outage',
      () async {
        final localStore = MemoryKeyValueStore();
        final sampleEntitlements = [
          Entitlement(
            id: 'ent-persisted',
            learnerId: 'learner-beta',
            source: const PromotionEntitlementSource(
              sourceId: 'promo-1',
              campaignId: 'summer-sale',
              promoCode: 'SUMMER26',
            ),
            status: EntitlementStatus.active,
            validFrom: DateTime.utc(2026, 1, 1),
          ),
        ];

        final fakeRemote = _FakeEntitlementDataSource(sampleEntitlements);
        final repo1 = EntitlementRepositoryImpl(
          remote: fakeRemote,
          localStore: localStore,
          learnerId: 'learner-beta',
        );
        await repo1.getEntitlements();

        // Now create a second repository instance simulating app restart while offline
        fakeRemote.shouldThrow = true;
        final repo2 = EntitlementRepositoryImpl(
          remote: fakeRemote,
          localStore: localStore,
          learnerId: 'learner-beta',
        );

        final cachedList = await repo2.getEntitlements();
        expect(cachedList.length, equals(1));
        expect(cachedList.first.id, equals('ent-persisted'));

        final decision = await repo2.evaluateAccess(
          resourceType: ResourceType.course,
          resourceId: 'course-1',
          policy: const AccessPolicy.premium(),
        );
        expect(decision.canAccess, isTrue);
        expect(decision.isStale, isTrue);
      },
    );

    test(
      'serializes and deserializes all 9 entitlement source types accurately',
      () async {
        final localStore = MemoryKeyValueStore();
        final allSources = [
          Entitlement(
            id: 'e1',
            learnerId: 'u1',
            source: const SubscriptionEntitlementSource(
              sourceId: 's1',
              planId: 'pro',
              tier: 'Pro',
            ),
            status: EntitlementStatus.active,
            validFrom: DateTime.utc(2026, 1, 1),
          ),
          Entitlement(
            id: 'e2',
            learnerId: 'u1',
            source: IndividualPurchaseEntitlementSource(
              sourceId: 's2',
              orderId: 'ORD-1',
              purchasedAt: DateTime.utc(2026, 2, 1),
              amountCents: 4900,
              currencyCode: 'USD',
            ),
            status: EntitlementStatus.active,
            validFrom: DateTime.utc(2026, 2, 1),
          ),
          Entitlement(
            id: 'e3',
            learnerId: 'u1',
            source: const BundleEntitlementSource(
              sourceId: 's3',
              bundleId: 'bun-1',
              bundleTitle: 'AI Suite',
            ),
            status: EntitlementStatus.active,
            validFrom: DateTime.utc(2026, 3, 1),
          ),
          Entitlement(
            id: 'e4',
            learnerId: 'u1',
            source: const PromotionEntitlementSource(
              sourceId: 's4',
              campaignId: 'camp-1',
              promoCode: 'SAVE50',
            ),
            status: EntitlementStatus.active,
            validFrom: DateTime.utc(2026, 4, 1),
          ),
          Entitlement(
            id: 'e5',
            learnerId: 'u1',
            source: const TrialEntitlementSource(sourceId: 's5', trialDays: 7),
            status: EntitlementStatus.active,
            validFrom: DateTime.utc(2026, 5, 1),
          ),
          Entitlement(
            id: 'e6',
            learnerId: 'u1',
            source: const CouponEntitlementSource(
              sourceId: 's6',
              code: 'COUPON100',
            ),
            status: EntitlementStatus.active,
            validFrom: DateTime.utc(2026, 6, 1),
          ),
          Entitlement(
            id: 'e7',
            learnerId: 'u1',
            source: const ScholarshipEntitlementSource(
              sourceId: 's7',
              scholarshipId: 'SCH-1',
              organizationName: 'Global Foundation',
            ),
            status: EntitlementStatus.active,
            validFrom: DateTime.utc(2026, 7, 1),
          ),
          Entitlement(
            id: 'e8',
            learnerId: 'u1',
            source: const AdministrativeGrantEntitlementSource(
              sourceId: 's8',
              grantedBy: 'admin',
              reason: 'Review',
            ),
            status: EntitlementStatus.active,
            validFrom: DateTime.utc(2026, 8, 1),
          ),
          Entitlement(
            id: 'e9',
            learnerId: 'u1',
            source: const TimeLimitedAccessEntitlementSource(
              sourceId: 's9',
              windowId: 'win-1',
            ),
            status: EntitlementStatus.active,
            validFrom: DateTime.utc(2026, 8, 15),
          ),
        ];

        final fakeRemote = _FakeEntitlementDataSource(allSources);
        final repo = EntitlementRepositoryImpl(
          remote: fakeRemote,
          localStore: localStore,
          learnerId: 'u1',
        );

        await repo.getEntitlements();

        // Clear in-memory and reload from cache
        fakeRemote.shouldThrow = true;
        final repoReloaded = EntitlementRepositoryImpl(
          remote: fakeRemote,
          localStore: localStore,
          learnerId: 'u1',
        );
        final reloaded = await repoReloaded.getEntitlements();

        expect(reloaded.length, equals(9));
        expect(reloaded[0].source, isA<SubscriptionEntitlementSource>());
        expect(reloaded[1].source, isA<IndividualPurchaseEntitlementSource>());
        expect(reloaded[2].source, isA<BundleEntitlementSource>());
        expect(reloaded[3].source, isA<PromotionEntitlementSource>());
        expect(reloaded[4].source, isA<TrialEntitlementSource>());
        expect(reloaded[5].source, isA<CouponEntitlementSource>());
        expect(reloaded[6].source, isA<ScholarshipEntitlementSource>());
        expect(reloaded[7].source, isA<AdministrativeGrantEntitlementSource>());
        expect(reloaded[8].source, isA<TimeLimitedAccessEntitlementSource>());
      },
    );
  });
}
