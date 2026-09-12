import 'package:learning_platform/features/entitlements/data/entitlement_data_source.dart';
import 'package:learning_platform/features/entitlements/domain/access_policy.dart';
import 'package:learning_platform/features/entitlements/domain/resource_type.dart';
import 'package:learning_platform/features/learning_progress/data/learning_data_source.dart';
import 'package:learning_platform/features/learning_progress/domain/learning_progress.dart';
import 'package:learning_platform/features/learning_progress/domain/playback_source.dart';

/// Deterministic development adapter with server-authoritative entitlement enforcement.
final class FoundationLearningDataSource implements LearningDataSource {
  FoundationLearningDataSource({EntitlementDataSource? entitlementDataSource})
    : _entitlementDataSource = entitlementDataSource;

  final EntitlementDataSource? _entitlementDataSource;
  final Map<String, CourseProgress> _progressByLearnerCourse = {};
  final Set<String> _processedMutationIds = {};

  static final Map<String, _PlaybackResource> _playbackResources = {
    for (var index = 0; index < 36; index++)
      'video-$index-1': _PlaybackResource(
        lessonId: 'lesson-$index-1',
        courseId: 'course-${index + 1}',
        policy: const AccessPolicy.preview(),
        categoryIds: {_categoryIds[index % _categoryIds.length]},
      ),
    'video-protected-course-4-lesson-2': const _PlaybackResource(
      lessonId: 'lesson-3-2',
      courseId: 'course-4',
      policy: AccessPolicy.premium(),
      categoryIds: {'business'},
    ),
  };
  static const _categoryIds = [
    'development',
    'design',
    'business',
    'data',
    'wellbeing',
  ];

  String _key(String learnerId, String courseId) => '$learnerId::$courseId';

  @override
  Future<CourseProgress> fetchProgress(
    String learnerId,
    String courseId,
  ) async =>
      _progressByLearnerCourse[_key(learnerId, courseId)] ??
      CourseProgress.empty(courseId);

  @override
  Future<ProgressSyncResult> synchronizeProgress(
    String learnerId,
    String courseId,
    List<ProgressMutation> mutations,
  ) async {
    final key = _key(learnerId, courseId);
    var progress =
        _progressByLearnerCourse[key] ?? CourseProgress.empty(courseId);
    final accepted = <ProgressMutation>[];
    for (final mutation in mutations) {
      if (_processedMutationIds.add('$learnerId::${mutation.id}')) {
        accepted.add(mutation);
      }
    }
    if (accepted.isNotEmpty) {
      progress = ProgressReconciler.reconcile(
        progress,
        accepted,
      ).copyWith(serverRevision: progress.serverRevision + 1);
      _progressByLearnerCourse[key] = progress;
    }
    return ProgressSyncResult(
      progress: progress,
      acknowledgedMutationIds: mutations.map((item) => item.id).toSet(),
    );
  }

  @override
  Future<PlaybackSource> fetchPlaybackSource(
    String learnerId,
    String assetId,
  ) async {
    final resource = _playbackResources[assetId];
    if (resource == null) {
      throw const LearningDataException(
        LearningDataErrorKind.notFound,
        'Playback resource not found.',
      );
    }

    if (!resource.policy.isFree && !resource.policy.isPreview) {
      final entitlementDataSource = _entitlementDataSource;
      if (entitlementDataSource == null) {
        throw const LearningDataException(
          LearningDataErrorKind.unauthorized,
          'Playback authorization service is unavailable.',
        );
      }
      final isAuthorized = await entitlementDataSource.verifyAccess(
        learnerId: learnerId,
        resourceType: ResourceType.lesson,
        targetId: resource.lessonId,
        effectivePolicy: resource.policy,
        categoryIds: resource.categoryIds,
        courseId: resource.courseId,
      );
      if (!isAuthorized) {
        throw const LearningDataException(
          LearningDataErrorKind.unauthorized,
          'Unauthorized: Active entitlement required for protected stream.',
        );
      }
    }

    return PlaybackSource(
      streamUri: Uri.parse(
        'https://devstreaming-cdn.apple.com/videos/streaming/examples/'
        'img_bipbop_adv_example_ts/master.m3u8',
      ),
      kind: PlaybackStreamKind.hls,
      subtitles: const [],
    );
  }
}

final class _PlaybackResource {
  const _PlaybackResource({
    required this.lessonId,
    required this.courseId,
    required this.policy,
    required this.categoryIds,
  });

  final String lessonId;
  final String courseId;
  final AccessPolicy policy;
  final Set<String> categoryIds;
}
