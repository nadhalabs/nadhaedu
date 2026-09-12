import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:learning_platform/bootstrap/providers.dart';
import 'package:learning_platform/config/app_environment.dart';
import 'package:learning_platform/features/authentication/application/auth_controller.dart';
import 'package:learning_platform/features/authentication/application/auth_service.dart';
import 'package:learning_platform/features/authentication/application/auth_state.dart';
import 'package:learning_platform/features/authentication/data/auth_remote_data_source.dart';
import 'package:learning_platform/features/authentication/data/auth_repository_impl.dart';
import 'package:learning_platform/features/authentication/data/backend_auth_data_source.dart';
import 'package:learning_platform/features/authentication/data/foundation_auth_data_source.dart';
import 'package:learning_platform/features/authentication/domain/auth_capabilities.dart';
import 'package:learning_platform/features/authentication/domain/auth_repository.dart';

final authCapabilitiesProvider = Provider<AuthCapabilities>(
  (ref) =>
      ref.watch(appConfigProvider).environment == AppEnvironment.development
      ? AuthCapabilities.foundation
      : const AuthCapabilities(
          registration: true,
          passwordRecovery: true,
          otp: false,
        ),
);
final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>(
  (ref) => switch (ref.watch(appConfigProvider).environment) {
    AppEnvironment.development => FoundationAuthDataSource(),
    AppEnvironment.staging || AppEnvironment.production =>
      BackendAuthDataSource(ref.watch(apiClientProvider)),
  },
);
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(
    remote: ref.watch(authRemoteDataSourceProvider),
    sessionStore: ref.watch(authSessionStoreProvider),
  ),
);
final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(ref.watch(authRepositoryProvider)),
);
final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) {
    final controller = AuthController(ref.watch(authServiceProvider));
    ref.listen(sessionExpirationProvider, (_, _) => controller.expireSession());
    unawaited(controller.bootstrap());
    return controller;
  },
);
