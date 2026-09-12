import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nadha_cms/features/cms/presentation/theme/cms_theme.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_card.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_header.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_state_views.dart';
import 'package:nadha_cms/features/operations/application/cms_operations_providers.dart';
import 'package:nadha_cms/features/operations/presentation/cms_operation_widgets.dart';

class CmsCommerceScreen extends ConsumerStatefulWidget {
  const CmsCommerceScreen({super.key});
  @override
  ConsumerState<CmsCommerceScreen> createState() => _State();
}

class _State extends ConsumerState<CmsCommerceScreen> {
  final learner = TextEditingController();
  String provider = '';
  int limit = 50;

  CmsOperationsRequest get request =>
      CmsOperationsRequest('/api/v1/admin/commerce', {
        if (learner.text.trim().isNotEmpty) 'learnerId': learner.text.trim(),
        if (provider.isNotEmpty) 'provider': provider,
        'limit': limit,
      });

  @override
  void dispose() {
    learner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = request;
    final state = ref.watch(cmsOperationsQueryProvider(current));
    return Column(
      children: [
        const CmsHeader(
          currentRoute: '/admin/commerce',
          title: 'Commerce Operations',
          subtitle: 'Provider-authoritative and internal commerce evidence.',
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              OperationFilters(
                children: [
                  OperationField(
                    controller: learner,
                    label: 'Learner ID',
                    onSubmitted: (_) => setState(() {}),
                  ),
                  OperationSelect(
                    value: provider,
                    label: 'Provider',
                    values: const [
                      '',
                      'appleAppStore',
                      'googlePlay',
                      'stripe',
                      'mock',
                    ],
                    onChanged: (value) =>
                        setState(() => provider = value ?? ''),
                  ),
                  OperationSelect(
                    value: '$limit',
                    label: 'Records per section',
                    values: const ['25', '50', '100'],
                    onChanged: (value) =>
                        setState(() => limit = int.parse(value ?? '50')),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.filter_alt),
                    label: const Text('Apply'),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      learner.clear();
                      provider = '';
                      limit = 50;
                    }),
                    child: const Text('Clear filters'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              state.when(
                loading: () =>
                    const CmsLoadingView(message: 'Loading commerce evidence…'),
                error: (error, _) => CmsErrorView(
                  message: 'Unable to load this view. Please try again.',
                  onRetry: () =>
                      ref.invalidate(cmsOperationsQueryProvider(current)),
                ),
                data: (data) => Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: CmsTheme.warningBg,
                        border: Border.all(color: CmsTheme.warningColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${data['providerOperationsMessage']}',
                        style: const TextStyle(color: CmsTheme.warningText),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _section('Purchases', operationItems(data, 'purchases')),
                    const SizedBox(height: 16),
                    _section(
                      'Subscriptions',
                      operationItems(data, 'subscriptions'),
                    ),
                    const SizedBox(height: 16),
                    _section('Plans', operationItems(data, 'plans')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _section(String title, List<Map<String, Object?>> items) => CmsCard(
    title: '$title (${items.length})',
    child: Column(
      children: [
        if (items.isEmpty)
          CmsEmptyView(title: 'No ${title.toLowerCase()} match these filters')
        else
          for (final item in items)
            OperationRecord(
              item: item,
              actions: item.containsKey('authority')
                  ? [
                      Chip(
                        label: Text(operationLabel('${item['authority']}')),
                        backgroundColor: item['authority'] == 'providerVerified'
                            ? CmsTheme.successBg
                            : item['authority'] == 'pendingUnverified'
                            ? CmsTheme.warningBg
                            : CmsTheme.cardColor,
                      ),
                    ]
                  : const [],
            ),
      ],
    ),
  );
}
