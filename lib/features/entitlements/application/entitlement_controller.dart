import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_platform/core/errors/app_failure.dart';
import 'package:learning_platform/features/entitlements/application/entitlement_state.dart';
import 'package:learning_platform/features/entitlements/domain/entitlement_repository.dart';

final class EntitlementController extends StateNotifier<EntitlementState> {
  EntitlementController(this._repository)
    : super(const EntitlementState.initial());

  final EntitlementRepository _repository;

  Future<void> load({bool forceRefresh = false}) async {
    state = state.copyWith(isLoading: true, failure: () => null);
    try {
      final list = await _repository.getEntitlements(
        forceRefresh: forceRefresh,
      );
      state = state.copyWith(
        entitlements: list,
        isLoading: false,
        isStale: _repository.isCacheStale,
        failure: () => null,
      );
    } on Object catch (error) {
      state = state.copyWith(
        isLoading: false,
        isStale: true,
        failure: () => UnexpectedFailure(
          code: 'entitlements_sync_failed',
          message: 'Failed to synchronize entitlements.',
          cause: error,
        ),
      );
    }
  }

  Future<void> refresh() => load(forceRefresh: true);
}
