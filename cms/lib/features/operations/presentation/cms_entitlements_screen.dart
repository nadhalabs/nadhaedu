import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nadha_cms/core/errors/result.dart';
import 'package:nadha_cms/features/cms/presentation/theme/cms_theme.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_card.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_confirm_dialog.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_header.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_state_views.dart';
import 'package:nadha_cms/features/operations/application/cms_operations_providers.dart';
import 'package:nadha_cms/features/operations/presentation/cms_operation_widgets.dart';

class CmsEntitlementsScreen extends ConsumerStatefulWidget {
  const CmsEntitlementsScreen({super.key});
  @override
  ConsumerState<CmsEntitlementsScreen> createState() => _State();
}

class _State extends ConsumerState<CmsEntitlementsScreen> {
  final learner = TextEditingController();
  String status = '';
  bool submitting = false;

  CmsOperationsRequest get request =>
      CmsOperationsRequest('/api/v1/admin/entitlements', {
        if (learner.text.trim().isNotEmpty) 'learnerId': learner.text.trim(),
        if (status.isNotEmpty) 'status': status,
        'limit': 100,
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
          currentRoute: '/admin/entitlements',
          title: 'Entitlements',
          subtitle: 'Manual overrides are distinct from provider-owned access.',
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
                    value: status,
                    label: 'Status',
                    values: const ['', 'active', 'expired', 'revoked'],
                    onChanged: (value) => setState(() => status = value ?? ''),
                  ),
                  ElevatedButton.icon(
                    onPressed: submitting ? null : () => setState(() {}),
                    icon: const Icon(Icons.filter_alt),
                    label: const Text('Apply'),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      learner.clear();
                      status = '';
                    }),
                    child: const Text('Clear filters'),
                  ),
                  ElevatedButton.icon(
                    key: const Key('grant-entitlement'),
                    onPressed: submitting ? null : () => _grant(current),
                    icon: const Icon(Icons.add),
                    label: const Text('Grant manual entitlement'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              state.when(
                loading: () =>
                    const CmsLoadingView(message: 'Loading entitlements…'),
                error: (error, _) => CmsErrorView(
                  message: 'Unable to load this view. Please try again.',
                  onRetry: () =>
                      ref.invalidate(cmsOperationsQueryProvider(current)),
                ),
                data: (data) {
                  final items = operationItems(data);
                  return CmsCard(
                    title: 'Authoritative entitlement state (${items.length})',
                    child: Column(
                      children: [
                        if (items.isEmpty)
                          const CmsEmptyView(
                            title: 'No entitlements match these filters',
                          )
                        else
                          for (final item in items)
                            OperationRecord(
                              item: item,
                              actions: item['source'] == 'admin_grant'
                                  ? [
                                      OutlinedButton(
                                        onPressed: submitting
                                            ? null
                                            : () => _extend(item, current),
                                        child: const Text('Extend'),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: CmsTheme.dangerColor,
                                        ),
                                        onPressed:
                                            submitting ||
                                                item['status'] == 'revoked'
                                            ? null
                                            : () => _revoke(item, current),
                                        child: const Text('Revoke'),
                                      ),
                                    ]
                                  : const [
                                      Tooltip(
                                        message:
                                            'Provider-owned access is read-only in CMS.',
                                        child: Chip(
                                          label: Text('Provider owned'),
                                        ),
                                      ),
                                    ],
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

  Future<void> _grant(CmsOperationsRequest current) async {
    final values = await _entitlementDialog(
      context,
      title: 'Grant manual entitlement',
      initialLearner: learner.text,
      includeResource: true,
    );
    if (values == null || !mounted) return;
    final learnerId = values['learnerId']!;
    final confirmed = await CmsConfirmDialog.show(
      context,
      title: 'Confirm manual entitlement grant',
      message:
          'Learner: $learnerId\nCourse/product: ${values['resourceId']}\n'
          'Expiry: ${values['expiresAt']}\nRequested operation: grant manual entitlement\n'
          'Reason: ${values['reason']}',
      confirmLabel: 'Grant entitlement',
    );
    if (confirmed == null || !mounted) return;
    await _mutate(
      current,
      () => ref
          .read(cmsOperationsRepositoryProvider)
          .post(
            '/api/v1/admin/learners/$learnerId/entitlements',
            body: {
              'resourceType': 'course',
              'resourceId': values['resourceId'],
              'expiresAt': values['expiresAt'],
              'reason': values['reason'],
            },
          ),
      'Manual entitlement granted and audited.',
    );
  }

  Future<void> _extend(
    Map<String, Object?> item,
    CmsOperationsRequest current,
  ) async {
    final values = await _entitlementDialog(
      context,
      title: 'Extend manual entitlement',
      initialLearner: '${item['learnerId']}',
      initialResource: '${item['resourceId']}',
    );
    if (values == null || !mounted) return;
    final confirmed = await CmsConfirmDialog.show(
      context,
      title: 'Confirm entitlement extension',
      message:
          'Learner: ${item['learnerId']}\nCourse/product: ${item['resourceId']}\n'
          'Current state: ${item['status']} · version ${item['version']}\n'
          'New expiry: ${values['expiresAt']}\nReason: ${values['reason']}',
      confirmLabel: 'Extend entitlement',
    );
    if (confirmed == null || !mounted) return;
    await _mutate(
      current,
      () => ref
          .read(cmsOperationsRepositoryProvider)
          .post(
            '/api/v1/admin/entitlements/${item['id']}/extend',
            body: {
              'expectedVersion': item['version'],
              'expiresAt': values['expiresAt'],
              'reason': values['reason'],
            },
          ),
      'Entitlement extended and audited.',
    );
  }

  Future<void> _revoke(
    Map<String, Object?> item,
    CmsOperationsRequest current,
  ) async {
    final reason = await CmsConfirmDialog.show(
      context,
      title: 'Revoke manual entitlement',
      message:
          'Learner: ${item['learnerId']}\nCourse/product: ${item['resourceId']}\n'
          'Current state: ${item['status']}\nRequested operation: permanent manual revocation.',
      confirmLabel: 'Revoke entitlement',
      isDestructive: true,
      requireReason: true,
      reasonLabel: 'Reason (minimum 8 characters)',
    );
    if (reason == null || !mounted) return;
    await _mutate(
      current,
      () => ref
          .read(cmsOperationsRepositoryProvider)
          .post(
            '/api/v1/admin/entitlements/${item['id']}/revoke',
            body: {'expectedVersion': item['version'], 'reason': reason},
          ),
      'Entitlement revoked and audited.',
    );
  }

  Future<void> _mutate(
    CmsOperationsRequest current,
    Future<Result<Map<String, Object?>>> Function() operation,
    String success,
  ) async {
    setState(() => submitting = true);
    final result = await operation();
    if (!mounted) return;
    setState(() => submitting = false);
    ref.invalidate(cmsOperationsQueryProvider(current));
    final message = switch (result) {
      Success() => success,
      Failure(failure: final failure) => failure.message,
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

Future<Map<String, String>?> _entitlementDialog(
  BuildContext context, {
  required String title,
  String initialLearner = '',
  String initialResource = '',
  bool includeResource = false,
}) async {
  final learner = TextEditingController(text: initialLearner);
  final resource = TextEditingController(text: initialResource);
  final expiry = TextEditingController();
  final reason = TextEditingController();
  String? error;
  return showDialog<Map<String, String>>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: learner,
                  readOnly: !includeResource,
                  decoration: const InputDecoration(labelText: 'Learner ID'),
                ),
                TextField(
                  controller: resource,
                  readOnly: !includeResource,
                  decoration: const InputDecoration(
                    labelText: 'Course / product ID',
                  ),
                ),
                TextField(
                  controller: expiry,
                  decoration: const InputDecoration(
                    labelText:
                        'Future expiry (ISO-8601, e.g. 2027-01-31T00:00:00Z)',
                  ),
                ),
                TextField(
                  controller: reason,
                  decoration: const InputDecoration(
                    labelText: 'Reason (minimum 8 characters)',
                  ),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      error!,
                      style: const TextStyle(color: CmsTheme.dangerText),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final parsed = DateTime.tryParse(expiry.text.trim());
                if (learner.text.trim().isEmpty ||
                    resource.text.trim().isEmpty ||
                    parsed == null ||
                    !parsed.isAfter(DateTime.now()) ||
                    reason.text.trim().length < 8) {
                  setDialogState(
                    () => error =
                        'Complete all fields, use a future expiry, and provide a reason.',
                  );
                  return;
                }
                Navigator.pop(context, {
                  'learnerId': learner.text.trim(),
                  'resourceId': resource.text.trim(),
                  'expiresAt': parsed.toUtc().toIso8601String(),
                  'reason': reason.text.trim(),
                });
              },
              child: const Text('Review and confirm'),
            ),
          ],
        );
      },
    ),
  );
}
