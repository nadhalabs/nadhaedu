import 'package:flutter/material.dart';
import 'package:learning_platform/core/theme/app_tokens.dart';
import 'package:learning_platform/features/entitlements/domain/access_decision.dart';

/// Reusable, accessible visual indicator representing the 8 freemium access states:
/// free, preview, locked, included, purchased, subscribed, expired, unavailable.
class AccessStatusBadge extends StatelessWidget {
  const AccessStatusBadge({
    required this.state,
    this.showIcon = true,
    this.compact = false,
    super.key,
  });

  final AccessState state;
  final bool showIcon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final (label, icon, bg, fg, border) = switch (state) {
      AccessState.free => (
        'Free',
        Icons.lock_open_outlined,
        AppPalette.softSurface(context, AppPalette.sunshine),
        colorScheme.onSurface,
        null,
      ),
      AccessState.preview => (
        'Preview',
        Icons.visibility_outlined,
        colorScheme.primaryContainer.withValues(alpha: 0.6),
        colorScheme.onPrimaryContainer,
        null,
      ),
      AccessState.locked => (
        'Locked',
        Icons.lock_outline,
        colorScheme.surfaceContainerHighest,
        colorScheme.onSurfaceVariant,
        colorScheme.outlineVariant,
      ),
      AccessState.included => (
        'Included',
        Icons.check_circle_outline,
        colorScheme.secondaryContainer.withValues(alpha: 0.7),
        colorScheme.onSecondaryContainer,
        null,
      ),
      AccessState.purchased => (
        'Purchased',
        Icons.verified_outlined,
        colorScheme.primaryContainer,
        colorScheme.onPrimaryContainer,
        null,
      ),
      AccessState.subscribed => (
        'Subscribed',
        Icons.star_outline,
        colorScheme.primary.withValues(alpha: 0.15),
        colorScheme.primary,
        colorScheme.primary.withValues(alpha: 0.4),
      ),
      AccessState.expired => (
        'Expired',
        Icons.timer_off_outlined,
        colorScheme.errorContainer.withValues(alpha: 0.6),
        colorScheme.onErrorContainer,
        null,
      ),
      AccessState.unavailable => (
        'Unavailable',
        Icons.block_outlined,
        colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        colorScheme.outline,
        colorScheme.outlineVariant,
      ),
    };

    final padding = compact
        ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
        : const EdgeInsets.symmetric(horizontal: 10, vertical: 4);

    final textStyle = compact
        ? theme.textTheme.labelSmall?.copyWith(
            color: fg,
            fontWeight: FontWeight.bold,
          )
        : theme.textTheme.labelMedium?.copyWith(
            color: fg,
            fontWeight: FontWeight.bold,
          );

    return Semantics(
      label: 'Access status: $label',
      excludeSemantics: true,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: border != null ? Border.all(color: border) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showIcon) ...[
              Icon(icon, size: compact ? 12 : 14, color: fg),
              SizedBox(width: compact ? 4 : 6),
            ],
            Text(label, style: textStyle),
          ],
        ),
      ),
    );
  }
}
