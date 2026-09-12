import 'package:flutter/material.dart';

@immutable
final class AppearanceSettings {
  const AppearanceSettings({
    this.themeMode = ThemeMode.system,
    this.reducedMotion = false,
    this.highContrast = false,
  });

  final ThemeMode themeMode;
  final bool reducedMotion;
  final bool highContrast;

  AppearanceSettings copyWith({
    ThemeMode? themeMode,
    bool? reducedMotion,
    bool? highContrast,
  }) => AppearanceSettings(
    themeMode: themeMode ?? this.themeMode,
    reducedMotion: reducedMotion ?? this.reducedMotion,
    highContrast: highContrast ?? this.highContrast,
  );
}

@immutable
final class PlaybackSettings {
  const PlaybackSettings({
    this.autoplayNextLesson = true,
    this.preferredPlaybackSpeed = 1.0,
    this.captionsDefaultEnabled = false,
  });

  final bool autoplayNextLesson;
  final double preferredPlaybackSpeed;
  final bool captionsDefaultEnabled;

  PlaybackSettings copyWith({
    bool? autoplayNextLesson,
    double? preferredPlaybackSpeed,
    bool? captionsDefaultEnabled,
  }) => PlaybackSettings(
    autoplayNextLesson: autoplayNextLesson ?? this.autoplayNextLesson,
    preferredPlaybackSpeed:
        preferredPlaybackSpeed ?? this.preferredPlaybackSpeed,
    captionsDefaultEnabled:
        captionsDefaultEnabled ?? this.captionsDefaultEnabled,
  );
}

@immutable
final class DownloadPreferences {
  const DownloadPreferences({
    this.downloadQuality = 'standard',
    this.downloadWifiOnly = true,
  });

  final String downloadQuality;
  final bool downloadWifiOnly;

  DownloadPreferences copyWith({
    String? downloadQuality,
    bool? downloadWifiOnly,
  }) => DownloadPreferences(
    downloadQuality: downloadQuality ?? this.downloadQuality,
    downloadWifiOnly: downloadWifiOnly ?? this.downloadWifiOnly,
  );
}

@immutable
final class AccessibilitySettings {
  const AccessibilitySettings({
    this.largeTouchTargets = false,
    this.screenReaderOptimized = false,
  });

  final bool largeTouchTargets;
  final bool screenReaderOptimized;

  AccessibilitySettings copyWith({
    bool? largeTouchTargets,
    bool? screenReaderOptimized,
  }) => AccessibilitySettings(
    largeTouchTargets: largeTouchTargets ?? this.largeTouchTargets,
    screenReaderOptimized: screenReaderOptimized ?? this.screenReaderOptimized,
  );
}

@immutable
final class PrivacySettings {
  const PrivacySettings({
    this.analyticsEnabled = false,
    this.crashReportingEnabled = true,
  });

  final bool analyticsEnabled;
  final bool crashReportingEnabled;

  PrivacySettings copyWith({
    bool? analyticsEnabled,
    bool? crashReportingEnabled,
  }) => PrivacySettings(
    analyticsEnabled: analyticsEnabled ?? this.analyticsEnabled,
    crashReportingEnabled: crashReportingEnabled ?? this.crashReportingEnabled,
  );
}

@immutable
final class AppSettings {
  const AppSettings({
    this.appearance = const AppearanceSettings(),
    this.playback = const PlaybackSettings(),
    this.downloads = const DownloadPreferences(),
    this.accessibility = const AccessibilitySettings(),
    this.privacy = const PrivacySettings(),
  });

  final AppearanceSettings appearance;
  final PlaybackSettings playback;
  final DownloadPreferences downloads;
  final AccessibilitySettings accessibility;
  final PrivacySettings privacy;

  AppSettings copyWith({
    AppearanceSettings? appearance,
    PlaybackSettings? playback,
    DownloadPreferences? downloads,
    AccessibilitySettings? accessibility,
    PrivacySettings? privacy,
  }) => AppSettings(
    appearance: appearance ?? this.appearance,
    playback: playback ?? this.playback,
    downloads: downloads ?? this.downloads,
    accessibility: accessibility ?? this.accessibility,
    privacy: privacy ?? this.privacy,
  );

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final themeStr = json['themeMode'] as String? ?? 'system';
    final themeMode = switch (themeStr.toLowerCase()) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    return AppSettings(
      appearance: AppearanceSettings(
        themeMode: themeMode,
        reducedMotion: (json['reducedMotion'] as bool?) ?? false,
        highContrast: (json['highContrast'] as bool?) ?? false,
      ),
      playback: PlaybackSettings(
        autoplayNextLesson: (json['autoplayNextLesson'] as bool?) ?? true,
        preferredPlaybackSpeed:
            (json['preferredPlaybackSpeed'] as num?)?.toDouble() ?? 1.0,
        captionsDefaultEnabled:
            (json['captionsDefaultEnabled'] as bool?) ?? false,
      ),
      downloads: DownloadPreferences(
        downloadQuality: (json['downloadQuality'] as String?) ?? 'standard',
        downloadWifiOnly: (json['downloadWifiOnly'] as bool?) ?? true,
      ),
      accessibility: AccessibilitySettings(
        largeTouchTargets: (json['largeTouchTargets'] as bool?) ?? false,
        screenReaderOptimized:
            (json['screenReaderOptimized'] as bool?) ?? false,
      ),
      privacy: PrivacySettings(
        analyticsEnabled: (json['analyticsEnabled'] as bool?) ?? false,
        crashReportingEnabled: (json['crashReportingEnabled'] as bool?) ?? true,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'themeMode': appearance.themeMode.name,
    'reducedMotion': appearance.reducedMotion,
    'highContrast': appearance.highContrast,
    'autoplayNextLesson': playback.autoplayNextLesson,
    'preferredPlaybackSpeed': playback.preferredPlaybackSpeed,
    'captionsDefaultEnabled': playback.captionsDefaultEnabled,
    'downloadQuality': downloads.downloadQuality,
    'downloadWifiOnly': downloads.downloadWifiOnly,
    'largeTouchTargets': accessibility.largeTouchTargets,
    'screenReaderOptimized': accessibility.screenReaderOptimized,
    'analyticsEnabled': privacy.analyticsEnabled,
    'crashReportingEnabled': privacy.crashReportingEnabled,
  };
}
