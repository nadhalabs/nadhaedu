import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:learning_platform/bootstrap/providers.dart';
import 'package:learning_platform/core/widgets/content_states.dart';
import 'package:learning_platform/features/authentication/application/auth_providers.dart';
import 'package:learning_platform/features/authentication/application/auth_state.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authControllerProvider);
    if (state.status == AuthStatus.bootstrapFailure) {
      return Scaffold(
        body: ErrorView(
          onAction: ref.read(authControllerProvider.notifier).bootstrap,
        ),
      );
    }
    final name = ref.watch(brandingConfigProvider).displayName;
    return Scaffold(body: LoadingView(label: 'Loading $name'));
  }
}
