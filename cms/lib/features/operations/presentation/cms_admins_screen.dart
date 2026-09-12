import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nadha_cms/core/errors/result.dart';
import 'package:nadha_cms/features/authentication/application/auth_providers.dart';
import 'package:nadha_cms/features/cms/presentation/theme/cms_theme.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_card.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_confirm_dialog.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_header.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_state_views.dart';
import 'package:nadha_cms/features/operations/application/cms_operations_providers.dart';
import 'package:nadha_cms/features/operations/presentation/cms_operation_widgets.dart';

class CmsAdminsScreen extends ConsumerStatefulWidget {
  const CmsAdminsScreen({super.key});
  @override
  ConsumerState<CmsAdminsScreen> createState() => _State();
}

class _State extends ConsumerState<CmsAdminsScreen> {
  static const request = CmsOperationsRequest('/api/v1/admin/super/admins');
  bool submitting = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cmsOperationsQueryProvider(request));
    final selfId = ref.watch(authControllerProvider).session?.identity.id;
    return Column(
      children: [
        const CmsHeader(
          currentRoute: '/admin/super/admins',
          title: 'Admin Management',
          subtitle: 'Super-admin-only privilege and account controls.',
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: CmsTheme.dangerBg,
                  border: Border.all(color: CmsTheme.dangerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'ULTIMATE CONTROL — backend safeguards remain authoritative. Every action requires a reason and confirmation.',
                  style: TextStyle(
                    color: CmsTheme.dangerText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              state.when(
                loading: () =>
                    const CmsLoadingView(message: 'Loading administrators…'),
                error: (error, _) => CmsErrorView(
                  message: 'Unable to load this view. Please try again.',
                  onRetry: () =>
                      ref.invalidate(cmsOperationsQueryProvider(request)),
                ),
                data: (data) {
                  final items = operationItems(data);
                  return CmsCard(
                    title: 'Administrators (${items.length})',
                    child: Column(
                      children: [
                        if (items.isEmpty)
                          const CmsEmptyView(title: 'No administrators found')
                        else
                          for (final item in items)
                            OperationRecord(
                              item: item,
                              actions: [
                                OutlinedButton(
                                  onPressed: submitting || item['id'] == selfId
                                      ? null
                                      : () => _changeRole(item),
                                  child: Text(
                                    item['id'] == selfId
                                        ? 'Current operator'
                                        : 'Change role',
                                  ),
                                ),
                                if (item['isActive'] == true)
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: CmsTheme.dangerColor,
                                    ),
                                    onPressed:
                                        submitting || item['id'] == selfId
                                        ? null
                                        : () => _accountAction(item, 'suspend'),
                                    child: const Text('Suspend'),
                                  )
                                else
                                  ElevatedButton(
                                    onPressed: submitting
                                        ? null
                                        : () => _accountAction(
                                            item,
                                            'reactivate',
                                          ),
                                    child: const Text('Reactivate'),
                                  ),
                                OutlinedButton(
                                  onPressed: submitting
                                      ? null
                                      : () => _accountAction(
                                          item,
                                          'revoke-sessions',
                                        ),
                                  child: const Text('Revoke sessions'),
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

  Future<void> _changeRole(Map<String, Object?> item) async {
    var role = '${item['role']}';
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Change role — ${item['email']}'),
          content: DropdownButtonFormField<String>(
            initialValue: role,
            decoration: const InputDecoration(labelText: 'Approved role'),
            items: const ['support', 'content_manager', 'admin', 'super_admin']
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(operationLabel(value)),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => role = value ?? role),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, role),
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    final reason = await _confirm(
      item,
      'Change role from ${item['role']} to $selected',
      false,
    );
    if (reason == null || !mounted) return;
    await _mutate(
      () => ref
          .read(cmsOperationsRepositoryProvider)
          .post(
            '/api/v1/admin/super/admins/${item['id']}/role',
            body: {'role': selected, 'reason': reason},
          ),
    );
  }

  Future<void> _accountAction(Map<String, Object?> item, String action) async {
    final reason = await _confirm(
      item,
      operationLabel(action),
      action == 'suspend' || action == 'revoke-sessions',
    );
    if (reason == null || !mounted) return;
    await _mutate(
      () => ref
          .read(cmsOperationsRepositoryProvider)
          .post(
            '/api/v1/admin/super/users/${item['id']}/$action',
            body: {'reason': reason},
          ),
    );
  }

  Future<String?> _confirm(
    Map<String, Object?> item,
    String operation,
    bool destructive,
  ) => CmsConfirmDialog.show(
    context,
    title: operation,
    message:
        'Target: ${item['displayName']} (${item['email']})\n'
        'Current role: ${item['role']} · Current state: ${item['isActive'] == true ? 'active' : 'suspended'}\n'
        'Requested operation: $operation',
    isDestructive: destructive,
    requireReason: true,
    reasonLabel: 'Reason (minimum 8 characters)',
  );

  Future<void> _mutate(
    Future<Result<Map<String, Object?>>> Function() operation,
  ) async {
    setState(() => submitting = true);
    final result = await operation();
    if (!mounted) return;
    setState(() => submitting = false);
    ref.invalidate(cmsOperationsQueryProvider(request));
    final message = switch (result) {
      Success() => 'Administrator state refreshed. The operation was audited.',
      Failure(failure: final failure) => failure.message,
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
