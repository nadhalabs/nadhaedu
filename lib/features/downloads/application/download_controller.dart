import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_platform/features/downloads/application/download_manager.dart';
import 'package:learning_platform/features/downloads/domain/download_network_policy.dart';
import 'package:learning_platform/features/downloads/domain/download_repository.dart';
import 'package:learning_platform/features/downloads/domain/download_task.dart';

final class DownloadController
    extends StateNotifier<AsyncValue<List<DownloadTask>>> {
  DownloadController({
    required DownloadRepository repository,
    required DownloadManager downloadManager,
    required String learnerId,
  }) : _repository = repository,
       _downloadManager = downloadManager,
       _learnerId = learnerId,
       super(const AsyncValue.loading()) {
    unawaited(_init());
  }

  final DownloadRepository _repository;
  final DownloadManager _downloadManager;
  final String _learnerId;
  StreamSubscription<DownloadTask>? _updateSubscription;

  Future<void> _init() async {
    _updateSubscription = _downloadManager.taskUpdates.listen((updatedTask) {
      if (!mounted) return;
      if (updatedTask.learnerId == _learnerId) {
        state.whenData((tasks) {
          final existingIndex = tasks.indexWhere((t) => t.id == updatedTask.id);
          if (existingIndex >= 0) {
            final updatedList = [...tasks];
            updatedList[existingIndex] = updatedTask;
            if (mounted) state = AsyncValue.data(updatedList);
          } else {
            if (mounted) state = AsyncValue.data([updatedTask, ...tasks]);
          }
        });
      }
    });

    await _downloadManager.recoverInterruptedDownloads(_learnerId);
    if (mounted) {
      final result = await AsyncValue.guard(
        () => _repository.getAllTasks(_learnerId),
      );
      if (mounted) {
        state = result;
      }
    }
  }

  Future<void> loadTasks() async {
    if (!mounted) return;
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(
      () => _repository.getAllTasks(_learnerId),
    );
    if (mounted) {
      state = result;
    }
  }

  Future<DownloadTask> startDownload({
    required DownloadResourceType resourceType,
    required String resourceId,
    required String courseId,
    String? lessonId,
    required String title,
    required String courseTitle,
    DownloadQuality quality = DownloadQuality.standard,
  }) async {
    final task = await _downloadManager.enqueueDownload(
      learnerId: _learnerId,
      resourceType: resourceType,
      resourceId: resourceId,
      courseId: courseId,
      lessonId: lessonId,
      title: title,
      courseTitle: courseTitle,
      quality: quality,
    );
    await loadTasks();
    return task;
  }

  Future<void> pauseDownload(String taskId) async {
    await _downloadManager.pauseDownload(_learnerId, taskId);
    await loadTasks();
  }

  Future<void> resumeDownload(String taskId) async {
    await _downloadManager.resumeDownload(_learnerId, taskId);
    await loadTasks();
  }

  Future<void> cancelDownload(String taskId) async {
    await _downloadManager.cancelDownload(_learnerId, taskId);
    await loadTasks();
  }

  Future<void> retryDownload(String taskId) async {
    await _downloadManager.retryDownload(_learnerId, taskId);
    await loadTasks();
  }

  Future<void> deleteDownload(String taskId) async {
    await _downloadManager.deleteDownload(_learnerId, taskId);
    await loadTasks();
  }

  Future<void> deleteCourseDownloads(String courseId) async {
    await _repository.deleteTasksForCourse(_learnerId, courseId);
    await loadTasks();
  }

  Future<void> clearAllDownloads() async {
    await _repository.deleteAllTasks(_learnerId);
    await loadTasks();
  }

  Future<void> revalidateAllDownloads() async {
    final tasks =
        state.valueOrNull ?? await _repository.getAllTasks(_learnerId);
    final resourceIds = tasks.map((t) => t.resourceId).toList(growable: false);
    if (resourceIds.isEmpty) return;

    await _repository.revalidateDownloads(
      learnerId: _learnerId,
      resourceIds: resourceIds,
    );
    await loadTasks();
  }

  Future<void> setNetworkPreference(
    NetworkDownloadPreference preference,
  ) async {
    final current = await _repository.getNetworkPolicy();
    final updated = current.copyWith(preference: preference);
    await _repository.setNetworkPolicy(updated);
  }

  @override
  void dispose() {
    final sub = _updateSubscription;
    if (sub != null) {
      unawaited(sub.cancel());
    }
    super.dispose();
  }
}
