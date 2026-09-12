import 'package:flutter/foundation.dart';

@immutable
final class BrandingConfig {
  const BrandingConfig({required this.displayName});

  static const temporary = BrandingConfig(displayName: 'Nadha Edu');

  final String displayName;

  String get wordmark => displayName.toUpperCase();
}
