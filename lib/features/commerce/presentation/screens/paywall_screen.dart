import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_platform/bootstrap/providers.dart';
import 'package:learning_platform/core/theme/app_spacing.dart';
import 'package:learning_platform/features/commerce/application/commerce_providers.dart';
import 'package:learning_platform/features/commerce/domain/commerce_analytics.dart';
import 'package:learning_platform/features/commerce/domain/commerce_product.dart';
import 'package:learning_platform/features/commerce/domain/subscription.dart';
import 'package:learning_platform/features/commerce/presentation/widgets/premium_badge.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({this.source = 'direct', super.key});

  final String source;

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  SubscriptionPlan? _selectedPlan;
  final _couponController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        ref
            .read(commerceAnalyticsTrackerProvider)
            .logEvent(
              PaywallViewedEvent(
                placement: 'full_screen_paywall',
                source: widget.source,
              ),
            ),
      );
    });
  }

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final branding = ref.watch(brandingConfigProvider);
    final commerceState = ref.watch(commerceControllerProvider);
    final plans = commerceState.plans;

    final selectedPlan =
        _selectedPlan ??
        (plans.isNotEmpty
            ? plans.firstWhere(
                (p) => p.billingInterval == BillingInterval.annual,
                orElse: () => plans.first,
              )
            : null);

    return Scaffold(
      appBar: AppBar(
        title: Text('${branding.displayName} Pro'),
        actions: [
          TextButton(
            onPressed: commerceState.isBusy
                ? null
                : () async {
                    final success = await ref
                        .read(commerceControllerProvider.notifier)
                        .restorePurchases();
                    if (context.mounted && success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Purchases successfully restored.'),
                        ),
                      );
                      await Navigator.of(context).maybePop();
                    }
                  },
            child: const Text('Restore'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.large),
            children: [
              // Hero Section
              Center(
                child: Column(
                  children: [
                    const PremiumBadge(tier: SubscriptionTier.pro),
                    const SizedBox(height: AppSpacing.medium),
                    Semantics(
                      header: true,
                      child: Text(
                        'Unlock Your Full Learning Potential',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.small),
                    Text(
                      'Accelerate your career with comprehensive courses, accredited certificates, and interactive code sandboxes.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.large),

              // Value Highlights
              Card(
                elevation: 0,
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.4,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.medium),
                  child: Column(
                    children: const [
                      _BenefitItem(
                        icon: Icons.all_inclusive,
                        title: 'Unlimited Course Catalog Access',
                        subtitle:
                            'Full access to 500+ top-rated courses and workshops.',
                      ),
                      Divider(height: AppSpacing.medium),
                      _BenefitItem(
                        icon: Icons.verified_outlined,
                        title: 'Official Verified Certificates',
                        subtitle:
                            'Shareable credentials for your portfolio & LinkedIn.',
                      ),
                      Divider(height: AppSpacing.medium),
                      _BenefitItem(
                        icon: Icons.offline_bolt_outlined,
                        title: 'Interactive Assessments & Quizzes',
                        subtitle:
                            'Hands-on practice exercises graded with instant feedback.',
                      ),
                      Divider(height: AppSpacing.medium),
                      _BenefitItem(
                        icon: Icons.download_outlined,
                        title: 'Offline Video Downloads',
                        subtitle:
                            'Learn on your commute without consuming mobile data.',
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.large),

              // Plans Selector
              Text(
                'Select a Membership Plan',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.small),

              if (plans.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.large),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                ...plans.map((plan) {
                  final isSelected = selectedPlan?.id == plan.id;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.small),
                    child: InkWell(
                      onTap: () => setState(() => _selectedPlan = plan),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.medium),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.outlineVariant,
                            width: isSelected ? 2.5 : 1,
                          ),
                          color: isSelected
                              ? colorScheme.primaryContainer.withValues(
                                  alpha: 0.15,
                                )
                              : null,
                        ),
                        child: Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                right: AppSpacing.small,
                              ),
                              child: Icon(
                                isSelected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked,
                                color: isSelected
                                    ? colorScheme.primary
                                    : colorScheme.outlineVariant,
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        plan.name,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      if (plan.hasSavings) ...[
                                        const SizedBox(width: AppSpacing.small),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: AppSpacing.small,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                colorScheme.tertiaryContainer,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            'SAVE ${plan.savingsPercent}%',
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                                  color: colorScheme
                                                      .onTertiaryContainer,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                        ),
                                      ],
                                      if (plan.isPopular) ...[
                                        const SizedBox(
                                          width: AppSpacing.xSmall,
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: AppSpacing.small,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: colorScheme.primaryContainer,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            'POPULAR',
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                                  color: colorScheme
                                                      .onPrimaryContainer,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    plan.description,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  if (plan.hasTrial) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '✓ Includes ${plan.trialDays}-day free trial',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: colorScheme.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  plan.formattedPrice,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  plan.billingInterval.billingPeriodLabel,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

              const SizedBox(height: AppSpacing.medium),

              // Coupon / Promo Code
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _couponController,
                      decoration: InputDecoration(
                        hintText: 'Promo code',
                        isDense: true,
                        border: const OutlineInputBorder(),
                        suffixIcon: commerceState.appliedCoupon != null
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _couponController.clear();
                                  ref
                                      .read(commerceControllerProvider.notifier)
                                      .removeCoupon();
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.small),
                  FilledButton.tonal(
                    onPressed: commerceState.isBusy
                        ? null
                        : () async {
                            await ref
                                .read(commerceControllerProvider.notifier)
                                .applyCoupon(
                                  _couponController.text,
                                  productId: selectedPlan?.id,
                                );
                          },
                    child: const Text('Apply'),
                  ),
                ],
              ),

              if (commerceState.appliedCoupon != null) ...[
                const SizedBox(height: AppSpacing.xSmall),
                Text(
                  '✓ Promo applied: ${commerceState.appliedCoupon!.code}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],

              if (commerceState.failure != null) ...[
                const SizedBox(height: AppSpacing.small),
                Text(
                  commerceState.failure!.message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.error,
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.large),

              // Main Subscribe Button
              SizedBox(
                height: AppSpacing.touchTarget,
                child: FilledButton(
                  onPressed: commerceState.isBusy || selectedPlan == null
                      ? null
                      : () async {
                          final success = await ref
                              .read(commerceControllerProvider.notifier)
                              .purchaseSubscriptionPlan(selectedPlan);
                          if (context.mounted && success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Pro Subscription activated! Enjoy full access.',
                                ),
                              ),
                            );
                            await Navigator.of(context).maybePop();
                          }
                        },
                  child: commerceState.isProcessingPurchase
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          (selectedPlan?.hasTrial ?? false)
                              ? 'Start ${selectedPlan!.trialDays}-Day Free Trial'
                              : 'Subscribe Now · ${selectedPlan?.formattedPrice ?? ""}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),

              const SizedBox(height: AppSpacing.large),

              // Store Compliance Disclaimers
              Text(
                'Subscriptions automatically renew unless auto-renew is turned off at least 24 hours before the end of the current billing period. Account will be charged for renewal within 24 hours prior to the end of the current period. You can manage and cancel your subscriptions in your account settings after purchase.',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.small),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () {},
                    child: const Text('Terms of Use (EULA)'),
                  ),
                  const Text('·'),
                  TextButton(
                    onPressed: () {},
                    child: const Text('Privacy Policy'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BenefitItem extends StatelessWidget {
  const _BenefitItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: colorScheme.primaryContainer,
          child: Icon(icon, size: 20, color: colorScheme.primary),
        ),
        const SizedBox(width: AppSpacing.medium),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
