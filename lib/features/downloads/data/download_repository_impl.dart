import 'dart:convert';

import 'package:learning_platform/core/persistence/key_value_store.dart';
import 'package:learning_platform/features/downloads/data/download_data_source.dart';
import 'package:learning_platform/features/downloads/data/download_file_manager.dart';
import 'package:learning_platform/features/downloads/data/download_task_store.dart';
import 'package:learning_platform/features/downloads/domain/download_authorization.dart';
import 'package:learning_platform/features/downloads/domain/download_network_policy.dart';
import 'package:learning_platform/features/downloads/domain/download_repository.dart';
import 'package:learning_platform/features/downloads/domain/download_task.dart';
import 'package:learning_platform/features/downloads/domain/storage_summary.dart';

final class DownloadRepositoryImpl implements DownloadRepository {
  DownloadRepositoryImpl({
    required DownloadDataSource remote,
    required DownloadTaskStore taskStore,
    required DownloadFileManager fileManager,
    required KeyValueStore preferencesStore,
  }) : _remote = remote,
       _taskStore = taskStore,
       _fileManager = fileManager,
       _preferencesStore = preferencesStore;

  final DownloadDataSource _remote;
  final DownloadTaskStore _taskStore;
  final DownloadFileManager _fileManager;
  final KeyValueStore _preferencesStore;

  static const _networkPolicyKey = 'downloads.network_policy.v1';

  @override
  Future<List<DownloadTask>> getAllTasks(String learnerId) async {
    final tasks = await _taskStore.getAll(learnerId);
    return _validateTasks(tasks);
  }

  @override
  Future<DownloadTask?> getTask(String learnerId, String taskId) async {
    final task = await _taskStore.getById(learnerId, taskId);
    if (task == null) return null;
    return (await _validateTasks([task])).firstOrNull;
  }

  @override
  Future<DownloadTask?> getTaskByResourceId(
    String learnerId,
    String resourceId,
  ) async {
    final task = await _taskStore.getByResourceId(learnerId, resourceId);
    if (task == null) return null;
    return (await _validateTasks([task])).firstOrNull;
  }

  @override
  Future<List<DownloadTask>> getTasksByCourseId(
    String learnerId,
    String courseId,
  ) async {
    final tasks = await _taskStore.getByCourseId(learnerId, courseId);
    return _validateTasks(tasks);
  }

  @override
  Future<void> saveTask(DownloadTask task) => _taskStore.save(task);

  @override
  Future<void> deleteTask(String learnerId, String taskId) async {
    final task = await _taskStore.getById(learnerId, taskId);
    if (task != null) {
      if (task.localRelativePath != null) {
        await _fileManager.deleteFile(task.localRelativePath!);
      }
      for (final sub in task.subtitles) {
        await _fileManager.deleteFile(sub.localRelativePath);
      }
      await _taskStore.remove(learnerId, taskId);
    }
  }

  @override
  Future<void> deleteTasksForCourse(String learnerId, String courseId) async {
    final tasks = await _taskStore.getByCourseId(learnerId, courseId);
    for (final task in tasks) {
      if (task.localRelativePath != null) {
        await _fileManager.deleteFile(task.localRelativePath!);
      }
      for (final sub in task.subtitles) {
        await _fileManager.deleteFile(sub.localRelativePath);
      }
    }
    await _taskStore.removeForCourse(learnerId, courseId);
  }

  @override
  Future<void> deleteAllTasks(String learnerId) async {
    final tasks = await _taskStore.getAll(learnerId);
    for (final task in tasks) {
      if (task.localRelativePath != null) {
        await _fileManager.deleteFile(task.localRelativePath!);
      }
      for (final sub in task.subtitles) {
        await _fileManager.deleteFile(sub.localRelativePath);
      }
    }
    await _taskStore.removeAll(learnerId);
  }

  @override
  Future<DownloadAuthorization> requestDownloadAuthorization({
    required String learnerId,
    required DownloadResourceType resourceType,
    required String resourceId,
    DownloadQuality quality = DownloadQuality.standard,
  }) => _remote.fetchDownloadAuthorization(
    learnerId: learnerId,
    resourceType: resourceType,
    resourceId: resourceId,
    quality: quality,
  );

