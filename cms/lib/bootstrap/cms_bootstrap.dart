import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nadha_cms/bootstrap/cms_app.dart';
import 'package:nadha_cms/bootstrap/cms_providers.dart';
import 'package:nadha_cms/config/app_config.dart';
import 'package:nadha_cms/config/app_environment.dart';
import 'package:nadha_cms/features/authentication/data/auth_session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> bootstrapCms({required AppEnvironment environment}) async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  final config = AppConfig.fromEnvironment(environment);
  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        authSessionStoreProvider.overrideWithValue(
          CmsWebAuthSessionStore(preferences),
        ),
      ],
      child: const CmsApp(),
    ),
  );
}
