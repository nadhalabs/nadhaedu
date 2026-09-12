import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nadha_cms/bootstrap/cms_providers.dart';
import 'package:nadha_cms/core/errors/result.dart';
import 'package:nadha_cms/features/cms/media/direct_upload.dart';
import 'package:nadha_cms/features/cms/media/media_upload.dart';

final contentEditorDataProvider = FutureProvider.autoDispose
    .family<Map<String, Object?>, String>((ref, path) async {
      return switch (await ref.watch(apiClientProvider).get('/api/v1/$path')) {
        Success(value: final data) => data,
        Failure(failure: final error) => throw StateError(error.message),
      };
    });

class CmsContentItemsScreen extends ConsumerWidget {
  const CmsContentItemsScreen({
    required this.lessonId,
    required this.courseId,
    super.key,
  });
  final String lessonId;
  final String courseId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = 'admin/lessons/$lessonId/content-items';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lesson content'),
        actions: [
          TextButton(
            onPressed: () async {
              final rows =
                  ref
                          .read(contentEditorDataProvider(path))
                          .valueOrNull?['items']
                      as List? ??
                  [];
              final position =
                  rows.fold<int>(
                    0,
                    (v, r) => (r as Map)['position'] as int > v
                        ? r['position'] as int
                        : v,
                  ) +
                  1;
              await showDialog<void>(
                context: context,
                builder: (_) => _ContentDialog(
                  lessonId: lessonId,
                  courseId: courseId,
                  position: position,
                ),
              );
            },
            child: const Text('Add content'),
          ),
        ],
      ),
      body: ref
          .watch(contentEditorDataProvider(path))
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: TextButton(
                onPressed: () =>
                    ref.invalidate(contentEditorDataProvider(path)),
                child: Text('Retry: $e'),
              ),
            ),
            data: (data) {
              final rows = (data['items']! as List)
                  .cast<Map<String, Object?>>();
              return Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Drag to order. Archive to retire content without deleting history. Upload a video inside Add content. Resources use existing registered downloads.',
                    ),
                  ),
                  Expanded(
                    child: ReorderableListView(
                      onReorder: (oldIndex, newIndex) async {
                        final ids = rows
                            .map((r) => r['id']! as String)
                            .toList();
                        if (newIndex > oldIndex) newIndex--;
                        ids.insert(newIndex, ids.removeAt(oldIndex));
                        final result = await ref
                            .read(apiClientProvider)
                            .post(
                              '/api/v1/$path/reorder',
                              body: {'itemIds': ids},
                            );
                        ref.invalidate(contentEditorDataProvider(path));
                        if (result case Failure(
                          failure: final e,
                        ) when context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(e.message)));
                        }
                      },
                      children: [
                        for (final row in rows)
                          ListTile(
                            key: ValueKey(row['id']),
                            title: Text('${row['position']}. ${row['title']}'),
                            subtitle: Text('${row['type']} • ${row['status']}'),
                            onTap: () async {
                              await showDialog<void>(
                                context: context,
                                builder: (_) => _ContentDialog(
                                  lessonId: lessonId,
                                  courseId: courseId,
                                  position: row['position']! as int,
                                  row: row,
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
    );
  }
}

class _ContentDialog extends ConsumerStatefulWidget {
  const _ContentDialog({
    required this.lessonId,
    required this.courseId,
    required this.position,
    this.row,
  });
  final String lessonId;
  final String courseId;
  final int position;
  final Map<String, Object?>? row;
  @override
  ConsumerState<_ContentDialog> createState() => _ContentDialogState();
}

class _ContentDialogState extends ConsumerState<_ContentDialog> {
  late final title = TextEditingController(
    text: widget.row?['title'] as String?,
  );
  late final body = TextEditingController(text: widget.row?['body'] as String?);
  late String type = widget.row?['type'] as String? ?? 'note';
  late String status = widget.row?['status'] as String? ?? 'draft';
  late String? reference = widget.row?['referenceId'] as String?;
  late String? assessment = widget.row?['assessmentId'] as String?;
  String? error;
  bool saving = false;
  @override
  void dispose() {
    title.dispose();
    body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Content item'),
    content: SizedBox(
      width: 560,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            DropdownButtonFormField<String>(
              initialValue: type,
              items: [
                'video',
                'note',
                'quiz',
                'resource',
              ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (v) => setState(() {
                type = v!;
                reference = null;
                assessment = null;
              }),
            ),
            DropdownButtonFormField<String>(
              initialValue: status,
              items: [
                'draft',
                'published',
                'unavailable',
                'archived',
              ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (v) => setState(() => status = v!),
            ),
            if (type == 'note')
              TextField(
                controller: body,
                minLines: 6,
                maxLines: 15,
                decoration: const InputDecoration(
                  labelText: 'Note text (plain text)',
                ),
              ),
            if (type == 'quiz')
              ref
                  .watch(
                    contentEditorDataProvider(
                      'admin/courses/${widget.courseId}',
                    ),
                  )
                  .when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('$e'),
                    data: (data) {
                      final rows = (data['assessments'] as List? ?? [])
                          .cast<Map<String, Object?>>();
                      return DropdownButtonFormField<String>(
                        key: ValueKey('assessment:$assessment'),
                        initialValue: rows.any((r) => r['id'] == assessment)
                            ? assessment
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Course assessment',
                        ),
                        items: rows
                            .map(
                              (r) => DropdownMenuItem(
                                value: r['id']! as String,
                                child: Text('${r['title']} (${r['status']})'),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => assessment = v),
                      );
                    },
                  ),
            if (type == 'video')
              MediaUpload(
                lessonId: widget.lessonId,
                replaceAssetId: widget.row?['referenceId'] as String?,
                onBusy: (busy) => setState(() => saving = busy),
                onReady: (data) {
                  setState(() => reference = data['assetId']! as String);
                  ref.invalidate(
                    contentEditorDataProvider(
                      'admin/lessons/${widget.lessonId}/media-assets',
                    ),
                  );
                },
              ),
            if (type == 'video' || type == 'resource')
              ref
                  .watch(
                    contentEditorDataProvider(
                      'admin/lessons/${widget.lessonId}/media-assets',
                    ),
                  )
                  .when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('$e'),
                    data: (data) {
                      final rows = (data['items']! as List)
                          .cast<Map<String, Object?>>()
                          .where(
                            (r) =>
                                r['status'] == 'active' &&
                                r['kind'] ==
                                    (type == 'video' ? 'hls' : 'download') &&
                                (r['contentItemId'] == null ||
                                    r['contentItemId'] == widget.row?['id']),
                          )
                          .toList();
                      if (rows.isEmpty) {
                        return const Text(
                          'No eligible media yet. Upload a video above, or register a downloadable resource.',
                        );
                      }
                      final selected = rows
                          .where((r) => r['assetId'] == reference)
                          .firstOrNull;
                      return Column(
                        children: [
                          if (selected?['posterUrl'] != null)
                            Image.network(
                              selected!['posterUrl']! as String,
                              height: 150,
                              errorBuilder: (_, _, _) =>
                                  const Icon(Icons.video_library),
                            ),
                          if (selected?['previewUrl'] != null)
                            TextButton(
                              onPressed: () => openPreview(
                                selected!['previewUrl']! as String,
                              ),
                              child: const Text('Preview video'),
                            ),
                          DropdownButtonFormField<String>(
                            key: ValueKey('asset:$reference:$type'),
                            initialValue:
                                rows.any((r) => r['assetId'] == reference)
                                ? reference
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'Registered media asset',
                            ),
                            items: rows
                                .map(
                                  (r) => DropdownMenuItem(
                                    value: r['assetId']! as String,
                                    child: Text(r['assetId']! as String),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() => reference = v),
                          ),
                        ],
                      );
                    },
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
                final path =
                    '/api/v1/admin/lessons/${widget.lessonId}/content-items';
                final payload = <String, Object?>{
                  'title': title.text,
                  'contentType': type,
                  'status': status,
                  'position': widget.position,
                  'body': type == 'note' ? body.text : null,
                  'referenceId': reference,
                  'assessmentId': assessment,
                };
                final api = ref.read(apiClientProvider);
                final result = widget.row == null
                    ? await api.post(path, body: payload)
                    : await api.put(
                        '$path/${widget.row!['id']}',
                        body: payload,
                      );
                if (!mounted || !context.mounted) return;
                switch (result) {
                  case Success():
                    ref.invalidate(
                      contentEditorDataProvider(
                        'admin/lessons/${widget.lessonId}/content-items',
                      ),
                    );
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
