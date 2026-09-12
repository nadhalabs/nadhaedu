import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_card.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_header.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_state_views.dart';
import 'package:nadha_cms/features/operations/application/cms_operations_providers.dart';
import 'package:nadha_cms/features/operations/presentation/cms_operation_widgets.dart';

class CmsAuditLogsScreen extends ConsumerStatefulWidget {
  const CmsAuditLogsScreen({super.key, this.currentRoute});
  final String? currentRoute;
  @override
  ConsumerState<CmsAuditLogsScreen> createState() => _State();
}

class _State extends ConsumerState<CmsAuditLogsScreen> {
  final actor = TextEditingController();
  final action = TextEditingController();
  final targetType = TextEditingController();
  final targetId = TextEditingController();
  final dateFrom = TextEditingController();
  final dateTo = TextEditingController();
  String actorRole = '';
  String result = '';
  int page = 1;
  static const pageSize = 20;

  CmsOperationsRequest get request =>
      CmsOperationsRequest('/api/v1/admin/audit-logs', {
        if (actor.text.trim().isNotEmpty) 'actorId': actor.text.trim(),
        if (action.text.trim().isNotEmpty) 'eventType': action.text.trim(),
        if (targetType.text.trim().isNotEmpty)
          'subjectType': targetType.text.trim(),
        if (targetId.text.trim().isNotEmpty) 'subjectId': targetId.text.trim(),
        if (actorRole.isNotEmpty) 'actorRole': actorRole,
        if (result.isNotEmpty) 'result': result,
        if (dateFrom.text.trim().isNotEmpty) 'dateFrom': dateFrom.text.trim(),
        if (dateTo.text.trim().isNotEmpty) 'dateTo': dateTo.text.trim(),
        'page': page,
        'pageSize': pageSize,
      });

  @override
  void dispose() {
    for (final value in [
      actor,
      action,
      targetType,
      targetId,
      dateFrom,
      dateTo,
    ]) {
      value.dispose();
    }
    super.dispose();
  }

  void apply() => setState(() => page = 1);
  void reset() {
    for (final value in [
      actor,
      action,
      targetType,
      targetId,
      dateFrom,
      dateTo,
    ]) {
      value.clear();
    }
    actorRole = '';
    result = '';
    apply();
  }

  @override
  Widget build(BuildContext context) {
    final current = request;
    final state = ref.watch(cmsOperationsQueryProvider(current));
    return Column(
      children: [
        CmsHeader(
          currentRoute: widget.currentRoute ?? '/admin/audit-logs',
          title: 'Audit Explorer',
          subtitle: 'Read-only, backend-filtered privileged operation history.',
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              OperationFilters(
                children: [
                  OperationField(
                    controller: actor,
                    label: 'Actor ID',
                    onSubmitted: (_) => apply(),
                  ),
                  OperationSelect(
                    value: actorRole,
                    label: 'Actor role',
                    values: const [
                      '',
                      'support',
                      'content_manager',
                      'admin',
                      'super_admin',
                    ],
                    onChanged: (value) => setState(() {
                      actorRole = value ?? '';
                      page = 1;
                    }),
                  ),
                  OperationField(
                    controller: action,
                    label: 'Action contains',
                    onSubmitted: (_) => apply(),
                  ),
                  OperationField(
                    controller: targetType,
                    label: 'Target entity',
                    onSubmitted: (_) => apply(),
                  ),
                  OperationField(
                    controller: targetId,
                    label: 'Target ID',
                    onSubmitted: (_) => apply(),
                  ),
                  OperationSelect(
                    value: result,
                    label: 'Result',
                    values: const ['', 'success', 'failure'],
                    onChanged: (value) => setState(() {
                      result = value ?? '';
                      page = 1;
                    }),
                  ),
                  OperationField(
                    controller: dateFrom,
                    label: 'From (ISO date)',
                    onSubmitted: (_) => apply(),
                  ),
                  OperationField(
                    controller: dateTo,
                    label: 'To (ISO date)',
                    onSubmitted: (_) => apply(),
                  ),
                  ElevatedButton.icon(
                    onPressed: apply,
                    icon: const Icon(Icons.filter_alt),
                    label: const Text('Apply'),
                  ),
                  TextButton(
                    onPressed: reset,
                    child: const Text('Clear filters'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              state.when(
                loading: () =>
                    const CmsLoadingView(message: 'Loading audit records…'),
                error: (error, _) => CmsErrorView(
                  message: 'Unable to load this view. Please try again.',
                  onRetry: () =>
                      ref.invalidate(cmsOperationsQueryProvider(current)),
                ),
                data: (data) {
                  final items = operationItems(data);
                  final total = data['total'] as int? ?? items.length;
                  return CmsCard(
                    title: 'Audit records ($total)',
                    subtitle:
                        'Immutable records; metadata is sanitised by the backend.',
                    child: Column(
                      children: [
                        if (items.isEmpty)
                          const CmsEmptyView(
                            title: 'No audit records match these filters',
                          )
                        else
                          for (final item in items)
                            OperationRecord(
                              item: Map<String, Object?>.from(item)
                                ..remove('data'),
                              actions: [
                                OutlinedButton(
                                  onPressed: () => _showMetadata(item['data']),
                                  child: const Text('Inspect metadata'),
                                ),
                              ],
                            ),
                        const SizedBox(height: 12),
                        OperationPagination(
                          canPrevious: page > 1,
                          canNext: page * pageSize < total,
                          label: 'Page $page',
                          onPrevious: () => setState(() => page--),
                          onNext: () => setState(() => page++),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showMetadata(Object? metadata) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Sanitised audit metadata'),
      content: SizedBox(
        width: 560,
        child: SelectableText(
          const JsonEncoder.withIndent('  ').convert(metadata ?? const {}),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
