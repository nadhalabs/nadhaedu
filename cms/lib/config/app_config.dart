import 'package:flutter/foundation.dart';

import 'package:nadha_cms/config/app_environment.dart';

@immutable
final class AppConfig {
  const AppConfig({
    required this.environment,
    required this.apiBaseUri,
    required this.enableDiagnostics,
  });

  factory AppConfig.fromEnvironment(AppEnvironment environment) {
    const configuredBaseUrl = String.fromEnvironment('API_BASE_URL');
    if (configuredBaseUrl.isEmpty &&
        environment != AppEnvironment.development) {
      throw const FormatException(
        'API_BASE_URL is required for staging and production builds.',
      );
    }
    final defaultBaseUrl = switch (environment) {
      AppEnvironment.development => 'http://localhost:8000',
      AppEnvironment.staging || AppEnvironment.production => '',
    };
    final uri = Uri.parse(
      configuredBaseUrl.isEmpty ? defaultBaseUrl : configuredBaseUrl,
    );
    final requiresHttps = environment != AppEnvironment.development;
    if ((requiresHttps && !uri.isScheme('https')) ||
        (!requiresHttps && !uri.isScheme('http') && !uri.isScheme('https')) ||
        uri.host.isEmpty) {
      throw const FormatException(
        'API_BASE_URL must be an absolute URL (HTTPS in staging/production).',
      );
    }
    return AppConfig(
      environment: environment,
      apiBaseUri: uri,
      enableDiagnostics: environment != AppEnvironment.production,
    );
  }

  final AppEnvironment environment;
  final Uri apiBaseUri;
  final bool enableDiagnostics;
}
