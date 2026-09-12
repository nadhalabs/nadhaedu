import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_platform/bootstrap/providers.dart';
import 'package:learning_platform/core/errors/result.dart';
import 'package:learning_platform/features/content_protection/domain/content_protection_policy.dart';
import 'package:learning_platform/features/content_protection/presentation/widgets/protected_content_gate.dart';
import 'package:learning_platform/features/downloads/application/download_providers.dart';
import 'package:learning_platform/features/learning_progress/application/learning_providers.dart';
import 'package:learning_platform/features/learning_progress/domain/playback_source.dart';
import 'package:video_player/video_player.dart';

class VideoLessonPlayer extends ConsumerStatefulWidget {
  const VideoLessonPlayer({
    required this.assetId,
    required this.initialPosition,
    required this.onProgress,
    required this.onFlush,
    this.policy = ContentProtectionPolicy.blockCaptureWhereSupported,
    super.key,
  });
  final String assetId;
  final Duration initialPosition;
  final Future<void> Function(Duration position, Duration duration) onProgress;
  final Future<void> Function() onFlush;
  final ContentProtectionPolicy policy;

  @override
  ConsumerState<VideoLessonPlayer> createState() => _VideoLessonPlayerState();
}

class _VideoLessonPlayerState extends ConsumerState<VideoLessonPlayer>
    with WidgetsBindingObserver {
  static const _checkpointInterval = Duration(seconds: 5);
  static const _speeds = [0.75, 1.0, 1.25, 1.5, 2.0];
  VideoPlayerController? _controller;
  Object? _error;
  Duration _lastCheckpoint = Duration.zero;
  bool _fullscreen = false;
  OverlayEntry? _overlay;
  Timer? _watchTimer;
  bool _watchProgress = false;
  bool _sending = false;
  double _furthest = 0;
  Duration? _resume;
  String? _poster;
  bool _started = false;
  bool _captionsEnabled = true;
  bool _isOfflinePlayback = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      final learnerId = ref.read(currentLearnerIdProvider);
      final downloadTask = await ref
          .read(downloadRepositoryProvider)
          .getTaskByResourceId(learnerId, widget.assetId);

      VideoPlayerController controller;

      if (downloadTask != null && downloadTask.canPlayOffline) {
        final fileManager = ref.read(downloadFileManagerProvider);
        final fullPath = await fileManager.resolveAbsolutePath(
          downloadTask.localRelativePath!,
        );
        final file = File(fullPath);
        if (await file.exists()) {
          _isOfflinePlayback = true;
          ClosedCaptionFile? captionFile;
          if (downloadTask.subtitles.isNotEmpty) {
            try {
              final subPath = await fileManager.resolveAbsolutePath(
                downloadTask.subtitles.first.localRelativePath,
              );
              final subFile = File(subPath);
              if (await subFile.exists()) {
                final text = await subFile.readAsString();
                captionFile = WebVTTCaptionFile(text);
              }
            } on Object catch (_) {}
          }

          controller = VideoPlayerController.file(
            file,
            closedCaptionFile: captionFile != null
                ? Future.value(captionFile)
                : null,
            videoPlayerOptions: VideoPlayerOptions(
              mixWithOthers: false,
              allowBackgroundPlayback: false,
            ),
          );
        } else {
          controller = await _initRemoteController();
        }
      } else {
        controller = await _initRemoteController();
      }

      await controller.initialize();
      final resume = _resume ?? widget.initialPosition;
      if (resume > Duration.zero && resume < controller.value.duration) {
        await controller.seekTo(resume);
      }
      controller.addListener(_onPlayerChanged);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
      _watchTimer?.cancel();
      if (_watchProgress) {
        _watchTimer = Timer.periodic(
          const Duration(seconds: 10),
          (_) => unawaited(_saveWatch()),
        );
      }
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<VideoPlayerController> _initRemoteController() async {
    final source = await ref
        .read(learningRepositoryProvider)
        .getPlaybackSource(widget.assetId);
    _poster = source.posterUrl;
    _watchProgress = source.watchProgress;
    if (_watchProgress) {
      final result = await ref
          .read(apiClientProvider)
          .get(
            '/api/v1/playback/${Uri.encodeComponent(widget.assetId)}/progress',
          );
      if (result case Success(value: final data)) {
        _furthest = (data['furthestSeconds'] as num).toDouble();
        _resume = Duration(
          milliseconds: ((data['positionSeconds'] as num) * 1000).round(),
        );
      } else {
        throw StateError('Unable to load watch progress.');
      }
    }
    if (!source.streamUri.isScheme('https')) {
      throw StateError('Playback requires HTTPS.');
    }
    return VideoPlayerController.networkUrl(
      source.streamUri,
      formatHint: source.kind == PlaybackStreamKind.hls
          ? VideoFormat.hls
          : null,
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: false,
        allowBackgroundPlayback: false,
      ),
      closedCaptionFile: source.subtitles.isEmpty
          ? null
          : _loadSubtitle(source.subtitles.first),
    );
  }

  Future<ClosedCaptionFile> _loadSubtitle(SubtitleTrack track) async {
    if (!track.uri.isScheme('https')) {
      throw StateError('Subtitles require HTTPS.');
    }
    final response = await Dio().get<String>(
      track.uri.toString(),
      options: Options(
        responseType: ResponseType.plain,
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
    final body = response.data ?? '';
    if (body.length > 1000000) {
      throw StateError('Subtitle file exceeds the supported size.');
    }
    return WebVTTCaptionFile(body);
  }

  Future<void> _saveWatch() async {
    final controller = _controller;
    if (!_watchProgress ||
        _sending ||
        controller == null ||
        !controller.value.isInitialized) {
      return;
    }
    _sending = true;
    try {
      final result = await ref
          .read(apiClientProvider)
          .post(
            '/api/v1/playback/${Uri.encodeComponent(widget.assetId)}/progress',
            body: {
              'positionSeconds':
                  controller.value.position.inMilliseconds / 1000,
            },
          );
      if (result case Success(value: final data)) {
        _furthest = (data['furthestSeconds'] as num).toDouble();
        if (data['completed'] == true) await widget.onFlush();
      } else {
        await controller.pause();
        await controller.seekTo(
          Duration(milliseconds: (_furthest * 1000).round()),
        );
        if (mounted) {
          setState(
            () => _error = StateError(
              'Progress could not be saved. Reconnect and retry.',
            ),
          );
        }
      }
    } finally {
      _sending = false;
    }
  }

  void _onPlayerChanged() {
    final controller = _controller;
    if (!mounted || controller == null) return;
    final value = controller.value;
    if (value.hasError) {
      _error = StateError('Playback failed.');
    }
    if (value.isPlaying) _started = true;
    if (!_watchProgress &&
        value.position - _lastCheckpoint >= _checkpointInterval) {
      _lastCheckpoint = value.position;
      unawaited(widget.onProgress(value.position, value.duration));
    }
    setState(() {});
    _overlay?.markNeedsBuild();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_checkpointAndFlush());
      unawaited(_controller?.pause());
    }
  }

  Future<void> _checkpointAndFlush() async {
    final value = _controller?.value;
    if (_watchProgress) await _saveWatch();
    if (!_watchProgress && value != null && value.isInitialized) {
      await widget.onProgress(value.position, value.duration);
    }
    await widget.onFlush();
  }

  Future<void> _toggleFullscreen() async {
    final next = !_fullscreen;
    setState(() => _fullscreen = next);
    if (next) {
      _overlay = OverlayEntry(
        builder: (context) => Material(
          color: Colors.black,
          child: _buildPlayer(context, overlay: true),
        ),
      );
      Overlay.of(context, rootOverlay: true).insert(_overlay!);
    } else {
      _overlay?.remove();
      _overlay = null;
    }
    await SystemChrome.setEnabledSystemUIMode(
      next ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
    await SystemChrome.setPreferredOrientations(
      next
          ? const [
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]
          : const [],
    );
  }

  @override
  Widget build(BuildContext context) => _fullscreen
      ? const AspectRatio(
          aspectRatio: 16 / 9,
          child: ColoredBox(color: Colors.black),
        )
      : _buildPlayer(context);

  Widget _buildPlayer(BuildContext context, {bool overlay = false}) {
    final controller = _controller;
    final player = ColoredBox(
      color: Colors.black,
      child: _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_outlined, color: Colors.white),
                  const SizedBox(height: 8),
                  const Text(
                    'We couldn’t load this video.',
                    style: TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () {
                      _watchTimer?.cancel();
                      final old = _controller;
                      old?.removeListener(_onPlayerChanged);
                      unawaited(old?.dispose());
                      setState(() {
                        _error = null;
                        _controller = null;
                      });
                      unawaited(_initialize());
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            )
          : controller == null
          ? const Center(
              child: CircularProgressIndicator(semanticsLabel: 'Loading video'),
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: AspectRatio(
                    aspectRatio: controller.value.aspectRatio == 0
                        ? 16 / 9
                        : controller.value.aspectRatio,
                    child: VideoPlayer(controller),
                  ),
                ),
                if (!_started && _poster != null)
                  Positioned.fill(
                    child: Image.network(
                      _poster!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.video_library_outlined,
                        color: Colors.white,
                      ),
                    ),
                  ),
                if (controller.value.isBuffering)
                  const Center(child: CircularProgressIndicator()),
                if (_captionsEnabled)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 64),
                      child: ClosedCaption(
                        text: controller.value.caption.text,
                        textStyle: const TextStyle(
                          color: Colors.white,
                          backgroundColor: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                if (_isOfflinePlayback)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(160),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.offline_bolt,
                            color: Colors.greenAccent,
                            size: 14,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Offline',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: _VideoControls(
                    controller: controller,
                    maxSeekSeconds: _watchProgress ? _furthest + 2 : null,
                    onPause: _saveWatch,
                    speeds: _speeds,
                    fullscreen: _fullscreen,
                    captionsEnabled: _captionsEnabled,
                    onCaptions: () =>
                        setState(() => _captionsEnabled = !_captionsEnabled),
                    onFullscreen: _toggleFullscreen,
                  ),
                ),
              ],
            ),
    );

    final view = _fullscreen
        ? SizedBox.expand(child: player)
        : AspectRatio(aspectRatio: 16 / 9, child: player);

    return ProtectedContentGate(
      policy: widget.policy,
      onCaptureChanged: (isCaptured) {
        if (isCaptured) {
          unawaited(_controller?.pause());
        }
      },
      child: view,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _watchTimer?.cancel();
    _overlay?.remove();
    final controller = _controller;
    if (controller != null) {
      controller.removeListener(_onPlayerChanged);
      if (!_watchProgress) {
        unawaited(
          widget.onProgress(
            controller.value.position,
            controller.value.duration,
          ),
        );
      }
      unawaited(controller.dispose());
    }
    if (_fullscreen) {
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
      unawaited(SystemChrome.setPreferredOrientations(const []));
    }
    super.dispose();
  }
}

