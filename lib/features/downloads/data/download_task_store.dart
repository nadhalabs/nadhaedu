import 'dart:convert';

import 'package:learning_platform/core/persistence/key_value_store.dart';
import 'package:learning_platform/features/downloads/domain/download_task.dart';

final class DownloadTaskStore {
  DownloadTaskStore(this._store);
  final KeyValueStore _store;

  final Map<String, Map<String, DownloadTask>> _tasksByLearner = {};
  final Map<String, Map<String, String>> _resourceIdToTaskIdByLearner = {};
  final Map<String, Map<String, Set<String>>> _courseIdToTaskIdsByLearner = {};
  final Set<String> _loadedLearners = {};

  String _key(String learnerId) => 'downloads.tasks.v1.$learnerId';

  Future<void> ensureLoaded(String learnerId) async {
    if (_loadedLearners.contains(learnerId)) return;
    final raw = await _store.readString(_key(learnerId));
    final tasks = <String, DownloadTask>{};
    final byResource = <String, String>{};
    final byCourse = <String, Set<String>>{};

    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map<String, Object?>) {
              try {
                final task = DownloadTask.fromJson(item);
                tasks[task.id] = task;
                byResource[task.resourceId] = task.id;
                byCourse
                    .putIfAbsent(task.courseId, () => <String>{})
                    .add(task.id);
              } on Object catch (_) {
                // Ignore invalid entries during schema migration
              }
            }
          }
        }
      } on Object catch (_) {
        // Fallback to empty on parse failure
      }
    }

    _tasksByLearner[learnerId] = tasks;
    _resourceIdToTaskIdByLearner[learnerId] = byResource;
    _courseIdToTaskIdsByLearner[learnerId] = byCourse;
    _loadedLearners.add(learnerId);
  }

  Future<List<DownloadTask>> getAll(String learnerId) async {
    await ensureLoaded(learnerId);
    return (_tasksByLearner[learnerId]?.values.toList() ?? [])
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<DownloadTask?> getById(String learnerId, String taskId) async {
    await ensureLoaded(learnerId);
    return _tasksByLearner[learnerId]?[taskId];
  }

  Future<DownloadTask?> getByResourceId(
    String learnerId,
    String resourceId,
  ) async {
    await ensureLoaded(learnerId);
    final taskId = _resourceIdToTaskIdByLearner[learnerId]?[resourceId];
    if (taskId == null) return null;
    return _tasksByLearner[learnerId]?[taskId];
  }

  Future<List<DownloadTask>> getByCourseId(
    String learnerId,
    String courseId,
  ) async {
    await ensureLoaded(learnerId);
    final taskIds = _courseIdToTaskIdsByLearner[learnerId]?[courseId];
    if (taskIds == null) return const [];
    final tasks = _tasksByLearner[learnerId];
    if (tasks == null) return const [];
    return taskIds.map((id) => tasks[id]).whereType<DownloadTask>().toList();
  }

  Future<void> save(DownloadTask task) async {
    await ensureLoaded(task.learnerId);
    final tasks = _tasksByLearner.putIfAbsent(task.learnerId, () => {});
    final byResource = _resourceIdToTaskIdByLearner.putIfAbsent(
      task.learnerId,
      () => {},
    );
    final byCourse = _courseIdToTaskIdsByLearner.putIfAbsent(
      task.learnerId,
      () => {},
    );

    tasks[task.id] = task;
    byResource[task.resourceId] = task.id;
    byCourse.putIfAbsent(task.courseId, () => <String>{}).add(task.id);

    if (tasks.length > 200) {
      final prunable =
          tasks.values.where((t) => !t.isActive && !t.isCompleted).toList()
            ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
      final excess = tasks.length - 200;
      for (final t in prunable.take(excess)) {
        tasks.remove(t.id);
        byResource.remove(t.resourceId);
        byCourse[t.courseId]?.remove(t.id);
      }
    }

    await _flush(task.learnerId);
  }

  Future<void> remove(String learnerId, String taskId) async {
    await ensureLoaded(learnerId);
    final task = _tasksByLearner[learnerId]?.remove(taskId);
    if (task != null) {
      _resourceIdToTaskIdByLearner[learnerId]?.remove(task.resourceId);
      _courseIdToTaskIdsByLearner[learnerId]?[task.courseId]?.remove(taskId);
      await _flush(learnerId);
    }
  }

  Future<void> removeForCourse(String learnerId, String courseId) async {
    await ensureLoaded(learnerId);
    final taskIds = _courseIdToTaskIdsByLearner[learnerId]?.remove(courseId);
    if (taskIds != null) {
      final tasks = _tasksByLearner[learnerId];
      final byResource = _resourceIdToTaskIdByLearner[learnerId];
      for (final id in taskIds) {
        final task = tasks?.remove(id);
        if (task != null) {
          byResource?.remove(task.resourceId);
        }
      }
      await _flush(learnerId);
    }
  }

  Future<void> removeAll(String learnerId) async {
    _tasksByLearner[learnerId]?.clear();
    _resourceIdToTaskIdByLearner[learnerId]?.clear();
    _courseIdToTaskIdsByLearner[learnerId]?.clear();
    await _store.remove(_key(learnerId));
  }

  Future<void> _flush(String learnerId) async {
    final tasks = _tasksByLearner[learnerId]?.values.toList() ?? [];
    final jsonList = tasks.map((t) => t.toJson()).toList(growable: false);
    await _store.writeString(_key(learnerId), jsonEncode(jsonList));
  }
}
