import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_platform/core/routing/app_router.dart';
import 'package:learning_platform/core/theme/app_spacing.dart';
import 'package:learning_platform/features/entitlements/domain/access_decision.dart';
import 'package:learning_platform/features/entitlements/domain/access_reason.dart';
import 'package:learning_platform/features/entitlements/presentation/widgets/access_status_badge.dart';

/// Reusable gate / paywall component presented when a learner encounters locked or expired content.
class AccessGateView extends StatelessWidget {
  const AccessGateView({
    required this.decision,
    this.resourceTitle,
    this.onUnlock,
    this.onDismiss,
    super.key,
  });

  final AccessDecision decision;
  final String? resourceTitle;
  final VoidCallback? onUnlock;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final (
      title,
      message,
      primaryActionLabel,
      icon,
    ) = switch (decision.reason) {
      AccessReason.subscriptionExpired => (
        'Subscription Expired',
        'Your subscription has ended. Renew now to resume this course and keep your progress on track.',
        'Renew Subscription',
        Icons.timer_off_outlined,
      ),
      AccessReason.trialExpired => (
        'Free Trial Ended',
        'Your trial period has concluded. Upgrade to a subscription for unlimited access to all lessons, quizzes, and certificates.',
        'Subscribe to Continue',
        Icons.hourglass_bottom_outlined,
      ),
      AccessReason.timeLimitExpired => (
        'Access Window Expired',
        'The time-limited access window for this content has ended. Unlock perpetual or subscription access to continue.',
        'Unlock Full Access',
        Icons.alarm_off_outlined,
      ),
      AccessReason.revoked => (
        'Access Revoked',
        'Your access grant for this resource has been revoked. Contact support or purchase a plan.',
        'View Available Plans',
        Icons.block_outlined,
      ),
      _ => (
        'Premium Content Locked',
        'This lesson requires an active subscription or purchase to view video streams, exercises, and downloadable resources.',
        'Unlock with Subscription',
        Icons.lock_outline,
      ),
    };

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.large),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xLarge),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: colorScheme.primaryContainer,
                    child: Icon(icon, size: 36, color: colorScheme.primary),
                  ),
                  const SizedBox(height: AppSpacing.medium),
                  AccessStatusBadge(state: decision.state),
                  const SizedBox(height: AppSpacing.medium),
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (resourceTitle != null) ...[
                    const SizedBox(height: AppSpacing.xSmall),
                    Text(
                      resourceTitle!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.medium),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.large),
                  _buildBenefitRow(
                    context,
                    Icons.video_library_outlined,
                    'Full HD video streams & transcripts',
                  ),
                  const SizedBox(height: AppSpacing.small),
                  _buildBenefitRow(
                    context,
                    Icons.assignment_turned_in_outlined,
                    'Interactive quizzes, assignments & projects',
                  ),
                  const SizedBox(height: AppSpacing.small),
                  _buildBenefitRow(
                    context,
                    Icons.workspace_premium_outlined,
                    'Verified course completion certificates',
                  ),
                  const SizedBox(height: AppSpacing.xLarge),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed:
                          onUnlock ?? () => context.push(AppRoutes.paywall),
                      icon: const Icon(Icons.star_outline),
                      label: Text(primaryActionLabel),
                    ),
                  ),
                  if (onDismiss != null) ...[
                    const SizedBox(height: AppSpacing.small),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: TextButton(
                        onPressed: onDismiss,
                        child: const Text('Back to Course Outline'),
                      ),
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

  Widget _buildBenefitRow(BuildContext context, IconData icon, String text) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.secondary),
        const SizedBox(width: AppSpacing.small),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
