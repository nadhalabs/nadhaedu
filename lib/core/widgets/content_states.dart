import 'package:flutter/material.dart';
import 'package:learning_platform/core/motion/app_motion.dart';
import 'package:learning_platform/core/theme/app_spacing.dart';
import 'package:learning_platform/core/widgets/learning_feedback.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({this.label = 'Loading', super.key});
  final String label;

  @override
  Widget build(BuildContext context) => Center(
    child: Semantics(
      label: label,
      liveRegion: true,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.large),
          child: LearningEntrance(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const LearningEmblem(size: 72),
                const SizedBox(height: AppSpacing.medium),
                Text(label, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.medium),
                SizedBox(
                  width: 220,
                  child: AppMotion.reduced(context)
                      ? const LinearProgressIndicator(value: 0.4)
                      : const LinearProgressIndicator(),
                ),
                const SizedBox(height: AppSpacing.small),
                Text(
                  'Getting things ready for you.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class MessageView extends StatelessWidget {
  const MessageView({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.large),
          child: Semantics(
            container: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  child: Icon(
                    icon,
                    size: 40,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: AppSpacing.medium),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.small),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: AppSpacing.large),
                  ElevatedButton(
                    onPressed: onAction,
                    child: Text(actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class ErrorView extends MessageView {
  const ErrorView({super.onAction, super.key})
    : super(
        icon: Icons.error_outline,
        title: 'Let’s try that again',
        message: 'We couldn’t load this just now. Your learning is still here.',
        actionLabel: onAction == null ? null : 'Retry',
      );
}

class EmptyView extends MessageView {
  const EmptyView({super.key})
    : super(
        icon: Icons.inbox_outlined,
        title: 'Nothing here yet',
        message: 'Explore a course to start your next discovery.',
      );
}

class OfflineView extends MessageView {
  const OfflineView({super.onAction, super.key})
    : super(
        icon: Icons.cloud_off_outlined,
        title: 'You are offline',
        message:
            'Your saved lessons are waiting in Downloads. Reconnect to discover more.',
        actionLabel: onAction == null ? null : 'Try again',
      );
}
