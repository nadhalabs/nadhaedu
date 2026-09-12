import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nadha_cms/bootstrap/cms_providers.dart';
import 'package:nadha_cms/core/errors/result.dart';

typedef AcademicRow = Map<String, Object?>;

final academicRecordsProvider = FutureProvider.autoDispose
    .family<List<AcademicRow>, String>((ref, kind) async {
      final result = await ref
          .watch(apiClientProvider)
          .get('/api/v1/admin/academic/$kind');
      return switch (result) {
        Success(value: final data) =>
          (data['items']! as List).cast<AcademicRow>(),
        Failure(failure: final error) => throw StateError(error.message),
      };
    });

/// Shared dependent selectors. Null classification deliberately means legacy.
class AcademicSelectors extends ConsumerWidget {
  const AcademicSelectors({
    required this.value,
    required this.onChanged,
    super.key,
  });
  final AcademicRow value;
  final ValueChanged<AcademicRow> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final entry in const {
          'curricula': 'Curriculum',
          'standards': 'Standard',
          'streams': 'Stream',
          'subjects': 'Subject',
        }.entries)
          ref
              .watch(academicRecordsProvider(entry.key))
              .when(
                loading: () => const SizedBox(
                  width: 160,
                  child: LinearProgressIndicator(),
                ),
                error: (error, _) => TextButton(
                  onPressed: () =>
                      ref.invalidate(academicRecordsProvider(entry.key)),
                  child: Text('Retry ${entry.value}: $error'),
                ),
                data: (records) {
                  final field = {
                    'curricula': 'curriculumId',
                    'standards': 'standardId',
                    'streams': 'streamId',
                    'subjects': 'subjectId',
                  }[entry.key]!;
                  final items = records
                      .where(
                        (r) =>
                            r['isActive'] == true &&
                            (entry.key != 'standards' ||
                                r['curriculumId'] == value['curriculumId']) &&
                            (entry.key != 'streams' ||
                                r['standardId'] == value['standardId']),
                      )
                      .toList();
                  if (entry.key == 'streams' &&
                      items.isEmpty &&
                      value[field] == null) {
                    return const SizedBox.shrink();
                  }
                  final current = value[field] as String?;
                  return SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      key: ValueKey('$field:$current:${items.length}'),
                      initialValue: items.any((r) => r['id'] == current)
                          ? current
                          : null,
                      decoration: InputDecoration(labelText: entry.value),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('Not selected'),
                        ),
                        ...items.map(
                          (r) => DropdownMenuItem(
                            value: r['id']! as String,
                            child: Text(r['name']! as String),
                          ),
                        ),
                      ],
                      onChanged: (selected) {
                        final next = {
                          ...value,
                          field: selected == '' ? null : selected,
                        };
                        if (field == 'curriculumId') {
                          next['standardId'] = null;
                          next['streamId'] = null;
                        }
                        if (field == 'standardId') next['streamId'] = null;
                        onChanged(next);
                      },
                    ),
                  );
                },
              ),
      ],
    );
  }
}

class CmsAcademicScreen extends ConsumerWidget {
  const CmsAcademicScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => DefaultTabController(
    length: 4,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Academic catalog'),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Curricula'),
            Tab(text: 'Standards'),
            Tab(text: 'Streams'),
            Tab(text: 'Subjects'),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          for (final kind in ['curricula', 'standards', 'streams', 'subjects'])
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Disable records to retire them. Existing content and history are retained.',
                        ),
                      ),
                      FilledButton(
                        onPressed: () async {
                          await showDialog<void>(
                            context: context,
                            builder: (_) => _TaxonomyDialog(kind: kind),
                          );
                        },
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ref
                      .watch(academicRecordsProvider(kind))
                      .when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Center(
                          child: TextButton(
                            onPressed: () =>
                                ref.invalidate(academicRecordsProvider(kind)),
                            child: Text('Retry: $e'),
                          ),
                        ),
                        data: (rows) => ListView(
                          children: rows
                              .map(
                                (r) => ListTile(
                                  title: Text(r['name']! as String),
                                  subtitle: Text(
                                    '${r['code']} • ${r['isActive'] == true ? 'Active' : 'Disabled'}',
                                  ),
                                  trailing: const Icon(Icons.edit),
                                  onTap: () async {
                                    await showDialog<void>(
                                      context: context,
                                      builder: (_) =>
                                          _TaxonomyDialog(kind: kind, row: r),
                                    );
                                  },
                                ),
                              )
                              .toList(),
                        ),
                      ),
                ),
              ],
            ),
        ],
      ),
    ),
  );
}

