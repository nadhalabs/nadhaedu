import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_card.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_header.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_state_views.dart';
import 'package:nadha_cms/features/operations/application/cms_operations_providers.dart';
import 'package:nadha_cms/features/operations/presentation/cms_operation_widgets.dart';

class CmsLearnersScreen extends ConsumerStatefulWidget {
  const CmsLearnersScreen({super.key});

  @override
  ConsumerState<CmsLearnersScreen> createState() => _CmsLearnersScreenState();
}

class _CmsLearnersScreenState extends ConsumerState<CmsLearnersScreen> {
  final search = TextEditingController();
  final course = TextEditingController();
  String active = '';
  String? cursor;
  final cursors = <String?>[];

  CmsOperationsRequest get request =>
      CmsOperationsRequest('/api/v1/admin/learners', {
        if (search.text.trim().isNotEmpty) 'search': search.text.trim(),
        if (course.text.trim().isNotEmpty) 'courseId': course.text.trim(),
        if (active.isNotEmpty) 'active': active == 'active',
        if (cursor != null) 'cursor': cursor,
        'limit': 25,
      });

  @override
  void dispose() {
    search.dispose();
    course.dispose();
    super.dispose();
  }

  void apply() => setState(() {
    cursor = null;
    cursors.clear();
  });

  void reset() {
    search.clear();
    course.clear();
    active = '';
    apply();
  }

  @override
  Widget build(BuildContext context) {
    final current = request;
    final state = ref.watch(cmsOperationsQueryProvider(current));
    return Column(
      children: [
        const CmsHeader(
          currentRoute: '/admin/learners',
          title: 'Learner Operations',
          subtitle:
              'Backend-driven identity, enrollment and support workspace.',
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              OperationFilters(
                children: [
                  OperationField(
                    controller: search,
                    label: 'Name, email, or learner ID',
                    onSubmitted: (_) => apply(),
                  ),
                  OperationSelect(
                    value: active,
                    label: 'Account status',
                    values: const ['', 'active', 'suspended'],
                    onChanged: (value) => setState(() {
                      active = value ?? '';
                      cursor = null;
                      cursors.clear();
                    }),
                  ),
                  OperationField(
                    controller: course,
                    label: 'Course / enrollment ID',
                    onSubmitted: (_) => apply(),
                  ),
                  ElevatedButton.icon(
                    onPressed: apply,
                    icon: const Icon(Icons.search),
                    label: const Text('Search'),
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
                    const CmsLoadingView(message: 'Searching learners…'),
                error: (error, _) => CmsErrorView(
                  message: 'Unable to load this view. Please try again.',
                  onRetry: () =>
                      ref.invalidate(cmsOperationsQueryProvider(current)),
                ),
                data: (data) {
                  final items = operationItems(data);
                  final next = data['nextCursor'] as String?;
                  return CmsCard(
                    title: 'Learners (${items.length})',
                    subtitle:
                        'Use View learner to open the stable detail workspace.',
                    child: Column(
                      children: [
                        if (items.isEmpty)
                          const CmsEmptyView(
                            title: 'No learners found',
                            message:
                                'Adjust or clear the backend search filters.',
                          )
                        else
                          for (final item in items)
                            OperationRecord(
                              item: item,
                              actions: [
                                ElevatedButton.icon(
                                  key: ValueKey('view-learner-${item['id']}'),
                                  onPressed: () => context.go(
                                    '/admin/learners/${item['id']}',
                                  ),
                                  icon: const Icon(Icons.open_in_new, size: 16),
                                  label: const Text('View learner'),
                                ),
                              ],
                            ),
                        const SizedBox(height: 12),
                        OperationPagination(
                          canPrevious: cursors.isNotEmpty,
                          canNext: next != null,
                          onPrevious: () =>
                              setState(() => cursor = cursors.removeLast()),
                          onNext: () => setState(() {
                            cursors.add(cursor);
                            cursor = next;
                          }),
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
}
