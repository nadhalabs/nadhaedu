import 'dart:async';
import 'dart:convert';

import 'package:learning_platform/core/persistence/key_value_store.dart';
import 'package:learning_platform/features/learning_progress/data/learning_data_source.dart';
import 'package:learning_platform/features/learning_progress/domain/learning_progress.dart';
import 'package:learning_platform/features/learning_progress/domain/learning_repository.dart';
import 'package:learning_platform/features/learning_progress/domain/playback_source.dart';

final class LearningRepositoryImpl implements LearningRepository {
  LearningRepositoryImpl({
    required LearningDataSource remote,
    required KeyValueStore localStore,
    required String learnerId,
  }) : _remote = remote,
       _localStore = localStore,
       _learnerId = learnerId;

  static const _maxPendingMutations = 500;
  static const _maxHistoryEntries = 100;
  final LearningDataSource _remote;
  final KeyValueStore _localStore;
  final String _learnerId;
  int _mutationSequence = 0;
  Future<void> _writes = Future<void>.value();
  final Map<String, Future<CourseProgress>> _syncing = {};

  Future<T> _exclusive<T>(Future<T> Function() action) {
    final operation = _writes.then((_) => action());
    _writes = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  String get _storageKey => 'learning.progress.v1.$_learnerId';

  @override
  Future<CourseProgress> loadProgress(String courseId) async {
    try {
      final server = await _remote.fetchProgress(_learnerId, courseId);
      return _exclusive(() async {
        final local = await _readLocal();
        final reconciled = ProgressReconciler.reconcile(
          server,
          local.pending.where((item) => item.courseId == courseId),
        );
        await _writeLocal(local.withProgress(reconciled));
        return reconciled;
      });
    } on LearningDataException {
      final local = await _exclusive(_readLocal);
      final cached = local.progress[courseId];
      if (cached == null) rethrow;
      return ProgressReconciler.reconcile(
        cached,
        local.pending.where((item) => item.courseId == courseId),
      );
    }
  }

  @override
  Future<CourseProgress> recordPosition({
    required String courseId,
    required String lessonId,
    required Duration position,
    required Duration duration,
    required DateTime occurredAt,
  }) => _exclusive(
    () => _record(
      courseId: courseId,
      lessonId: lessonId,
      kind: ProgressMutationKind.position,
      position: position,
      duration: duration,
      completed: false,
      occurredAt: occurredAt,
    ),
  );

  @override
  Future<CourseProgress> setCompleted({
    required String courseId,
    required String lessonId,
    required bool completed,
    required Duration position,
    required Duration duration,
    required DateTime occurredAt,
  }) => _exclusive(
    () => _record(
      courseId: courseId,
      lessonId: lessonId,
      kind: ProgressMutationKind.completion,
      position: position,
      duration: duration,
      completed: completed,
      occurredAt: occurredAt,
    ),
  );

  Future<CourseProgress> _record({
    required String courseId,
    required String lessonId,
    required ProgressMutationKind kind,
    required Duration position,
    required Duration duration,
    required bool completed,
    required DateTime occurredAt,
  }) async {
    var local = await _readLocal();
    final baseline = local.progress[courseId] ?? CourseProgress.empty(courseId);
    final mutation = ProgressMutation(
      id: '${occurredAt.microsecondsSinceEpoch}-${_mutationSequence++}-$lessonId',
      courseId: courseId,
      lessonId: lessonId,
      kind: kind,
      position: _clamp(position, duration),
      duration: duration,
      completed: completed,
      occurredAt: occurredAt.toUtc(),
      baseRevision: baseline.serverRevision,
    );
    final pending = [...local.pending, mutation];
    if (pending.length > _maxPendingMutations) {
      // Keep durable completions; coalesce unsent playback checkpoints only.
      final latestPositions = <String, ProgressMutation>{};
      for (final item in pending) {
        if (item.kind == ProgressMutationKind.position) {
          latestPositions['${item.courseId}/${item.lessonId}'] = item;
        }
      }
      pending.removeWhere(
        (item) =>
            item.kind == ProgressMutationKind.position &&
            latestPositions['${item.courseId}/${item.lessonId}']?.id != item.id,
      );
      if (pending.length > _maxPendingMutations) {
        throw StateError('Reconnect to save more progress.');
      }
    }
    final progress = ProgressReconciler.reconcile(baseline, [mutation]);
    final history = [
      LearningHistoryEntry(
        courseId: courseId,
        lessonId: lessonId,
        visitedAt: occurredAt.toUtc(),
      ),
      ...local.history.where(
        (item) => item.courseId != courseId || item.lessonId != lessonId,
      ),
    ].take(_maxHistoryEntries).toList(growable: false);
    local = _LocalLearningState(
      progress: {...local.progress, courseId: progress},
      pending: pending,
      history: history,
    );
    await _writeLocal(local);
    return progress;
  }

  @override
  Future<CourseProgress> synchronize(String courseId) {
    if (_syncing[courseId] case final active?) return active;
    final operation = _synchronize(courseId);
    _syncing[courseId] = operation;
    return operation.whenComplete(() => _syncing.remove(courseId));
  }

  Future<CourseProgress> _synchronize(String courseId) async {
    var local = await _exclusive(_readLocal);
    final batch = local.pending
        .where((item) => item.courseId == courseId)
        .take(100)
        .toList(growable: false);
    if (batch.isEmpty) return loadProgress(courseId);
    final result = await _remote.synchronizeProgress(
      _learnerId,
      courseId,
      batch,
    );
    return _exclusive(() async {
      local = await _readLocal();
      final sentIds = batch.map((item) => item.id).toSet();
      final remaining = local.pending
          .where(
            (item) =>
                !(sentIds.contains(item.id) &&
                    result.acknowledgedMutationIds.contains(item.id)),
          )
          .toList(growable: false);
      final sameCoursePending = remaining.where(
        (item) => item.courseId == courseId,
      );
      final reconciled = ProgressReconciler.reconcile(
        result.progress,
        sameCoursePending,
      );
      local = _LocalLearningState(
        progress: {...local.progress, courseId: reconciled},
        pending: remaining,
        history: local.history,
      );
      await _writeLocal(local);
      return reconciled;
    });
  }

  @override
  Future<PlaybackSource> getPlaybackSource(String assetId) =>
      _remote.fetchPlaybackSource(_learnerId, assetId);

  @override
  Future<List<LearningHistoryEntry>> getHistory({int limit = 50}) async =>
      (await _readLocal()).history
          .take(limit.clamp(1, 100))
          .toList(growable: false);

  Duration _clamp(Duration value, Duration duration) {
    if (value < Duration.zero) return Duration.zero;
    if (duration > Duration.zero && value > duration) return duration;
    return value;
  }

  Future<_LocalLearningState> _readLocal() async {
    final encoded = await _localStore.readString(_storageKey);
    if (encoded == null) return const _LocalLearningState.empty();
    try {
      final value = jsonDecode(encoded);
      return _LocalLearningState.fromJson(value as Map<String, Object?>);
    } on Object {
      return const _LocalLearningState.empty();
    }
  }

  Future<void> _writeLocal(_LocalLearningState state) =>
      _localStore.writeString(_storageKey, jsonEncode(state.toJson()));
}

final class _LocalLearningState {
  const _LocalLearningState({
    required this.progress,
    required this.pending,
    required this.history,
  });
  const _LocalLearningState.empty()
    : progress = const {},
      pending = const [],
      history = const [];

