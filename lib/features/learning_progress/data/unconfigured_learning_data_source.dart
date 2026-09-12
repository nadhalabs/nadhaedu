import 'package:learning_platform/features/learning_progress/data/learning_data_source.dart';
import 'package:learning_platform/features/learning_progress/domain/learning_progress.dart';
import 'package:learning_platform/features/learning_progress/domain/playback_source.dart';

final class UnconfiguredLearningDataSource implements LearningDataSource {
  const UnconfiguredLearningDataSource();

  Never _fail() => throw const LearningDataException(
    LearningDataErrorKind.server,
    'Learning service is not configured.',
  );

  @override
  Future<CourseProgress> fetchProgress(
    String learnerId,
    String courseId,
  ) async => _fail();

  @override
  Future<PlaybackSource> fetchPlaybackSource(
    String learnerId,
    String assetId,
  ) async => _fail();

  @override
  Future<ProgressSyncResult> synchronizeProgress(
    String learnerId,
    String courseId,
    List<ProgressMutation> mutations,
  ) async => _fail();
}
