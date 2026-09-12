import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:learning_platform/core/routing/app_router.dart';
import 'package:learning_platform/core/widgets/content_states.dart';
import 'package:learning_platform/features/authentication/application/auth_providers.dart';

class SessionExpiredScreen extends ConsumerWidget {
  const SessionExpiredScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: MessageView(
      icon: Icons.lock_clock_outlined,
      title: 'Your session expired',
      message: 'Sign in again to continue securely.',
      actionLabel: 'Go to sign in',
      onAction: () {
        ref.read(authControllerProvider.notifier).clearFeedback();
        context.go(AppRoutes.login);
      },
    ),
  );
}
