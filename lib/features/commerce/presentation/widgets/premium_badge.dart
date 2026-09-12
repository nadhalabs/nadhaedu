import 'package:flutter/material.dart';
import 'package:learning_platform/core/theme/app_spacing.dart';
import 'package:learning_platform/features/commerce/domain/subscription.dart';

class PremiumBadge extends StatelessWidget {
  const PremiumBadge({
    this.tier = SubscriptionTier.pro,
    this.customLabel,
    this.compact = false,
    super.key,
  });

  final SubscriptionTier tier;
  final String? customLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final label =
        customLabel ??
        switch (tier) {
          SubscriptionTier.pro => 'PRO',
          SubscriptionTier.standard => 'PLUS',
          SubscriptionTier.student => 'STUDENT',
          SubscriptionTier.family => 'FAMILY',
          SubscriptionTier.institution => 'ENTERPRISE',
        };

    final (bgColor, fgColor) = switch (tier) {
      SubscriptionTier.pro => (
        colorScheme.primaryContainer,
        colorScheme.onPrimaryContainer,
      ),
      SubscriptionTier.standard => (
        colorScheme.secondaryContainer,
        colorScheme.onSecondaryContainer,
      ),
      SubscriptionTier.student => (
        colorScheme.tertiaryContainer,
        colorScheme.onTertiaryContainer,
      ),
      SubscriptionTier.family => (
        colorScheme.primary.withValues(alpha: 0.15),
        colorScheme.primary,
      ),
      SubscriptionTier.institution => (
        colorScheme.inverseSurface,
        colorScheme.onInverseSurface,
      ),
    };

    return Semantics(
      label: '$label membership badge',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? AppSpacing.small : AppSpacing.small + 2,
          vertical: compact ? 2 : AppSpacing.xSmall,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: fgColor.withValues(alpha: 0.25), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.stars_rounded, size: compact ? 12 : 14, color: fgColor),
            const SizedBox(width: AppSpacing.xSmall),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: fgColor,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                fontSize: compact ? 10 : 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
