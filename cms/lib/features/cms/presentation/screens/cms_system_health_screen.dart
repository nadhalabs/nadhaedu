import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nadha_cms/core/theme/app_breakpoints.dart';
import 'package:nadha_cms/features/cms/application/cms_providers.dart';
import 'package:nadha_cms/features/cms/presentation/theme/cms_theme.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_badge.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_card.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_header.dart';

class CmsSystemHealthScreen extends ConsumerWidget {
  const CmsSystemHealthScreen({super.key, this.currentRoute});

  final String? currentRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(cmsDashboardControllerProvider);
    final route = currentRoute ?? _safeRoute(context, '/admin/system');
    final isMobile = MediaQuery.sizeOf(context).width < AppBreakpoints.medium;
    final readiness = dashboardState.data?.systemReadiness;

    return Scaffold(
      backgroundColor: CmsTheme.canvasColor,
      body: Column(
        children: [
          CmsHeader(
            currentRoute: route,
            title: 'System Health & Operational Diagnostics',
            subtitle:
                'Subsystem readiness, provider integration matrix, and security boundaries',
            showMenuButton: isMobile,
            onMenuTap: () => Scaffold.of(context).openDrawer(),
            actions: [
              IconButton(
                tooltip: 'Refresh Status',
                icon: const Icon(Icons.refresh, size: 18),
                color: CmsTheme.primaryAccent,
                onPressed: () =>
                    ref.read(cmsDashboardControllerProvider.notifier).refresh(),
              ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Core Infrastructure Cards Grid
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cols = constraints.maxWidth >= 900 ? 3 : 1;
                      return GridView.count(
                        crossAxisCount: cols,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 2.0,
                        children: [
                          _buildSubsystemCard(
                            title: 'Database Engine',
                            description:
                                'Relational storage & transactional ACID',
                            status: readiness?.database == 'connected'
                                ? 'Connected'
                                : 'Checking',
                            isHealthy: readiness?.database == 'connected',
                            icon: Icons.storage_outlined,
                            extra:
                                'Revision: ${readiness?.migrationRevision ?? "unknown"}',
                          ),
                          _buildSubsystemCard(
                            title: 'Distributed Cache & Rate Limiting',
                            description: 'Redis fixed-window rate limiter',
                            status: readiness?.cache == 'connected'
                                ? 'Active'
                                : 'Checking',
                            isHealthy: readiness?.cache == 'connected',
                            icon: Icons.memory,
                            extra: 'See System Readiness for live status',
                          ),
                          _buildSubsystemCard(
                            title: 'Media CDN & Token Origin',
                            description: 'HMAC-SHA256 URL token signing',
                            status: 'Operational',
                            isHealthy: true,
                            icon: Icons.shield_outlined,
                            extra: 'Expiring authorization tokens',
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Commerce & Subscriptions Integration Matrix
                  CmsCard(
                    title: 'External Provider Integration Matrix',
                    subtitle:
                        'Fail-closed security boundaries for live commerce and notification providers',
                    child: Column(
                      children: [
                        _buildProviderRow(
                          name: 'Apple App Store (StoreKit 2)',
                          category:
                              'In-App Purchases & Auto-Renewing Subscriptions',
                          mode: 'MOCK / FAIL-CLOSED',
                          modeType: CmsBadgeType.warning,
                          details:
                              'Production adapter fails closed until live App Store Connect private keys are configured.',
                        ),
                        const Divider(color: CmsTheme.borderColor, height: 24),
                        _buildProviderRow(
                          name: 'Google Play Billing',
                          category:
                              'Play Store Billing & RTDN Lifecycle Webhooks',
                          mode: 'MOCK / FAIL-CLOSED',
                          modeType: CmsBadgeType.warning,
                          details:
                              'Production adapter fails closed until Google Cloud Service Account JSON is supplied.',
                        ),
                        const Divider(color: CmsTheme.borderColor, height: 24),
                        _buildProviderRow(
                          name: 'Stripe Billing & Checkout',
                          category:
                              'Web Payment Intents & Subscription Invoicing',
                          mode: 'MOCK / FAIL-CLOSED',
                          modeType: CmsBadgeType.warning,
                          details:
                              'Production adapter fails closed until live Stripe API secret keys and webhook signature are configured.',
                        ),
                        const Divider(color: CmsTheme.borderColor, height: 24),
                        _buildProviderRow(
                          name: 'Apple Push Notification Service (APNs)',
                          category: 'iOS Native Push Delivery',
                          mode: 'NO-OP / DEFERRED',
                          modeType: CmsBadgeType.neutral,
                          details:
                              'Platform device push tokens registered securely; production push gateway deferred.',
                        ),
                        const Divider(color: CmsTheme.borderColor, height: 24),
                        _buildProviderRow(
                          name: 'Firebase Cloud Messaging (FCM)',
                          category: 'Android Native Push Delivery',
                          mode: 'NO-OP / DEFERRED',
                          modeType: CmsBadgeType.neutral,
                          details:
                              'Platform device push tokens registered securely; production push gateway deferred.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubsystemCard({
    required String title,
    required String description,
    required String status,
    required bool isHealthy,
    required IconData icon,
    required String extra,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CmsTheme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: CmsTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: CmsTheme.primaryAccent),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      color: CmsTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              CmsBadge(
                label: status.toUpperCase(),
                type: isHealthy ? CmsBadgeType.success : CmsBadgeType.warning,
              ),
            ],
          ),
          Text(
            description,
            style: const TextStyle(color: CmsTheme.textSecondary, fontSize: 12),
          ),
          Text(
            extra,
            style: const TextStyle(
              color: CmsTheme.textMuted,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderRow({
    required String name,
    required String category,
    required String mode,
    required CmsBadgeType modeType,
    required String details,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  color: CmsTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                category,
                style: const TextStyle(color: CmsTheme.textMuted, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        CmsBadge(label: mode, type: modeType),
        const SizedBox(width: 16),
        Expanded(
          flex: 6,
          child: Text(
            details,
            style: const TextStyle(
              color: CmsTheme.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

String _safeRoute(BuildContext context, String fallback) {
  try {
    return GoRouterState.of(context).uri.path;
  } on Object catch (_) {
    return fallback;
  }
}
