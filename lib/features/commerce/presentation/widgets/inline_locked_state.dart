import 'package:flutter/material.dart';
import 'package:learning_platform/core/theme/app_spacing.dart';
import 'package:learning_platform/features/commerce/presentation/widgets/upgrade_cta_button.dart';

class InlineLockedState extends StatelessWidget {
  const InlineLockedState({
    this.title = 'Premium Content',
    this.description =
        'This content is available to active subscribers or learners who purchased this course.',
    this.ctaLabel = 'Unlock Access',
    this.onUnlock,
    this.compact = false,
    super.key,
  });

  final String title;
  final String description;
  final String ctaLabel;
  final VoidCallback? onUnlock;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (compact) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.small),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.lock_outline, size: 16, color: colorScheme.secondary),
            const SizedBox(width: AppSpacing.small),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: onUnlock,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.small,
                ),
                minimumSize: const Size(0, 32),
              ),
              child: Text(ctaLabel),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.medium),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: colorScheme.primaryContainer,
                child: Icon(
                  Icons.lock_outline,
                  size: 18,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.small),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.small),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.medium),
          UpgradeCtaButton(
            label: ctaLabel,
            onPressed: onUnlock,
            style: UpgradeCtaStyle.primary,
          ),
        ],
      ),
    );
  }
}
