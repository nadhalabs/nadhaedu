import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nadha_cms/core/errors/result.dart';
import 'package:nadha_cms/features/cms/presentation/theme/cms_theme.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_card.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_header.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_state_views.dart';
import 'package:nadha_cms/features/operations/application/cms_operations_providers.dart';
import 'package:nadha_cms/features/operations/presentation/cms_operation_widgets.dart';

class CmsNotificationsScreen extends ConsumerStatefulWidget {
  const CmsNotificationsScreen({super.key});
  @override
  ConsumerState<CmsNotificationsScreen> createState() => _State();
}

class _State extends ConsumerState<CmsNotificationsScreen> {
  final learner = TextEditingController();
  final title = TextEditingController();
  final body = TextEditingController();
  String type = 'systemAnnouncement';
  String priority = 'normal';
  bool submitting = false;
  String? validation;

  CmsOperationsRequest get request =>
      CmsOperationsRequest('/api/v1/admin/notifications', {
        if (learner.text.trim().isNotEmpty) 'learnerId': learner.text.trim(),
        'limit': 50,
      });

  @override
  void dispose() {
    learner.dispose();
    title.dispose();
    body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = request;
    final state = ref.watch(cmsOperationsQueryProvider(current));
    return Column(
      children: [
        const CmsHeader(
          currentRoute: '/admin/notifications',
          title: 'In-app Notifications',
          subtitle:
              'Create in-app records. Push delivery and scheduling are not configured.',
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: CmsTheme.warningBg,
                  border: Border.all(color: CmsTheme.warningColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Fail-closed delivery: this creates an in-app notification record only. It does not confirm FCM/APNs delivery and does not schedule delivery.',
                  style: TextStyle(color: CmsTheme.warningText),
                ),
              ),
              const SizedBox(height: 16),
              CmsCard(
                title: 'Compose notification record',
                child: Column(
                  children: [
                    TextField(
                      controller: learner,
                      decoration: const InputDecoration(
                        labelText: 'Target learner ID',
                      ),
                    ),
                    TextField(
                      controller: title,
                      maxLength: 200,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    TextField(
                      controller: body,
                      maxLength: 4000,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: 'Body'),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        OperationSelect(
                          value: type,
                          label: 'Type',
                          values: const [
                            'systemAnnouncement',
                            'courseUpdate',
                            'lessonReminder',
                            'learningReminder',
                            'securityEvent',
                          ],
                          onChanged: (value) =>
                              setState(() => type = value ?? type),
                        ),
                        OperationSelect(
                          value: priority,
                          label: 'Priority',
                          values: const ['low', 'normal', 'high'],
                          onChanged: (value) =>
                              setState(() => priority = value ?? priority),
                        ),
                      ],
                    ),
                    if (validation != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          validation!,
                          style: const TextStyle(color: CmsTheme.dangerText),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        key: const Key('create-notification'),
                        onPressed: submitting ? null : () => _submit(current),
                        icon: submitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.add_alert),
                        label: const Text('Create in-app record'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              state.when(
                loading: () => const CmsLoadingView(
                  message: 'Loading notification records…',
                ),
                error: (error, _) => CmsErrorView(
                  message: 'Unable to load this view. Please try again.',
                  onRetry: () =>
                      ref.invalidate(cmsOperationsQueryProvider(current)),
                ),
                data: (data) {
                  final items = operationItems(data);
                  return CmsCard(
                    title: 'In-app records (${items.length})',
                    child: Column(
                      children: [
                        if (items.isEmpty)
                          const CmsEmptyView(title: 'No notification records')
                        else
                          for (final item in items) OperationRecord(item: item),
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

  Future<void> _submit(CmsOperationsRequest current) async {
    if (learner.text.trim().isEmpty ||
        title.text.trim().isEmpty ||
        body.text.trim().isEmpty) {
      setState(
        () => validation = 'Target learner, title, and body are required.',
      );
      return;
    }
    setState(() {
      submitting = true;
      validation = null;
    });
    final result = await ref
        .read(cmsOperationsRepositoryProvider)
        .post(
          '/api/v1/admin/notifications',
          body: {
            'userId': learner.text.trim(),
            'title': title.text.trim(),
            'body': body.text.trim(),
            'notificationType': type,
            'priority': priority,
          },
        );
    if (!mounted) return;
    setState(() => submitting = false);
    switch (result) {
      case Success():
        title.clear();
        body.clear();
        ref.invalidate(cmsOperationsQueryProvider(current));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'In-app record created. Push delivery was not attempted.',
            ),
          ),
        );
      case Failure(failure: final failure):
        setState(() => validation = failure.message);
    }
  }
}
