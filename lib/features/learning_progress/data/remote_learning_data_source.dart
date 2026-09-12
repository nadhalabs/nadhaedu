import 'package:learning_platform/core/errors/result.dart';
import 'package:learning_platform/core/networking/api_client.dart';
import 'package:learning_platform/features/learning_progress/data/learning_data_source.dart';
import 'package:learning_platform/features/learning_progress/domain/learning_progress.dart';
import 'package:learning_platform/features/learning_progress/domain/playback_source.dart';

final class RemoteLearningDataSource implements LearningDataSource {
  const RemoteLearningDataSource(this._client);
  final ApiClient _client;
  @override
  Future<CourseProgress> fetchProgress(
    String learnerId,
    String courseId,
  ) async => _progress(
    await _get('/api/v1/courses/${Uri.encodeComponent(courseId)}/progress'),
  );
  @override
  Future<ProgressSyncResult> synchronizeProgress(
    String learnerId,
    String courseId,
    List<ProgressMutation> mutations,
  ) async {
    final json = await _post(
      '/api/v1/courses/${Uri.encodeComponent(courseId)}/progress/sync',
      {
        'mutations': [
          for (final m in mutations)
            {
              'id': m.id,
              'lessonId': m.lessonId,
              'kind': m.kind.name,
              'positionSeconds': m.position.inSeconds,
              'durationSeconds': m.duration.inSeconds,
              'completed': m.completed,
              'occurredAt': m.occurredAt.toUtc().toIso8601String(),
              'baseRevision': m.baseRevision,
            },
        ],
      },
    );
    return ProgressSyncResult(
      progress: _progress(_map(json, 'progress')),
      acknowledgedMutationIds: _list(
        json,
        'acknowledgedMutationIds',
      ).cast<String>().toSet(),
    );
  }

  @override
  Future<PlaybackSource> fetchPlaybackSource(
    String learnerId,
    String assetId,
  ) async {
    final json = await _get('/api/v1/playback/${Uri.encodeComponent(assetId)}');
    return PlaybackSource(
      streamUri: Uri.parse(_string(json, 'streamUrl')),
      posterUrl: json['posterUrl'] as String?,
      watchProgress: json['watchProgress'] == true,
      kind: PlaybackStreamKind.values.byName(_string(json, 'kind')),
      subtitles: _list(json, 'subtitles').map((x) {
        final j = _valueMap(x);
        return SubtitleTrack(
          id: _string(j, 'id'),
          label: _string(j, 'label'),
          languageCode: _string(j, 'languageCode'),
          uri: Uri.parse(_string(j, 'url')),
        );
      }).toList(),
    );
  }

  Future<Map<String, Object?>> _get(String p) async =>
      switch (await _client.get(p)) {
        Success(value: final v) => v,
        Failure(failure: final f) => throw _error(f),
      };
  Future<Map<String, Object?>> _post(String p, Map<String, Object?> b) async =>
      switch (await _client.post(p, body: b)) {
        Success(value: final v) => v,
        Failure(failure: final f) => throw _error(f),
      };
}

CourseProgress _progress(Map<String, Object?> j) => CourseProgress(
  courseId: _string(j, 'courseId'),
  serverRevision: j['serverRevision']! as int,
  updatedAt: DateTime.parse(_string(j, 'updatedAt')).toUtc(),
  lessons: {
    for (final e in _map(j, 'lessons').entries)
      e.key: _lesson(_valueMap(e.value)),
  },
);
LessonProgress _lesson(Map<String, Object?> j) => LessonProgress(
  lessonId: _string(j, 'lessonId'),
  position: Duration(seconds: j['positionSeconds']! as int),
  duration: Duration(seconds: j['durationSeconds']! as int),
  completed: j['completed']! as bool,
  updatedAt: DateTime.parse(_string(j, 'updatedAt')).toUtc(),
);
LearningDataException _error(Object f) => LearningDataException(
  f is ApiFailure && f.kind == ApiErrorKind.notFound
      ? LearningDataErrorKind.notFound
      : f is ApiFailure &&
            (f.kind == ApiErrorKind.authenticationRequired ||
                f.kind == ApiErrorKind.accessDenied ||
                f.kind == ApiErrorKind.entitlementRequired)
      ? LearningDataErrorKind.unauthorized
      : f is ApiFailure && f.kind == ApiErrorKind.offline
      ? LearningDataErrorKind.offline
      : f is ApiFailure && f.kind == ApiErrorKind.timeout
      ? LearningDataErrorKind.timeout
      : LearningDataErrorKind.server,
  f is ApiFailure ? f.message : 'Learning request failed.',
);
Map<String, Object?> _map(Map<String, Object?> j, String k) => _valueMap(j[k]);
Map<String, Object?> _valueMap(Object? v) =>
    Map<String, Object?>.from(v! as Map);
List<Object?> _list(Map<String, Object?> j, String k) =>
    (j[k] as List<Object?>?) ?? const [];
String _string(Map<String, Object?> j, String k) => j[k]! as String;