class _TaxonomyDialog extends ConsumerStatefulWidget {
  const _TaxonomyDialog({required this.kind, this.row});
  final String kind;
  final AcademicRow? row;
  @override
  ConsumerState<_TaxonomyDialog> createState() => _TaxonomyDialogState();
}

class _TaxonomyDialogState extends ConsumerState<_TaxonomyDialog> {
  late final name = TextEditingController(text: widget.row?['name'] as String?);
  late final code = TextEditingController(text: widget.row?['code'] as String?);
  late final order = TextEditingController(
    text: '${widget.row?['sortOrder'] ?? 0}',
  );
  late final country = TextEditingController(
    text: widget.row?['country'] as String? ?? 'India',
  );
  late final region = TextEditingController(
    text: widget.row?['region'] as String?,
  );
  late bool active = widget.row?['isActive'] as bool? ?? true;
  late String? parent =
      widget.row?[widget.kind == 'standards' ? 'curriculumId' : 'standardId']
          as String?;
  bool saving = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    code.dispose();
    order.dispose();
    country.dispose();
    region.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parentKind = widget.kind == 'standards'
        ? 'curricula'
        : widget.kind == 'streams'
        ? 'standards'
        : null;
    return AlertDialog(
      title: Text('${widget.row == null ? 'Add' : 'Edit'} ${widget.kind}'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: code,
                decoration: const InputDecoration(labelText: 'Code'),
              ),
              TextField(
                controller: order,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Sort order'),
              ),
              if (widget.kind == 'curricula') ...[
                TextField(
                  controller: country,
                  decoration: const InputDecoration(labelText: 'Country'),
                ),
                TextField(
                  controller: region,
                  decoration: const InputDecoration(
                    labelText: 'Region / State (optional)',
                  ),
                ),
              ],
              if (parentKind != null)
                ref
                    .watch(academicRecordsProvider(parentKind))
                    .when(
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('$e'),
                      data: (rows) => DropdownButtonFormField<String>(
                        initialValue: parent,
                        decoration: InputDecoration(labelText: parentKind),
                        items: rows
                            .map(
                              (r) => DropdownMenuItem(
                                value: r['id']! as String,
                                child: Text('${r['name']} (${r['code']})'),
                              ),
                            )
                            .toList(),
                        onChanged: widget.row != null
                            ? null
                            : (v) => setState(() => parent = v),
                      ),
                    ),
              SwitchListTile(
                title: const Text('Active'),
                value: active,
                onChanged: (v) => setState(() => active = v),
              ),
              if (error != null) Text(error!),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: saving
              ? null
              : () async {
                  setState(() {
                    saving = true;
                    error = null;
                  });
                  final body = <String, Object?>{
                    'name': name.text.trim(),
                    'code': code.text.trim(),
                    'sortOrder': int.tryParse(order.text) ?? 0,
                    'isActive': active,
                    'country': country.text,
                    'region': region.text.isEmpty ? null : region.text,
                    if (parentKind != null)
                      widget.kind == 'standards'
                              ? 'curriculumId'
                              : 'standardId':
                          parent,
                  };
                  final api = ref.read(apiClientProvider);
                  final path = '/api/v1/admin/academic/${widget.kind}';
                  final result = widget.row == null
                      ? await api.post(path, body: body)
                      : await api.put('$path/${widget.row!['id']}', body: body);
                  if (!mounted || !context.mounted) return;
                  switch (result) {
                    case Success():
                      ref.invalidate(academicRecordsProvider(widget.kind));
                      Navigator.pop(context);
                    case Failure(failure: final e):
                      setState(() {
                        saving = false;
                        error = e.message;
                      });
                  }
                },
          child: Text(saving ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }
}
