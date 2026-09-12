import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_platform/core/analytics/platform_analytics.dart';
import 'package:learning_platform/core/errors/result.dart';
import 'package:learning_platform/features/settings/data/settings_repository.dart';
import 'package:learning_platform/features/settings/domain/app_settings.dart';

final class SettingsController extends StateNotifier<AppSettings> {
  SettingsController(this._repository, {PlatformAnalytics? analytics})
    : _analytics = analytics,
      super(const AppSettings()) {
    _initialization = _init();
  }

  final SettingsRepository _repository;
  final PlatformAnalytics? _analytics;
  late final Future<void> _initialization;
  Future<void> _writes = Future<void>.value();

  Future<void> _init() async {
    final loaded = await _repository.loadSettings();
    state = loaded;
  }

  Future<void> _update(
    AppSettings Function(AppSettings current) transform,
    Future<void> Function()? track,
  ) async {
    await _initialization;
    final previous = state;
    final updated = transform(previous);
    state = updated;
    if (track != null) unawaited(track());

    late final Future<void> write;
    write = _writes = _writes.then((_) async {
      final result = await _repository.saveSettings(updated);
      if (result is Failure<void> && identical(state, updated)) {
        state = previous;
      }
    });
    await write;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _update(
      (current) => current.copyWith(
        appearance: current.appearance.copyWith(themeMode: mode),
      ),
      () => _analytics?.themeChanged(themeMode: mode.name) ?? Future.value(),
    );
  }

  Future<void> setReducedMotion(bool value) async {
    await _update(
      (current) => current.copyWith(
        appearance: current.appearance.copyWith(reducedMotion: value),
      ),
      () =>
          _analytics?.settingsChanged(settingKey: 'reduced_motion') ??
          Future.value(),
    );
  }

  Future<void> setHighContrast(bool value) async {
    await _update(
      (current) => current.copyWith(
        appearance: current.appearance.copyWith(highContrast: value),
      ),
      () =>
          _analytics?.settingsChanged(settingKey: 'high_contrast') ??
          Future.value(),
    );
  }

  Future<void> setAutoplayNextLesson(bool value) async {
    await _update(
      (current) => current.copyWith(
        playback: current.playback.copyWith(autoplayNextLesson: value),
      ),
      () =>
          _analytics?.settingsChanged(settingKey: 'autoplay_next_lesson') ??
          Future.value(),
    );
  }

  Future<void> setPreferredPlaybackSpeed(double speed) async {
    await _update(
      (current) => current.copyWith(
        playback: current.playback.copyWith(preferredPlaybackSpeed: speed),
      ),
      () =>
          _analytics?.settingsChanged(settingKey: 'playback_speed') ??
          Future.value(),
    );
  }

  Future<void> setCaptionsDefaultEnabled(bool value) async {
    await _update(
      (current) => current.copyWith(
        playback: current.playback.copyWith(captionsDefaultEnabled: value),
      ),
      () =>
          _analytics?.settingsChanged(settingKey: 'captions_default') ??
          Future.value(),
    );
  }

  Future<void> setDownloadQuality(String quality) async {
    await _update(
      (current) => current.copyWith(
        downloads: current.downloads.copyWith(downloadQuality: quality),
      ),
      () =>
          _analytics?.settingsChanged(settingKey: 'download_quality') ??
          Future.value(),
    );
  }

  Future<void> setDownloadWifiOnly(bool value) async {
    await _update(
      (current) => current.copyWith(
        downloads: current.downloads.copyWith(downloadWifiOnly: value),
      ),
      () =>
          _analytics?.settingsChanged(settingKey: 'download_wifi_only') ??
          Future.value(),
    );
  }

  Future<void> setAnalyticsEnabled(bool value) async {
    await _update(
      (current) => current.copyWith(
        privacy: current.privacy.copyWith(analyticsEnabled: value),
      ),
      () =>
          _analytics?.settingsChanged(settingKey: 'analytics_enabled') ??
          Future.value(),
    );
  }
}
