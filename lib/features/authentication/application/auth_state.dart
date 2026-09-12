import 'package:learning_platform/core/errors/app_failure.dart';
import 'package:learning_platform/features/authentication/domain/auth_session.dart';

enum AuthStatus {
  bootstrapping,
  unauthenticated,
  onboardingRequired,
  authenticated,
  expired,
  bootstrapFailure,
}

final class AuthState {
  const AuthState({
    required this.status,
    this.session,
    this.failure,
    this.isSubmitting = false,
    this.recoveryRequested = false,
  });

  const AuthState.bootstrapping() : this(status: AuthStatus.bootstrapping);

  final AuthStatus status;
  final AuthSession? session;
  final AppFailure? failure;
  final bool isSubmitting;
  final bool recoveryRequested;

  AuthState copyWith({
    AuthStatus? status,
    AuthSession? session,
    AppFailure? failure,
    bool clearFailure = false,
    bool? isSubmitting,
    bool? recoveryRequested,
  }) => AuthState(
    status: status ?? this.status,
    session: session ?? this.session,
    failure: clearFailure ? null : failure ?? this.failure,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    recoveryRequested: recoveryRequested ?? this.recoveryRequested,
  );
}