String _time(Duration value) =>
    '${value.inMinutes}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';

class _VideoControls extends StatelessWidget {
  const _VideoControls({
    required this.controller,
    this.maxSeekSeconds,
    this.onPause,
    required this.speeds,
    required this.fullscreen,
    required this.captionsEnabled,
    required this.onCaptions,
    required this.onFullscreen,
  });
  final VideoPlayerController controller;
  final double? maxSeekSeconds;
  final Future<void> Function()? onPause;
  final List<double> speeds;
  final bool fullscreen;
  final bool captionsEnabled;
  final VoidCallback onCaptions;
  final VoidCallback onFullscreen;

  @override
  Widget build(BuildContext context) {
    final value = controller.value;
    final durationMs = value.duration.inMilliseconds;
    return ColoredBox(
      color: Colors.black54,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Slider(
              value: durationMs <= 0
                  ? 0
                  : value.position.inMilliseconds
                        .clamp(0, durationMs)
                        .toDouble(),
              max: durationMs <= 0 ? 1 : durationMs.toDouble(),
              onChanged: durationMs <= 0
                  ? null
                  : (position) => controller.seekTo(
                      Duration(
                        milliseconds: maxSeekSeconds == null
                            ? position.round()
                            : position.clamp(0, maxSeekSeconds! * 1000).round(),
                      ),
                    ),
              semanticFormatterCallback: (milliseconds) =>
                  '${Duration(milliseconds: milliseconds.round()).inSeconds} seconds',
            ),

            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                IconButton(
                  tooltip: value.isPlaying ? 'Pause video' : 'Play video',
                  color: Colors.white,
                  onPressed: () => value.isPlaying
                      ? controller.pause().then((_) => onPause?.call())
                      : controller.play(),
                  icon: Icon(value.isPlaying ? Icons.pause : Icons.play_arrow),
                ),
                Text(
                  '${_time(value.position)} / ${_time(value.duration)}',
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
                IconButton(
                  tooltip: 'Mute / unmute',
                  color: Colors.white,
                  onPressed: () =>
                      controller.setVolume(value.volume == 0 ? 1 : 0),
                  icon: Icon(
                    value.volume == 0 ? Icons.volume_off : Icons.volume_up,
                  ),
                ),
                PopupMenuButton<double>(
                  tooltip: 'Playback speed',
                  initialValue: value.playbackSpeed,
                  onSelected: controller.setPlaybackSpeed,
                  itemBuilder: (context) => [
                    for (final speed in speeds)
                      PopupMenuItem(value: speed, child: Text('${speed}x')),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      '${value.playbackSpeed}x',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: captionsEnabled
                      ? 'Hide subtitles'
                      : 'Show subtitles',
                  color: Colors.white,
                  onPressed: onCaptions,
                  icon: Icon(
                    captionsEnabled
                        ? Icons.closed_caption
                        : Icons.closed_caption_off,
                  ),
                ),
                IconButton(
                  tooltip: fullscreen ? 'Exit fullscreen' : 'Enter fullscreen',
                  color: Colors.white,
                  onPressed: onFullscreen,
                  icon: Icon(
                    fullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
