import 'package:learning_platform/features/learning_progress/domain/learning_progress.dart';
import 'package:learning_platform/features/learning_progress/domain/playback_source.dart';

abstract interface class LearningRepository {
  Future<CourseProgress> loadProgress(String courseId);
  Future<CourseProgress> recordPosition({
    required String courseId,
    required String lessonId,
    required Duration position,
    required Duration duration,
    required DateTime occurredAt,
  });
  Future<CourseProgress> setCompleted({
    required String courseId,
    required String lessonId,
    required bool completed,
    required Duration position,
    required Duration duration,
    required DateTime occurredAt,
  });
  Future<CourseProgress> synchronize(String courseId);
  Future<PlaybackSource> getPlaybackSource(String assetId);
  Future<List<LearningHistoryEntry>> getHistory({int limit = 50});
}