  factory _LocalLearningState.fromJson(
    Map<String, Object?> json,
  ) => _LocalLearningState(
    progress: {
      for (final entry
          in (json['progress'] as Map<String, Object?>? ?? const {}).entries)
        entry.key: _progressFromJson(entry.value as Map<String, Object?>),
    },
    pending: (json['pending'] as List<Object?>? ?? const [])
        .map((item) => _mutationFromJson(item! as Map<String, Object?>))
        .toList(growable: false),
    history: (json['history'] as List<Object?>? ?? const [])
        .map((item) => item! as Map<String, Object?>)
        .map(
          (item) => LearningHistoryEntry(
            courseId: item['courseId']! as String,
            lessonId: item['lessonId']! as String,
            visitedAt: DateTime.parse(item['visitedAt']! as String),
          ),
        )
        .toList(growable: false),
  );

  final Map<String, CourseProgress> progress;
  final List<ProgressMutation> pending;
  final List<LearningHistoryEntry> history;

  _LocalLearningState withProgress(CourseProgress value) => _LocalLearningState(
    progress: {...progress, value.courseId: value},
    pending: pending,
    history: history,
  );

  Map<String, Object?> toJson() => {
    'progress': {
      for (final entry in progress.entries)
        entry.key: _progressToJson(entry.value),
    },
    'pending': pending.map(_mutationToJson).toList(growable: false),
    'history': [
      for (final item in history)
        {
          'courseId': item.courseId,
          'lessonId': item.lessonId,
          'visitedAt': item.visitedAt.toIso8601String(),
        },
    ],
  };
}

Map<String, Object?> _progressToJson(CourseProgress value) => {
  'courseId': value.courseId,
  'serverRevision': value.serverRevision,
  'updatedAt': value.updatedAt.toIso8601String(),
  'lessons': {
    for (final entry in value.lessons.entries)
      entry.key: {
        'lessonId': entry.value.lessonId,
        'positionMs': entry.value.position.inMilliseconds,
        'durationMs': entry.value.duration.inMilliseconds,
        'completed': entry.value.completed,
        'updatedAt': entry.value.updatedAt.toIso8601String(),
      },
  },
};

CourseProgress _progressFromJson(Map<String, Object?> json) => CourseProgress(
  courseId: json['courseId']! as String,
  serverRevision: json['serverRevision']! as int,
  updatedAt: DateTime.parse(json['updatedAt']! as String),
  lessons: {
    for (final entry in (json['lessons']! as Map<String, Object?>).entries)
      entry.key: _lessonProgressFromJson(entry.value! as Map<String, Object?>),
  },
);

LessonProgress _lessonProgressFromJson(Map<String, Object?> json) =>
    LessonProgress(
      lessonId: json['lessonId']! as String,
      position: Duration(milliseconds: json['positionMs']! as int),
      duration: Duration(milliseconds: json['durationMs']! as int),
      completed: json['completed']! as bool,
      updatedAt: DateTime.parse(json['updatedAt']! as String),
    );

Map<String, Object?> _mutationToJson(ProgressMutation value) => {
  'id': value.id,
  'courseId': value.courseId,
  'lessonId': value.lessonId,
  'kind': value.kind.name,
  'positionMs': value.position.inMilliseconds,
  'durationMs': value.duration.inMilliseconds,
  'completed': value.completed,
  'occurredAt': value.occurredAt.toIso8601String(),
  'baseRevision': value.baseRevision,
};

ProgressMutation _mutationFromJson(Map<String, Object?> json) =>
    ProgressMutation(
      id: json['id']! as String,
      courseId: json['courseId']! as String,
      lessonId: json['lessonId']! as String,
      kind: ProgressMutationKind.values.byName(json['kind']! as String),
      position: Duration(milliseconds: json['positionMs']! as int),
      duration: Duration(milliseconds: json['durationMs']! as int),
      completed: json['completed']! as bool,
      occurredAt: DateTime.parse(json['occurredAt']! as String),
      baseRevision: json['baseRevision']! as int,
    );
