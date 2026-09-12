import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nadha_cms/config/app_config.dart';
import 'package:nadha_cms/core/networking/api_client.dart';
import 'package:nadha_cms/features/authentication/data/auth_session_store.dart';

final appConfigProvider = Provider<AppConfig>(
  (ref) => throw StateError('AppConfig must be initialized by CMS bootstrap.'),
);

final authSessionStoreProvider = Provider<AuthSessionStore>(
  (ref) => throw StateError(
    'AuthSessionStore must be initialized by CMS bootstrap.',
  ),
);

final sessionExpirationProvider = StateProvider<int>((ref) => 0);

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = DioApiClient(
    baseUri: ref.watch(appConfigProvider).apiBaseUri,
    sessionStore: ref.watch(authSessionStoreProvider),
    onSessionExpired: () =>
        ref.read(sessionExpirationProvider.notifier).state++,
  );
  ref.onDispose(client.close);
  return client;
});
