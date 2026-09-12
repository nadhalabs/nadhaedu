import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_platform/core/routing/app_router.dart';
import 'package:learning_platform/core/theme/app_spacing.dart';
import 'package:learning_platform/features/commerce/application/commerce_providers.dart';
import 'package:learning_platform/features/commerce/domain/commerce_product.dart';
import 'package:learning_platform/features/commerce/domain/platform_billing_service.dart';
import 'package:learning_platform/features/commerce/presentation/widgets/premium_badge.dart';

class SubscriptionManagementScreen extends ConsumerWidget {
  const SubscriptionManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final commerceState = ref.watch(commerceControllerProvider);
    final activeSub = commerceState.activeSubscription;
    final plans = commerceState.plans;

    final currentPlan = activeSub != null
        ? plans.cast<SubscriptionPlan?>().firstWhere(
            (p) => p?.id == activeSub.planId,
            orElse: () => null,
          )
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Subscription'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: 'Restore purchases',
            onPressed: () => ref
                .read(commerceControllerProvider.notifier)
                .restorePurchases(),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.large),
            children: [
              if (activeSub != null && activeSub.requiresAttention) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.medium),
                  margin: const EdgeInsets.only(bottom: AppSpacing.large),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colorScheme.error),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: colorScheme.error,
                      ),
                      const SizedBox(width: AppSpacing.medium),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activeSub.isInGracePeriod
                                  ? 'Grace Period Notice'
                                  : 'Billing Retry in Progress',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: colorScheme.onErrorContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Your recent payment could not be processed. Please update your payment method to avoid losing access.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onErrorContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Current Status Card
              Card(
                elevation: 0,
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.large),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            currentPlan?.name ?? 'Membership',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (activeSub != null)
                            PremiumBadge(tier: activeSub.tier)
                          else
                            const Chip(label: Text('Free Tier')),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.small),
                      if (activeSub != null) ...[
                        Text(
                          'Status: ${activeSub.status.displayName}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: activeSub.isUsable
                                ? Colors.green.shade700
                                : colorScheme.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.small),
                        if (activeSub.isTrialing &&
                            activeSub.trialPeriod != null) ...[
                          Text(
                            'Trial ends: ${_formatDate(activeSub.trialPeriod!.endDate)} (${activeSub.trialPeriod!.remainingDays(DateTime.now())} days left)',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ] else if (activeSub.renewsAt != null &&
                            !activeSub.cancelAtPeriodEnd) ...[
                          Text(
                            'Next renewal date: ${_formatDate(activeSub.renewsAt!)}',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ] else if (activeSub.cancelAtPeriodEnd) ...[
                          Text(
                            'Expires on: ${_formatDate(activeSub.currentPeriodEnd)}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.error,
                            ),
                          ),
                        ],
                      ] else ...[
                        const Text(
                          'You do not currently have an active subscription.',
                        ),
                        const SizedBox(height: AppSpacing.medium),
                        FilledButton(
                          onPressed: () => context.push(AppRoutes.paywall),
                          child: const Text('View Available Plans'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              if (activeSub != null && activeSub.isUsable) ...[
                const SizedBox(height: AppSpacing.large),
                Text(
                  'Change Subscription Plan',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.small),
                for (final plan in plans.where((p) => p.id != activeSub.planId))
                  Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.small),
                    child: ListTile(
                      title: Text(plan.name),
                      subtitle: Text(
                        '${plan.formattedPrice} ${plan.billingInterval.billingPeriodLabel}',
                      ),
                      trailing: FilledButton.tonal(
                        onPressed: commerceState.isBusy
                            ? null
                            : () async {
                                final confirmed = await _confirmPlanChange(
                                  context,
                                  fromPlan: currentPlan?.name ?? 'Current Plan',
                                  toPlan: plan.name,
                                );
                                if (confirmed == true) {
                                  await ref
                                      .read(commerceControllerProvider.notifier)
                                      .changeSubscriptionPlan(
                                        newPlanId: plan.id,
                                        prorationMode: ProrationMode
                                            .immediateWithTimeProration,
                                      );
                                }
                              },
                        child: const Text('Switch Plan'),
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.large),

                // Native store management & cancellation
                OutlinedButton.icon(
                  onPressed: () => ref
                      .read(commerceControllerProvider.notifier)
                      .openPlatformSubscriptionManagement(),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Manage in App Store / Play Store'),
                ),
                const SizedBox(height: AppSpacing.small),

                if (!activeSub.cancelAtPeriodEnd) ...[
                  TextButton(
                    onPressed: commerceState.isBusy
                        ? null
                        : () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Cancel Subscription?'),
                                content: const Text(
                                  'Your access will continue until the end of your current billing period. No further charges will be made.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(false),
                                    child: const Text('Keep Subscription'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(true),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: colorScheme.error,
                                    ),
                                    child: const Text('Confirm Cancel'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true) {
                              await ref
                                  .read(commerceControllerProvider.notifier)
                                  .cancelSubscription();
                            }
                          },
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.error,
                    ),
                    child: const Text('Cancel Subscription'),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<bool?> _confirmPlanChange(
    BuildContext context, {
    required String fromPlan,
    required String toPlan,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Subscription Plan'),
        content: Text(
          'Do you want to switch from $fromPlan to $toPlan? Any remaining credit on your current billing cycle will be applied immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm Switch'),
          ),
        ],
      ),
    );
  }
}
