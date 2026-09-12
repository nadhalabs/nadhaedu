enum PlaybackStreamKind { hls, mp4 }

final class SubtitleTrack {
  const SubtitleTrack({
    required this.id,
    required this.label,
    required this.languageCode,
    required this.uri,
  });
  final String id;
  final String label;
  final String languageCode;
  final Uri uri;
}

final class PlaybackSource {
  const PlaybackSource({
    required this.streamUri,
    required this.kind,
    required this.subtitles,
    this.posterUrl,
    this.watchProgress = false,
  });
  final String? posterUrl;
  final bool watchProgress;
  final Uri streamUri;
  final PlaybackStreamKind kind;
  final List<SubtitleTrack> subtitles;
}
