import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nadha_cms/bootstrap/cms_providers.dart';
import 'package:nadha_cms/features/authentication/application/auth_controller.dart';
import 'package:nadha_cms/features/authentication/application/auth_service.dart';
import 'package:nadha_cms/features/authentication/application/auth_state.dart';
import 'package:nadha_cms/features/authentication/data/auth_remote_data_source.dart';
import 'package:nadha_cms/features/authentication/data/auth_repository_impl.dart';
import 'package:nadha_cms/features/authentication/data/backend_auth_data_source.dart';
import 'package:nadha_cms/features/authentication/domain/auth_capabilities.dart';
import 'package:nadha_cms/features/authentication/domain/auth_repository.dart';

final authCapabilitiesProvider = Provider<AuthCapabilities>(
  (ref) => AuthCapabilities.foundation,
);
final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>(
  (ref) => BackendAuthDataSource(ref.watch(apiClientProvider)),
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
