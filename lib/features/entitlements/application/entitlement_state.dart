import 'package:learning_platform/core/errors/app_failure.dart';
import 'package:learning_platform/features/entitlements/domain/entitlement.dart';

final class EntitlementState {
  const EntitlementState({
    required this.entitlements,
    this.isLoading = false,
    this.isStale = false,
    this.failure,
  });

  const EntitlementState.initial()
    : entitlements = const [],
      isLoading = false,
      isStale = false,
      failure = null;

  final List<Entitlement> entitlements;
  final bool isLoading;
  final bool isStale;
  final AppFailure? failure;

  EntitlementState copyWith({
    List<Entitlement>? entitlements,
    bool? isLoading,
    bool? isStale,
    AppFailure? Function()? failure,
  }) => EntitlementState(
    entitlements: entitlements ?? this.entitlements,
    isLoading: isLoading ?? this.isLoading,
    isStale: isStale ?? this.isStale,
    failure: failure != null ? failure() : this.failure,
  );
}
