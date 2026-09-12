import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_platform/core/analytics/platform_analytics.dart';
import 'package:learning_platform/core/errors/app_failure.dart';
import 'package:learning_platform/core/errors/result.dart';
import 'package:learning_platform/features/profile/domain/profile_repository.dart';

final class AccountSecurityState {
  const AccountSecurityState({
    this.isSubmitting = false,
    this.failure,
    this.successMessage,
  });

  final bool isSubmitting;
  final AppFailure? failure;
  final String? successMessage;

  AccountSecurityState copyWith({
    bool? isSubmitting,
    AppFailure? failure,
    String? successMessage,
    bool clearFailure = false,
    bool clearSuccess = false,
  }) => AccountSecurityState(
    isSubmitting: isSubmitting ?? this.isSubmitting,
    failure: clearFailure ? null : (failure ?? this.failure),
    successMessage: clearSuccess
        ? null
        : (successMessage ?? this.successMessage),
  );
}

final class AccountSecurityController
    extends StateNotifier<AccountSecurityState> {
  AccountSecurityController(this._repository, {PlatformAnalytics? analytics})
    : _analytics = analytics,
      super(const AccountSecurityState());

  final ProfileRepository _repository;
  final PlatformAnalytics? _analytics;

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    state = state.copyWith(
      isSubmitting: true,
      clearFailure: true,
      clearSuccess: true,
    );
    final result = await _repository.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
    switch (result) {
      case Success():
        state = state.copyWith(
          isSubmitting: false,
          successMessage: 'Password successfully updated.',
        );
        return true;
      case Failure(failure: final failure):
        state = state.copyWith(isSubmitting: false, failure: failure);
        return false;
    }
  }

  Future<bool> deleteAccount({
    required String password,
    required String confirmationText,
  }) async {
    state = state.copyWith(
      isSubmitting: true,
      clearFailure: true,
      clearSuccess: true,
    );
    await _analytics?.accountDeletionStarted();

    final result = await _repository.deleteAccount(
      password: password,
      confirmationText: confirmationText,
    );
    switch (result) {
      case Success():
        state = state.copyWith(
          isSubmitting: false,
          successMessage: 'Account deleted successfully.',
        );
        return true;
      case Failure(failure: final failure):
        state = state.copyWith(isSubmitting: false, failure: failure);
        return false;
    }
  }
}
