import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_platform/bootstrap/providers.dart';
import 'package:learning_platform/config/app_environment.dart';
import 'package:learning_platform/features/authentication/application/auth_providers.dart';
import 'package:learning_platform/features/authentication/domain/auth_session.dart';
import 'package:learning_platform/features/entitlements/application/entitlement_controller.dart';
import 'package:learning_platform/features/entitlements/application/entitlement_state.dart';
import 'package:learning_platform/features/entitlements/data/entitlement_data_source.dart';
import 'package:learning_platform/features/entitlements/data/entitlement_repository_impl.dart';
import 'package:learning_platform/features/entitlements/data/foundation_entitlement_data_source.dart';
import 'package:learning_platform/features/entitlements/data/remote_entitlement_data_source.dart';
import 'package:learning_platform/features/entitlements/domain/access_decision.dart';
import 'package:learning_platform/features/entitlements/domain/access_evaluator.dart';
import 'package:learning_platform/features/entitlements/domain/access_policy.dart';
import 'package:learning_platform/features/entitlements/domain/access_reason.dart';
import 'package:learning_platform/features/entitlements/domain/entitlement_repository.dart';
import 'package:learning_platform/features/entitlements/domain/resource_type.dart';

final entitlementDataSourceProvider = Provider<EntitlementDataSource>((ref) {
  return switch (ref.watch(appConfigProvider).environment) {
    AppEnvironment.development => FoundationEntitlementDataSource(),
    AppEnvironment.staging || AppEnvironment.production =>
      RemoteEntitlementDataSource(ref.watch(apiClientProvider)),
  };
});

final entitlementRepositoryProvider = Provider<EntitlementRepository>((ref) {
  final learnerId =
      ref.watch(authControllerProvider).session?.identity.id ?? 'anonymous';

  return EntitlementRepositoryImpl(
    remote: ref.watch(entitlementDataSourceProvider),
    localStore: ref.watch(keyValueStoreProvider),
    learnerId: learnerId,
  );
});

final entitlementControllerProvider =
    StateNotifierProvider<EntitlementController, EntitlementState>((ref) {
      final repository = ref.watch(entitlementRepositoryProvider);
      final controller = EntitlementController(repository);
      unawaited(controller.load());
      return controller;
    });

typedef AccessEvaluationQuery = ({
  ResourceType resourceType,
  String resourceId,
  AccessPolicy policy,
  Set<String>? categoryIds,
  String? courseId,
});

final authoritativeAccessDecisionProvider = FutureProvider.autoDispose
    .family<AccessDecision, AccessEvaluationQuery>((ref, query) {
      if (ref.watch(appConfigProvider).environment ==
          AppEnvironment.development) {
        return Future.value(ref.watch(accessDecisionProvider(query)));
      }
      return ref
          .watch(entitlementRepositoryProvider)
          .evaluateAccess(
            resourceType: query.resourceType,
            resourceId: query.resourceId,
            policy: query.policy,
            categoryIds: query.categoryIds,
            courseId: query.courseId,
          );
    });

/// Pure, reactive provider computing the access decision for a resource from the current entitlement state.
final accessDecisionProvider =
    Provider.family<AccessDecision, AccessEvaluationQuery>((ref, query) {
      final entitlementState = ref.watch(entitlementControllerProvider);
      final AuthSession? session = ref.watch(authControllerProvider).session;

      // If user is unauthenticated and content is not free or preview, return unauthenticated decision
      if (session == null && !query.policy.isFree && !query.policy.isPreview) {
        return AccessDecision(
          resourceType: query.resourceType,
          resourceId: query.resourceId,
          canAccess: false,
          state: AccessState.locked,
          reason: AccessReason.unauthenticated,
          evaluatedAt: DateTime.now().toUtc(),
          explanation: 'Sign in to access this content.',
        );
      }

      return AccessEvaluator.evaluate(
        resourceType: query.resourceType,
        resourceId: query.resourceId,
        effectivePolicy: query.policy,
        entitlements: entitlementState.entitlements,
        categoryIds: query.categoryIds,
        courseId: query.courseId,
        isStale: entitlementState.isStale,
      );
    });
