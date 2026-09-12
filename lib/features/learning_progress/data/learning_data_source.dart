import 'package:learning_platform/features/learning_progress/domain/learning_progress.dart';
import 'package:learning_platform/features/learning_progress/domain/playback_source.dart';

enum LearningDataErrorKind { offline, timeout, server, notFound, unauthorized }

final class LearningDataException implements Exception {
  const LearningDataException(this.kind, this.message);
  final LearningDataErrorKind kind;
  final String message;
}

final class ProgressSyncResult {
  const ProgressSyncResult({
    required this.progress,
    required this.acknowledgedMutationIds,
  });
  final CourseProgress progress;
  final Set<String> acknowledgedMutationIds;
}

abstract interface class LearningDataSource {
  Future<CourseProgress> fetchProgress(String learnerId, String courseId);
  Future<ProgressSyncResult> synchronizeProgress(
    String learnerId,
    String courseId,
    List<ProgressMutation> mutations,
  );
  Future<PlaybackSource> fetchPlaybackSource(String learnerId, String assetId);
}
