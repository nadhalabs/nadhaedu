import 'package:flutter/material.dart';

import 'package:learning_platform/core/errors/app_failure.dart';
import 'package:learning_platform/core/theme/app_spacing.dart';

class AuthFeedback extends StatelessWidget {
  const AuthFeedback({required this.failure, super.key});
  final AppFailure? failure;

  @override
  Widget build(BuildContext context) {
    if (failure == null) return const SizedBox.shrink();
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.medium),
        padding: const EdgeInsets.all(AppSpacing.medium),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          failure!.message,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
        ),
      ),
    );
  }
}
