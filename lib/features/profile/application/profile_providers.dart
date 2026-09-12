import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_platform/bootstrap/providers.dart';
import 'package:learning_platform/config/app_environment.dart';
import 'package:learning_platform/features/notifications/application/notification_providers.dart';
import 'package:learning_platform/features/profile/application/account_security_controller.dart';
import 'package:learning_platform/features/profile/application/profile_controller.dart';
import 'package:learning_platform/features/profile/application/session_management_controller.dart';
import 'package:learning_platform/features/profile/data/foundation_profile_data_source.dart';
import 'package:learning_platform/features/profile/data/profile_data_source.dart';
import 'package:learning_platform/features/profile/data/profile_repository_impl.dart';
import 'package:learning_platform/features/profile/data/remote_profile_data_source.dart';
import 'package:learning_platform/features/profile/domain/profile_repository.dart';

final profileDataSourceProvider = Provider<ProfileDataSource>((ref) {
  return switch (ref.watch(appConfigProvider).environment) {
    AppEnvironment.development => FoundationProfileDataSource(),
    AppEnvironment.staging || AppEnvironment.production =>
      RemoteProfileDataSource(ref.watch(apiClientProvider)),
  };
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final dataSource = ref.watch(profileDataSourceProvider);
  return ProfileRepositoryImpl(dataSource);
});

final profileControllerProvider =
    StateNotifierProvider<ProfileController, ProfileState>((ref) {
      final repository = ref.watch(profileRepositoryProvider);
      final analytics = ref.watch(platformAnalyticsProvider);
      return ProfileController(repository, analytics: analytics);
    });

final sessionManagementControllerProvider =
    StateNotifierProvider<SessionManagementController, SessionManagementState>((
      ref,
    ) {
      final repository = ref.watch(profileRepositoryProvider);
      final analytics = ref.watch(platformAnalyticsProvider);
      return SessionManagementController(repository, analytics: analytics);
    });

final accountSecurityControllerProvider =
    StateNotifierProvider<AccountSecurityController, AccountSecurityState>((
      ref,
    ) {
      final repository = ref.watch(profileRepositoryProvider);
      final analytics = ref.watch(platformAnalyticsProvider);
      return AccountSecurityController(repository, analytics: analytics);
    });
