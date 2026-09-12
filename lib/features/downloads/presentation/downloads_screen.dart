import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_platform/core/motion/app_motion.dart';
import 'package:learning_platform/core/routing/app_router.dart';
import 'package:learning_platform/core/theme/app_spacing.dart';
import 'package:learning_platform/core/theme/app_tokens.dart';
import 'package:learning_platform/core/widgets/content_states.dart';
import 'package:learning_platform/core/widgets/learning_feedback.dart';
import 'package:learning_platform/features/downloads/application/download_providers.dart';
import 'package:learning_platform/features/downloads/domain/download_network_policy.dart';
import 'package:learning_platform/features/downloads/domain/download_task.dart';
import 'package:learning_platform/features/downloads/domain/storage_summary.dart';

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksState = ref.watch(downloadControllerProvider);
    final storageState = ref.watch(storageSummaryProvider);
    final policyState = ref.watch(downloadNetworkPolicyProvider);
    final controller = ref.read(downloadControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloads'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Revalidate offline access',
            onPressed: () => unawaited(controller.revalidateAllDownloads()),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear all downloads',
            onPressed: () => _confirmClearAll(context, ref),
          ),
        ],
      ),
      body: tasksState.when(
        loading: () => const LoadingView(label: 'Loading downloads'),
        error: (err, _) =>
            ErrorView(onAction: () => unawaited(controller.loadTasks())),
        data: (tasks) {
          if (tasks.isEmpty) {
            return MessageView(
              icon: Icons.download_outlined,
              title: 'No downloaded content',
              message:
                  'Take a lesson with you. Choose a course, then tap its download button.',
              actionLabel: 'Explore courses',
              onAction: () => context.go(AppRoutes.discover),
            );
          }

          final activeTasks = tasks
              .where((t) => t.isActive || t.isPaused)
              .toList();
          final completedTasks = tasks.where((t) => t.isCompleted).toList();
          final failedTasks = tasks
              .where((t) => t.isFailed || t.state == DownloadState.expired)
              .toList();

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.medium),
            children: [
              // Storage Breakdown Card
              storageState.when(
                data: (storage) => _StorageCard(storage: storage),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
              const SizedBox(height: AppSpacing.medium),

              // Network Policy Toggle
              policyState.when(
                data: (policy) => Card(
                  child: SwitchListTile(
                    title: const Text('Download over Wi-Fi only'),
                    subtitle: const Text(
                      'Prevent cellular data usage for media downloads',
                    ),
                    value:
                        policy.preference == NetworkDownloadPreference.wifiOnly,
                    onChanged: (val) {
                      unawaited(
                        controller.setNetworkPreference(
                          val
                              ? NetworkDownloadPreference.wifiOnly
                              : NetworkDownloadPreference.allowCellular,
                        ),
                      );
                      ref.invalidate(downloadNetworkPolicyProvider);
                    },
                  ),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
              const SizedBox(height: AppSpacing.medium),

              // Active Downloads Section
              if (activeTasks.isNotEmpty) ...[
                Text(
                  'In Progress (${activeTasks.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.small),
                ...activeTasks.map((t) => _ActiveDownloadTile(task: t)),
                const SizedBox(height: AppSpacing.medium),
              ],

              // Failed / Expired Downloads Section
              if (failedTasks.isNotEmpty) ...[
                Text(
                  'Needs Attention (${failedTasks.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.small),
                ...failedTasks.map((t) => _FailedDownloadTile(task: t)),
                const SizedBox(height: AppSpacing.medium),
              ],

              // Completed Downloads Grouped by Course
              if (completedTasks.isNotEmpty) ...[
                Text(
                  'Downloaded Courses',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.small),
                _CourseGroupedDownloads(completedTasks: completedTasks),
              ],
            ],
          );
        },
      ),
    );
  }

  void _confirmClearAll(BuildContext context, WidgetRef ref) {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Clear all downloads?'),
          content: const Text(
            'This will delete all offline media and files from your device. You can download them again whenever you are online.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                unawaited(
                  ref
                      .read(downloadControllerProvider.notifier)
                      .clearAllDownloads(),
                );
              },
              child: const Text('Clear All'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StorageCard extends StatelessWidget {
  const _StorageCard({required this.storage});
  final StorageSummary storage;

  @override
  Widget build(BuildContext context) {
    final usedFraction = storage.totalDeviceBytes > 0
        ? (storage.totalBytesUsed / storage.totalDeviceBytes).clamp(0.0, 1.0)
        : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: AppSpacing.medium,
              runSpacing: AppSpacing.small,
              children: [
                Text(
                  'Device Storage',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  '${StorageSummary.formatBytes(storage.totalBytesUsed)} used',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.small),
            LearningProgress(
              value: usedFraction,
              label: 'Device storage used',
              trackColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            const SizedBox(height: AppSpacing.small),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: AppSpacing.medium,
              runSpacing: AppSpacing.small,
              children: [
                Text(
                  '${storage.completedTasksCount} items downloaded',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  '${StorageSummary.formatBytes(storage.availableDeviceBytes)} free',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveDownloadTile extends ConsumerWidget {
  const _ActiveDownloadTile({required this.task});
  final DownloadTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(downloadControllerProvider.notifier);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.small),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        task.courseTitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (task.state == DownloadState.downloading)
                  IconButton(
                    icon: const Icon(Icons.pause),
                    tooltip: 'Pause',
                    onPressed: () =>
                        unawaited(controller.pauseDownload(task.id)),
                  )
                else if (task.state == DownloadState.paused)
                  IconButton(
                    icon: const Icon(Icons.play_arrow),
                    tooltip: 'Resume',
                    onPressed: () =>
                        unawaited(controller.resumeDownload(task.id)),
                  ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Cancel',
                  onPressed: () =>
                      unawaited(controller.cancelDownload(task.id)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.small),
            if (task.totalBytes > 0)
              LearningProgress(value: task.progress, label: 'Download progress')
            else
              LinearProgressIndicator(
                value: AppMotion.reduced(context) ? 0 : null,
              ),
            const SizedBox(height: AppSpacing.xSmall),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: AppSpacing.medium,
              runSpacing: AppSpacing.small,
              children: [
                Text(
                  task.state == DownloadState.preparing
                      ? 'Preparing...'
                      : task.state == DownloadState.paused
                      ? 'Paused'
                      : '${(task.progress * 100).round()}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  '${StorageSummary.formatBytes(task.bytesDownloaded)} / ${StorageSummary.formatBytes(task.totalBytes)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FailedDownloadTile extends ConsumerWidget {
  const _FailedDownloadTile({required this.task});
  final DownloadTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(downloadControllerProvider.notifier);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.small),
      child: ListTile(
        leading: Icon(
          task.state == DownloadState.expired
              ? Icons.history
              : Icons.error_outline,
          color: Theme.of(context).brightness == Brightness.dark
              ? AppPalette.coral
              : AppPalette.review,
        ),
        title: Text(task.title),
        subtitle: Text(
          task.failure?.message ??
              (task.state == DownloadState.expired
                  ? 'Offline lease expired. Reconnect to renew.'
                  : 'Download failed.'),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Retry',
              onPressed: () => unawaited(controller.retryDownload(task.id)),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: () => unawaited(controller.deleteDownload(task.id)),
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseGroupedDownloads extends ConsumerWidget {
  const _CourseGroupedDownloads({required this.completedTasks});
  final List<DownloadTask> completedTasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(downloadControllerProvider.notifier);
    final byCourse = <String, List<DownloadTask>>{};
    for (final t in completedTasks) {
      byCourse.putIfAbsent(t.courseId, () => []).add(t);
    }

    return Column(
      children: byCourse.entries.map((entry) {
        final courseId = entry.key;
        final courseTasks = entry.value;
        final courseTitle = courseTasks.first.courseTitle;
        final courseBytes = courseTasks.fold<int>(
          0,
          (sum, t) => sum + t.bytesDownloaded,
        );

        return Card(
          margin: const EdgeInsets.only(bottom: AppSpacing.medium),
          child: ExpansionTile(
            title: Text(courseTitle),
            subtitle: Text(
              '${courseTasks.length} lessons • ${StorageSummary.formatBytes(courseBytes)}',
            ),
            trailing: IconButton(
              icon: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              tooltip: 'Delete all downloads for this course',
              onPressed: () =>
                  _confirmDeleteCourse(context, ref, courseId, courseTitle),
            ),
            children: courseTasks.map((task) {
              return ListTile(
                leading: const Icon(Icons.play_circle_outline),
                title: Text(task.title),
                subtitle: Text(
                  '${StorageSummary.formatBytes(task.bytesDownloaded)} • ${task.isOfflineEntitlementValid ? 'Available offline' : 'Access expired'}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete lesson download',
                  onPressed: () =>
                      unawaited(controller.deleteDownload(task.id)),
                ),
                onTap: () {
                  unawaited(
                    context.push(
                      AppRoutes.learn(task.courseId, lessonId: task.lessonId),
                    ),
                  );
                },
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  void _confirmDeleteCourse(
    BuildContext context,
    WidgetRef ref,
    String courseId,
    String courseTitle,
  ) {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: Text('Delete downloads for $courseTitle?'),
          content: const Text(
            'All downloaded lessons for this course will be removed from your device.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                unawaited(
                  ref
                      .read(downloadControllerProvider.notifier)
                      .deleteCourseDownloads(courseId),
                );
              },
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
    );
  }
}
