import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_platform/features/entitlements/data/entitlement_repository_impl.dart';
import 'package:learning_platform/features/entitlements/data/foundation_entitlement_data_source.dart';
import 'package:learning_platform/features/entitlements/data/unconfigured_entitlement_data_source.dart';
import 'package:learning_platform/features/entitlements/domain/access_policy.dart';
import 'package:learning_platform/features/entitlements/domain/entitlement.dart';
import 'package:learning_platform/features/entitlements/domain/entitlement_source.dart';
import 'package:learning_platform/features/entitlements/domain/entitlement_status.dart';
import 'package:learning_platform/features/entitlements/domain/resource_type.dart';
import 'package:learning_platform/features/learning_progress/data/foundation_learning_data_source.dart';
import 'package:learning_platform/features/learning_progress/data/learning_data_source.dart';

import '../../helpers/memory_key_value_store.dart';

void main() {
  group('Entitlement Security Boundary', () {
    test(
      'tampering with local client storage does not grant access to protected server playback content',
      () async {
        const attackerLearnerId = 'unauthorized-user-999';
        final serverEntitlementSource = FoundationEntitlementDataSource();
        final serverLearningSource = FoundationLearningDataSource(
          entitlementDataSource: serverEntitlementSource,
        );

        // Server confirms learner has no active entitlements
        final serverEntitlements = await serverEntitlementSource
            .fetchEntitlements(attackerLearnerId);
        expect(serverEntitlements, isEmpty);

        // Attacker injects a fraudulent active Pro subscription into local device storage
        final localStore = MemoryKeyValueStore();
        final now = DateTime.now().toUtc();
        final fraudulentLocalEntitlement = [
          {
            'id': 'fake-ent-hacked',
            'learnerId': attackerLearnerId,
            'status': 'active',
            'validFrom': now
                .subtract(const Duration(days: 1))
                .toIso8601String(),
            'validUntil': now.add(const Duration(days: 365)).toIso8601String(),
            'targetType': null,
            'targetId': null,
            'categoryIds': <String>[],
            'metadata': <String, Object?>{},
            'source': {
              'type': 'subscription',
              'sourceId': 'fake-src',
              'planId': 'plan_pro',
              'tier': 'Pro',
              'autoRenewing': true,
            },
          },
        ];
        await localStore.writeString(
          'entitlements.v1.$attackerLearnerId',
          jsonEncode(fraudulentLocalEntitlement),
        );

        // The client repository instance reads from local cache when offline
        final clientRepo = EntitlementRepositoryImpl(
          remote: const UnconfiguredEntitlementDataSource(),
          localStore: localStore,
          learnerId: attackerLearnerId,
        );

        // An offline client can be tricked into optimistic presentation state.
        final localDecision = await clientRepo.evaluateAccess(
          resourceType: ResourceType.lesson,
          resourceId: 'video-protected-course-4-lesson-2',
          policy: const AccessPolicy.premium(),
        );
        expect(localDecision.canAccess, isTrue);
        expect(localDecision.isStale, isTrue);

        // When the attacker bypasses repository and attempts to request protected server stream:
        // The authoritative backend MUST reject the request
        expect(
          () => serverLearningSource.fetchPlaybackSource(
            attackerLearnerId,
            'video-protected-course-4-lesson-2',
          ),
          throwsA(
            isA<LearningDataException>().having(
              (e) => e.kind,
              'kind',
              equals(LearningDataErrorKind.unauthorized),
            ),
          ),
        );
      },
    );

    test(
      'server authority recognizes a course purchase for child playback',
      () async {
        const learnerId = 'purchase-learner';
        final serverEntitlementSource = FoundationEntitlementDataSource();
        serverEntitlementSource.grantEntitlement(
          Entitlement(
            id: 'purchase-course-4',
            learnerId: learnerId,
            source: IndividualPurchaseEntitlementSource(
              sourceId: 'purchase-source',
              orderId: 'order-4',
              purchasedAt: DateTime.utc(2026, 8, 1),
            ),
            status: EntitlementStatus.active,
            targetType: ResourceType.course,
            targetId: 'course-4',
            validFrom: DateTime.utc(2026, 8, 1),
          ),
        );
        final serverLearningSource = FoundationLearningDataSource(
          entitlementDataSource: serverEntitlementSource,
        );

        final source = await serverLearningSource.fetchPlaybackSource(
          learnerId,
          'video-protected-course-4-lesson-2',
        );

        expect(source.streamUri.scheme, 'https');
      },
    );

    test(
      'server authority permits playback for valid entitled learner',
      () async {
        final serverEntitlementSource = FoundationEntitlementDataSource();
        final serverLearningSource = FoundationLearningDataSource(
          entitlementDataSource: serverEntitlementSource,
        );

        // dev-learner has an active subscription in FoundationEntitlementDataSource
        final source = await serverLearningSource.fetchPlaybackSource(
          'dev-learner',
          'video-protected-course-4-lesson-2',
        );

        expect(source.streamUri.toString(), contains('master.m3u8'));
      },
    );
  });
}