  @override
  Future<List<DownloadRevalidationResult>> revalidateDownloads({
    required String learnerId,
    required List<String> resourceIds,
  }) async {
    final results = await _remote.revalidateDownloads(
      learnerId: learnerId,
      resourceIds: resourceIds,
    );

    // Update stored tasks with revalidation results
    for (final res in results) {
      final task = await _taskStore.getByResourceId(learnerId, res.resourceId);
      if (task != null) {
        if (res.status == RevalidationStatus.valid) {
          final updated = task.copyWith(
            state: task.isCompleted
                ? DownloadState.completed
                : (task.state == DownloadState.expired
                      ? DownloadState.paused
                      : task.state),
            entitlementExpiresAt: res.entitlementExpiresAt,
            assetVersion: res.assetVersion ?? task.assetVersion,
            clearFailure: true,
          );
          await _taskStore.save(updated);
        } else if (res.status == RevalidationStatus.expired ||
            res.status == RevalidationStatus.revoked) {
          final updated = task.copyWith(
            state: DownloadState.expired,
            failure: DownloadFailure(
              reason: DownloadFailureReason.entitlementExpired,
              message: res.message,
              retryable: false,
            ),
          );
          await _taskStore.save(updated);
        }
      }
    }

    return results;
  }

  @override
  Future<StorageSummary> getStorageSummary(String learnerId) async {
    final tasks = await _taskStore.getAll(learnerId);
    var totalBytes = 0;
    var completedCount = 0;
    final byCourse =
        <String, (String, int, int, int)>{}; // title, bytes, total, completed

    for (final task in tasks) {
      final size = task.isCompleted ? task.bytesDownloaded : 0;
      totalBytes += size;
      if (task.isCompleted) completedCount++;

      final existing = byCourse[task.courseId];
      if (existing == null) {
        byCourse[task.courseId] = (
          task.courseTitle,
          size,
          1,
          task.isCompleted ? 1 : 0,
        );
      } else {
        byCourse[task.courseId] = (
          existing.$1,
          existing.$2 + size,
          existing.$3 + 1,
          existing.$4 + (task.isCompleted ? 1 : 0),
        );
      }
    }

    final courses = byCourse.entries
        .map(
          (e) => CourseStorageUsage(
            courseId: e.key,
            courseTitle: e.value.$1,
            bytesUsed: e.value.$2,
            taskCount: e.value.$3,
            completedCount: e.value.$4,
          ),
        )
        .toList(growable: false);

    final availableSpace = await _fileManager.getAvailableDiskSpace();

    return StorageSummary(
      totalBytesUsed: totalBytes,
      availableDeviceBytes: availableSpace,
      totalDeviceBytes: availableSpace + totalBytes,
      courses: courses,
      totalTasksCount: tasks.length,
      completedTasksCount: completedCount,
    );
  }

  @override
  Future<DownloadNetworkPolicy> getNetworkPolicy() async {
    final raw = await _preferencesStore.readString(_networkPolicyKey);
    if (raw == null || raw.isEmpty) return const DownloadNetworkPolicy();
    try {
      final json = jsonDecode(raw);
      if (json is Map<String, Object?>) {
        return DownloadNetworkPolicy.fromJson(json);
      }
      return const DownloadNetworkPolicy();
    } on Object catch (_) {
      return const DownloadNetworkPolicy();
    }
  }

  @override
  Future<void> setNetworkPolicy(DownloadNetworkPolicy policy) async {
    await _preferencesStore.writeString(
      _networkPolicyKey,
      jsonEncode(policy.toJson()),
    );
  }

  Future<List<DownloadTask>> _validateTasks(List<DownloadTask> tasks) async {
    final validated = <DownloadTask>[];
    for (final task in tasks) {
      if (task.isCompleted && task.localRelativePath != null) {
        final exists = await _fileManager.fileExists(task.localRelativePath!);
        if (!exists) {
          // File was deleted outside the app
          final updated = task.copyWith(
            state: DownloadState.failed,
            failure: const DownloadFailure(
              reason: DownloadFailureReason.integrityFailure,
              message: 'Local download file is missing.',
              retryable: true,
            ),
          );
          await _taskStore.save(updated);
          validated.add(updated);
          continue;
        }
      }
      validated.add(task);
    }
    return validated;
  }
}
