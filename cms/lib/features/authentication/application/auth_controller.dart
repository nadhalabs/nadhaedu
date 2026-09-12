import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nadha_cms/core/errors/result.dart';
import 'package:nadha_cms/features/authentication/application/auth_service.dart';
import 'package:nadha_cms/features/authentication/application/auth_state.dart';
import 'package:nadha_cms/features/authentication/domain/auth_failure.dart';
import 'package:nadha_cms/features/authentication/domain/auth_session.dart';

final class AuthController extends StateNotifier<AuthState> {
  AuthController(this._service) : super(const AuthState.bootstrapping());

  final AuthService _service;

  void expireSession() {
    if (mounted) state = const AuthState(status: AuthStatus.expired);
  }

  Future<void> bootstrap() async {
    state = const AuthState.bootstrapping();
    final result = await _service.bootstrap();
    switch (result) {
      case Success<AuthSession?>(value: final session):
        state = session == null
            ? const AuthState(status: AuthStatus.unauthenticated)
            : _fromSession(session);
      case Failure<AuthSession?>(failure: final failure):
        state = failure is AuthExpiredFailure
            ? AuthState(status: AuthStatus.expired, failure: failure)
            : AuthState(status: AuthStatus.bootstrapFailure, failure: failure);
    }
  }

  Future<bool> signIn(String email, String password) =>
      _submitSession(() => _service.signIn(email, password));

  Future<bool> register(String email, String password, String displayName) =>
      _submitSession(() => _service.register(email, password, displayName));

  Future<bool> verifyOtp(String email, String code) =>
      _submitSession(() => _service.verifyOtp(email, code));

  Future<bool> resetPassword(
    String email,
    String verificationCode,
    String newPassword,
  ) => _submitSession(
    () => _service.resetPassword(email, verificationCode, newPassword),
  );

  Future<bool> completeOnboarding(String displayName) =>
      _submitSession(() => _service.completeOnboarding(displayName));

  Future<bool> refresh() => _submitSession(_service.refresh);

  Future<bool> requestRecovery(String email) async {
    if (state.isSubmitting) return false;
    state = state.copyWith(isSubmitting: true, clearFailure: true);
    final result = await _service.requestRecovery(email);
    switch (result) {
      case Success<void>():
        state = state.copyWith(isSubmitting: false, recoveryRequested: true);
        return true;
      case Failure<void>(failure: final failure):
        state = state.copyWith(isSubmitting: false, failure: failure);
        return false;
    }
  }

  Future<void> signOut({bool allDevices = false}) async {
    if (state.isSubmitting) return;
    state = state.copyWith(isSubmitting: true, clearFailure: true);
    final result = await _service.signOut(allDevices: allDevices);
    switch (result) {
      case Success<void>():
        state = const AuthState(status: AuthStatus.unauthenticated);
      case Failure<void>(failure: final failure):
        state = state.copyWith(isSubmitting: false, failure: failure);
    }
  }

  Future<bool> deleteAccount() async {
    if (state.isSubmitting) return false;
    state = state.copyWith(isSubmitting: true, clearFailure: true);
    final result = await _service.deleteAccount();
    switch (result) {
      case Success<void>():
        state = const AuthState(status: AuthStatus.unauthenticated);
        return true;
      case Failure<void>(failure: final failure):
        state = state.copyWith(isSubmitting: false, failure: failure);
        return false;
    }
  }

  void clearFeedback() =>
      state = state.copyWith(clearFailure: true, recoveryRequested: false);

  Future<bool> _submitSession(
    Future<Result<AuthSession>> Function() operation,
  ) async {
    if (state.isSubmitting) return false;
    state = state.copyWith(isSubmitting: true, clearFailure: true);
    final result = await operation();
    switch (result) {
      case Success<AuthSession>(value: final session):
        state = _fromSession(session);
        return true;
      case Failure<AuthSession>(failure: final failure):
        state = state.copyWith(isSubmitting: false, failure: failure);
        return false;
    }
  }

  AuthState _fromSession(AuthSession session) => AuthState(
    status: session.identity.hasCompletedOnboarding
        ? AuthStatus.authenticated
        : AuthStatus.onboardingRequired,
    session: session,
  );
}
