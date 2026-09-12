import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_platform/bootstrap/providers.dart';
import 'package:learning_platform/core/errors/result.dart';
import 'package:learning_platform/core/networking/api_client.dart';
import 'package:learning_platform/features/content_protection/domain/content_protection_policy.dart';
import 'package:learning_platform/features/downloads/application/download_providers.dart';
import 'package:learning_platform/features/downloads/domain/download_repository.dart';
import 'package:learning_platform/features/downloads/domain/download_task.dart';
import 'package:learning_platform/features/learning_progress/application/learning_providers.dart';
import 'package:learning_platform/features/learning_progress/domain/learning_repository.dart';
import 'package:learning_platform/features/learning_progress/domain/playback_source.dart';
import 'package:learning_platform/features/learning_progress/presentation/video_lesson_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

class PlayerPlatform extends VideoPlayerPlatform {
  Duration position = Duration.zero;
  String? url;
  @override
  Future<void> init() async {}
  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
  @override
  Future<int?> create(DataSource dataSource) async {
    url = dataSource.uri;
    return 1;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => Stream.value(
    VideoEvent(
      eventType: VideoEventType.initialized,
      duration: const Duration(seconds: 100),
      size: const Size(1600, 900),
    ),
  );
  @override
  Future<void> dispose(int playerId) async {}
  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> setVolume(int playerId, double volume) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<void> play(int playerId) async {}
  @override
  Future<void> pause(int playerId) async {}
  @override
  Future<void> seekTo(int playerId, Duration value) async {
    position = value;
  }

  @override
  Future<Duration> getPosition(int playerId) async => position;
  @override
  Widget buildView(int playerId) => const SizedBox();
}

class LearningFake implements LearningRepository {
  String? requested;
  bool fail = false;
  @override
  Future<PlaybackSource> getPlaybackSource(String assetId) async {
    requested = assetId;
    if (fail) throw StateError('Unavailable');
    return PlaybackSource(
      streamUri: Uri.parse('https://media.example/video.mp4'),
      kind: PlaybackStreamKind.mp4,
      subtitles: const [],
      watchProgress: true,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DownloadsFake implements DownloadRepository {
  @override
  Future<DownloadTask?> getTaskByResourceId(
    String learnerId,
    String resourceId,
  ) async => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class WatchApi implements ApiClient {
  final calls = <String>[];
  @override
  Future<Result<Map<String, Object?>>> get(
    String path, {
    Map<String, Object?> query = const {},
    bool authenticated = true,
  }) async {
    calls.add(path);
    return const Success({'positionSeconds': 30, 'furthestSeconds': 40});
  }

  @override
  Future<Result<Map<String, Object?>>> post(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, Object?> headers = const {},
    bool authenticated = true,
  }) async {
    calls.add(path);
    return const Success({
      'positionSeconds': 95,
      'furthestSeconds': 95,
      'completed': true,
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'correct asset, per-video resume, seek limit and server completion',
    (tester) async {
      final platform = PlayerPlatform();
      VideoPlayerPlatform.instance = platform;
      final learning = LearningFake();
      final api = WatchApi();
      var completions = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentLearnerIdProvider.overrideWithValue('learner'),
            learningRepositoryProvider.overrideWithValue(learning),
            downloadRepositoryProvider.overrideWithValue(DownloadsFake()),
            apiClientProvider.overrideWithValue(api),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 320,
                child: VideoLessonPlayer(
                  assetId: 'second-video',
                  initialPosition: const Duration(seconds: 80),
                  policy: ContentProtectionPolicy.none,
                  onProgress: (_, _) async =>
                      fail('Must use authoritative per-video progress'),
                  onFlush: () async {
                    completions++;
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(learning.requested, 'second-video');
      expect(platform.url, 'https://media.example/video.mp4');
      expect(platform.position.inSeconds, 30);
      final slider = tester.widget<Slider>(find.byType(Slider));
      slider.onChanged!(99000);
      await tester.pump();
      expect(platform.position.inSeconds, 42);
      await tester.pump(const Duration(seconds: 10));
      await tester.pump();
      expect(completions, 1);
      expect(
        api.calls.every((path) => path.endsWith('/second-video/progress')),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('authorization failure offers retry', (tester) async {
    final learning = LearningFake()..fail = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentLearnerIdProvider.overrideWithValue('learner'),
          learningRepositoryProvider.overrideWithValue(learning),
          downloadRepositoryProvider.overrideWithValue(DownloadsFake()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: VideoLessonPlayer(
              assetId: 'missing',
              initialPosition: Duration.zero,
              policy: ContentProtectionPolicy.none,
              onProgress: (_, _) async {},
              onFlush: () async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('We couldn’t load this video.'), findsOneWidget);
  });
}
