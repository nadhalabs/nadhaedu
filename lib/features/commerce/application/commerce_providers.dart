import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_platform/bootstrap/providers.dart';
import 'package:learning_platform/config/app_environment.dart';
import 'package:learning_platform/features/authentication/application/auth_providers.dart';
import 'package:learning_platform/features/commerce/application/commerce_controller.dart';
import 'package:learning_platform/features/commerce/application/commerce_state.dart';
import 'package:learning_platform/features/commerce/data/commerce_data_source.dart';
import 'package:learning_platform/features/commerce/data/commerce_repository_impl.dart';
import 'package:learning_platform/features/commerce/data/foundation_commerce_data_source.dart';
import 'package:learning_platform/features/commerce/data/foundation_platform_billing_service.dart';
import 'package:learning_platform/features/commerce/data/remote_commerce_data_source.dart';
import 'package:learning_platform/features/commerce/data/unconfigured_platform_billing_service.dart';
import 'package:learning_platform/features/commerce/domain/commerce_analytics.dart';
import 'package:learning_platform/features/commerce/domain/commerce_product.dart';
import 'package:learning_platform/features/commerce/domain/commerce_repository.dart';
import 'package:learning_platform/features/commerce/domain/platform_billing_service.dart';
import 'package:learning_platform/features/commerce/domain/subscription.dart';
import 'package:learning_platform/features/entitlements/application/entitlement_providers.dart';
import 'package:learning_platform/features/entitlements/data/foundation_entitlement_data_source.dart';

final commerceDataSourceProvider = Provider<CommerceDataSource>((ref) {
  return switch (ref.watch(appConfigProvider).environment) {
    AppEnvironment.development => FoundationCommerceDataSource(
      entitlementDataSource:
          ref.watch(entitlementDataSourceProvider)
              as FoundationEntitlementDataSource?,
    ),
    AppEnvironment.staging || AppEnvironment.production =>
      RemoteCommerceDataSource(ref.watch(apiClientProvider)),
  };
});

final platformBillingServiceProvider = Provider<PlatformBillingService>((ref) {
  return switch (ref.watch(appConfigProvider).environment) {
    AppEnvironment.development => FoundationPlatformBillingService(),
    AppEnvironment.staging ||
    AppEnvironment.production => const UnconfiguredPlatformBillingService(),
  };
});

final commerceAnalyticsTrackerProvider = Provider<CommerceAnalyticsTracker>((
  ref,
) {
  return CommerceAnalyticsTracker(ref.watch(analyticsProvider));
});

final commerceRepositoryProvider = Provider<CommerceRepository>((ref) {
  final learnerId =
      ref.watch(authControllerProvider).session?.identity.id ?? 'anonymous';

  return CommerceRepositoryImpl(
    dataSource: ref.watch(commerceDataSourceProvider),
    localStore: ref.watch(keyValueStoreProvider),
    learnerId: learnerId,
  );
});

final commerceControllerProvider =
    StateNotifierProvider<CommerceController, CommerceState>((ref) {
      final learnerId =
          ref.watch(authControllerProvider).session?.identity.id ?? 'anonymous';
      final repository = ref.watch(commerceRepositoryProvider);
      final billing = ref.watch(platformBillingServiceProvider);
      final analytics = ref.watch(commerceAnalyticsTrackerProvider);
      final entitlementController = ref.watch(
        entitlementControllerProvider.notifier,
      );

      final controller = CommerceController(
        repository: repository,
        billingService: billing,
        analytics: analytics,
        entitlementController: entitlementController,
        learnerId: learnerId,
      );

      unawaited(controller.initialize());
      return controller;
    });

final subscriptionPlansProvider =
    FutureProvider.autoDispose<List<SubscriptionPlan>>((ref) {
      return ref.watch(commerceRepositoryProvider).getSubscriptionPlans();
    });

final courseProductsProvider = FutureProvider.autoDispose<List<CourseProduct>>((
  ref,
) {
  return ref.watch(commerceRepositoryProvider).getCourseProducts();
});

final activeSubscriptionProvider = Provider.autoDispose<Subscription?>((ref) {
  return ref.watch(commerceControllerProvider).activeSubscription;
});
