import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nadha_cms/core/errors/result.dart';
import 'package:nadha_cms/features/cms/presentation/theme/cms_theme.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_header.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_state_views.dart';
import 'package:nadha_cms/features/operations/application/cms_operations_providers.dart';

class CmsPlatformControlsScreen extends ConsumerWidget {
  const CmsPlatformControlsScreen({super.key});
  static const path = '/api/v1/admin/super/settings';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cmsOperationsDataProvider(path));
    return Column(
      children: [
        const CmsHeader(
          currentRoute: '/admin/super/controls',
          title: 'Platform Controls',
          subtitle:
              'Versioned emergency and global controls. Every change is audited.',
        ),
        Expanded(
          child: state.when(
            loading: () => const CmsLoadingView(message: 'Loading controls…'),
            error: (error, _) => CmsErrorView(
              message: 'Unable to load this view. Please try again.',
              onRetry: () => ref.invalidate(cmsOperationsDataProvider(path)),
            ),
            data: (data) {
              final items = (data['items'] as List? ?? const [])
                  .map((item) => Map<String, Object?>.from(item as Map))
                  .toList();
              return ListView(
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
                      'ULTIMATE CONTROL — verify impact before changing a platform-wide switch.',
                      style: TextStyle(
                        color: CmsTheme.dangerText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final item in items)
                    Card(
                      child: SwitchListTile(
                        value: item['value'] == true,
                        title: Text('${item['key']}'.replaceAll('_', ' ')),
                        subtitle: Text(
                          '${item['description']} · version ${item['version']}',
                        ),
                        activeThumbColor: CmsTheme.dangerColor,
                        onChanged: (value) =>
                            _confirm(context, ref, item, value),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _confirm(
    BuildContext context,
    WidgetRef ref,
    Map<String, Object?> item,
    bool value,
  ) async {
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm platform-wide change'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Set ${item['key']} to $value?'),
            const SizedBox(height: 12),
            TextField(
              controller: reason,
              decoration: const InputDecoration(
                labelText: 'Reason (minimum 8 characters)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (confirmed != true ||
        reason.text.trim().length < 8 ||
        !context.mounted) {
      return;
    }
    final result = await ref
        .read(cmsOperationsRepositoryProvider)
        .put(
          '$path/${item['key']}',
          body: {
            'value': value,
            'expectedVersion': item['version'],
            'reason': reason.text.trim(),
          },
        );
    if (!context.mounted) return;
    switch (result) {
      case Success():
        ref.invalidate(cmsOperationsDataProvider(path));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Control updated and audited.')),
        );
      case Failure(failure: final failure):
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }
}
