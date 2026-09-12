import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_platform/core/routing/app_router.dart';
import 'package:learning_platform/core/theme/app_spacing.dart';

enum UpgradeCtaStyle { primary, tonal, outlined }

class UpgradeCtaButton extends StatelessWidget {
  const UpgradeCtaButton({
    this.label = 'Unlock with Pro',
    this.style = UpgradeCtaStyle.primary,
    this.onPressed,
    this.fullWidth = false,
    this.icon = Icons.auto_awesome,
    this.customPlanId,
    super.key,
  });

  final String label;
  final UpgradeCtaStyle style;
  final VoidCallback? onPressed;
  final bool fullWidth;
  final IconData icon;
  final String? customPlanId;

  @override
  Widget build(BuildContext context) {
    void handlePress() {
      if (onPressed != null) {
        onPressed!();
      } else {
        unawaited(context.push(AppRoutes.paywall));
      }
    }

    final button = switch (style) {
      UpgradeCtaStyle.primary => FilledButton.icon(
        onPressed: handlePress,
        icon: Icon(icon, size: 18),
        label: Text(label),
      ),
      UpgradeCtaStyle.tonal => FilledButton.tonalIcon(
        onPressed: handlePress,
        icon: Icon(icon, size: 18),
        label: Text(label),
      ),
      UpgradeCtaStyle.outlined => OutlinedButton.icon(
        onPressed: handlePress,
        icon: Icon(icon, size: 18),
        label: Text(label),
      ),
    };

    return SizedBox(
      height: AppSpacing.touchTarget,
      width: fullWidth ? double.infinity : null,
      child: button,
    );
  }
}
