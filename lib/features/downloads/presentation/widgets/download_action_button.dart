import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_platform/core/theme/app_spacing.dart';
import 'package:learning_platform/features/downloads/application/download_providers.dart';
import 'package:learning_platform/features/downloads/domain/download_task.dart';
import 'package:learning_platform/features/downloads/domain/storage_summary.dart';

class DownloadActionButton extends ConsumerWidget {
  const DownloadActionButton({
    required this.resourceId,
    required this.courseId,
    this.lessonId,
    required this.title,
    required this.courseTitle,
    this.resourceType = DownloadResourceType.video,
    this.compact = false,
    super.key,
  });

  final String resourceId;
  final String courseId;
  final String? lessonId;
  final String title;
  final String courseTitle;
  final DownloadResourceType resourceType;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = ref.watch(downloadTaskForResourceProvider(resourceId));
    final controller = ref.read(downloadControllerProvider.notifier);

    if (task == null) {
      return IconButton(
        icon: const Icon(Icons.download_outlined),
        tooltip: 'Download $title',
        onPressed: () {
          unawaited(
            controller.startDownload(
              resourceType: resourceType,
              resourceId: resourceId,
              courseId: courseId,
              lessonId: lessonId,
              title: title,
              courseTitle: courseTitle,
            ),
          );
        },
      );
    }

    return switch (task.state) {
      DownloadState.queued || DownloadState.preparing => IconButton(
        icon: const SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        tooltip: 'Download queued',
        onPressed: () => _showDownloadOptions(context, ref, task),
      ),
      DownloadState.downloading => Semantics(
        label: 'Downloading: ${(task.progress * 100).round()}%',
        value: '${(task.progress * 100).round()}%',
        button: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showDownloadOptions(context, ref, task),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: SizedBox.square(
              dimension: 24,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: task.progress > 0 ? task.progress : null,
                    strokeWidth: 3,
                  ),
                  const Icon(Icons.pause, size: 12),
                ],
              ),
            ),
          ),
        ),
      ),
      DownloadState.paused => IconButton(
        icon: const Icon(Icons.pause_circle_outline, color: Colors.orange),
        tooltip: 'Download paused: tap to resume',
        onPressed: () => unawaited(controller.resumeDownload(task.id)),
      ),
      DownloadState.completed => IconButton(
        icon: Icon(
          task.isOfflineEntitlementValid ? Icons.download_done : Icons.history,
          color: task.isOfflineEntitlementValid
              ? Theme.of(context).colorScheme.primary
              : Colors.amber,
        ),
        tooltip: task.isOfflineEntitlementValid
            ? 'Downloaded: tap for options'
            : 'Offline access expired: tap to revalidate',
        onPressed: () => _showDownloadOptions(context, ref, task),
      ),
      DownloadState.failed => IconButton(
        icon: const Icon(Icons.error_outline, color: Colors.red),
        tooltip: 'Download failed: tap to retry',
        onPressed: () => unawaited(controller.retryDownload(task.id)),
      ),
      DownloadState.expired => IconButton(
        icon: const Icon(Icons.history, color: Colors.amber),
        tooltip: 'Offline access expired: tap to revalidate',
        onPressed: () => _showDownloadOptions(context, ref, task),
      ),
      DownloadState.deleting || DownloadState.cancelled => IconButton(
        icon: const Icon(Icons.download_outlined),
        tooltip: 'Download $title',
        onPressed: () {
          unawaited(
            controller.startDownload(
              resourceType: resourceType,
              resourceId: resourceId,
              courseId: courseId,
              lessonId: lessonId,
              title: title,
              courseTitle: courseTitle,
            ),
          );
        },
      ),
    };
  }

  void _showDownloadOptions(
    BuildContext context,
    WidgetRef ref,
    DownloadTask task,
  ) {
    final controller = ref.read(downloadControllerProvider.notifier);
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.medium),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.small),
                Text(
                  'Status: ${task.state.name} • ${StorageSummary.formatBytes(task.bytesDownloaded)} of ${StorageSummary.formatBytes(task.totalBytes)}',
                  style: Theme.of(sheetContext).textTheme.bodySmall,
                ),
                if (task.failure != null) ...[
                  const SizedBox(height: AppSpacing.small),
                  Text(
                    task.failure!.message,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
                const Divider(),
                if (task.state == DownloadState.downloading)
                  ListTile(
                    leading: const Icon(Icons.pause),
                    title: const Text('Pause download'),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      unawaited(controller.pauseDownload(task.id));
                    },
                  ),
                if (task.state == DownloadState.paused)
                  ListTile(
                    leading: const Icon(Icons.play_arrow),
                    title: const Text('Resume download'),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      unawaited(controller.resumeDownload(task.id));
                    },
                  ),
                if (task.state == DownloadState.failed ||
                    task.state == DownloadState.expired)
                  ListTile(
                    leading: const Icon(Icons.refresh),
                    title: const Text('Retry download'),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      unawaited(controller.retryDownload(task.id));
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text(
                    'Delete download',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    unawaited(controller.deleteDownload(task.id));
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
