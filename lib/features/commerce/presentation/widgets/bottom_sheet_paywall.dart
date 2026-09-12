import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_platform/core/theme/app_spacing.dart';
import 'package:learning_platform/features/commerce/application/commerce_providers.dart';
import 'package:learning_platform/features/commerce/domain/commerce_product.dart';
import 'package:learning_platform/features/commerce/presentation/widgets/premium_badge.dart';

class BottomSheetPaywall extends ConsumerStatefulWidget {
  const BottomSheetPaywall({this.initialPlan, this.courseProduct, super.key});

  final SubscriptionPlan? initialPlan;
  final CourseProduct? courseProduct;

  static Future<bool?> show(
    BuildContext context, {
    SubscriptionPlan? initialPlan,
    CourseProduct? courseProduct,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => BottomSheetPaywall(
        initialPlan: initialPlan,
        courseProduct: courseProduct,
      ),
    );
  }

  @override
  ConsumerState<BottomSheetPaywall> createState() => _BottomSheetPaywallState();
}

class _BottomSheetPaywallState extends ConsumerState<BottomSheetPaywall> {
  SubscriptionPlan? _selectedPlan;
  final _couponController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedPlan = widget.initialPlan;
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
    final commerceState = ref.watch(commerceControllerProvider);
    final plans = commerceState.plans;

    final isCoursePurchase =
        widget.courseProduct != null && _selectedPlan == null;
    final activePlan =
        _selectedPlan ??
        (plans.isNotEmpty
            ? plans.firstWhere(
                (p) => p.isRecommended,
                orElse: () => plans.first,
              )
            : null);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.large),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.medium),
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                const PremiumBadge(),
                const SizedBox(width: AppSpacing.small),
                Expanded(
                  child: Text(
                    isCoursePurchase ? 'Unlock Course' : 'Choose Your Plan',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Close paywall',
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.small),
            Text(
              isCoursePurchase
                  ? widget.courseProduct!.title
                  : 'Get unlimited access to interactive lessons, quizzes, and certificates.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.medium),

            // Plan Selection Cards if not single course
            if (!isCoursePurchase && plans.isNotEmpty) ...[
              for (final plan in plans.take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.small),
                  child: InkWell(
                    onTap: () => setState(() => _selectedPlan = plan),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.medium),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: activePlan?.id == plan.id
                              ? colorScheme.primary
                              : colorScheme.outlineVariant,
                          width: activePlan?.id == plan.id ? 2 : 1,
                        ),
                        color: activePlan?.id == plan.id
                            ? colorScheme.primaryContainer.withValues(
                                alpha: 0.2,
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
                              activePlan?.id == plan.id
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              color: activePlan?.id == plan.id
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
                                          color: colorScheme.tertiaryContainer,
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
                                  ],
                                ),
                                if (plan.hasTrial)
                                  Text(
                                    '${plan.trialDays}-day free trial',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            plan.formattedPrice,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],

            // Coupon Code Field
            const SizedBox(height: AppSpacing.small),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _couponController,
                    decoration: InputDecoration(
                      hintText: 'Promo / Coupon code',
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
                                productId: isCoursePurchase
                                    ? widget.courseProduct!.id
                                    : activePlan?.id,
                              );
                        },
                  child: const Text('Apply'),
                ),
              ],
            ),

            if (commerceState.appliedCoupon != null) ...[
              const SizedBox(height: AppSpacing.xSmall),
              Text(
                '✓ Coupon applied: ${commerceState.appliedCoupon!.code} (${commerceState.appliedCoupon!.description ?? "Discount applied"})',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w600,
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

            // Main CTA Button
            SizedBox(
              height: AppSpacing.touchTarget,
              child: FilledButton(
                onPressed: commerceState.isBusy
                    ? null
                    : () async {
                        final navigator = Navigator.of(context);
                        final controller = ref.read(
                          commerceControllerProvider.notifier,
                        );
                        bool success = false;
                        if (isCoursePurchase) {
                          success = await controller.purchaseCourseProduct(
                            widget.courseProduct!,
                          );
                        } else if (activePlan != null) {
                          success = await controller.purchaseSubscriptionPlan(
                            activePlan,
                          );
                        }
                        if (mounted && success) {
                          navigator.pop(true);
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
                        isCoursePurchase
                            ? 'Buy Now · ${widget.courseProduct!.formattedPrice}'
                            : (activePlan?.hasTrial ?? false)
                            ? 'Start ${activePlan!.trialDays}-Day Free Trial'
                            : 'Subscribe Now · ${activePlan?.formattedPrice ?? ""}',
                      ),
              ),
            ),

            const SizedBox(height: AppSpacing.medium),

            // Store Compliance: Restore Purchases & Legal Disclaimers
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: commerceState.isBusy
                      ? null
                      : () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final navigator = Navigator.of(context);
                          final success = await ref
                              .read(commerceControllerProvider.notifier)
                              .restorePurchases();
                          if (mounted && success) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Purchases restored.'),
                              ),
                            );
                            navigator.pop(true);
                          }
                        },
                  child: const Text('Restore Purchases'),
                ),
              ],
            ),
            Text(
              'Subscriptions auto-renew unless cancelled at least 24 hours before the end of the current period. Manage your subscriptions in your App Store / Play Store account settings. By proceeding, you agree to our Terms of Use and Privacy Policy.',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
