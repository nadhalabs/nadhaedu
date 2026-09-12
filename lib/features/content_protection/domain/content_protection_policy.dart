import 'package:flutter/foundation.dart';

/// Server-authoritative screen and capture protection policy.
enum ContentProtectionPolicy {
  /// Public, marketing, and free content; screenshots and capture permitted.
  none,

  /// Protected content where capture triggers telemetry without hard-blocking.
  discourageCapture,

  /// Standard premium content; enforces secure window on Android and active capture redaction on iOS.
  blockCaptureWhereSupported,

  /// High-value commercial assets requiring end-to-end FairPlay / Widevine DRM pipelines.
  drmRequired;

  /// Whether this policy requires active platform window security (FLAG_SECURE).
  bool get requiresPlatformWindowSecurity =>
      this == blockCaptureWhereSupported || this == drmRequired;

  /// Whether this policy requires active capture detection and redaction (e.g. on iOS).
  bool get requiresCaptureRedaction =>
      this == blockCaptureWhereSupported || this == drmRequired;
}

/// Represents the current capture and protection state of the device screen.
@immutable
final class ScreenCaptureState {
  const ScreenCaptureState({
    required this.isCaptured,
    required this.isProtected,
    required this.activePolicy,
    this.platform = 'unknown',
  });

  /// Initial idle state where no capture is active and protection is disabled.
  static const initial = ScreenCaptureState(
    isCaptured: false,
    isProtected: false,
    activePolicy: ContentProtectionPolicy.none,
  );

  /// Whether the screen is currently being mirrored, shared, or recorded.
  final bool isCaptured;

  /// Whether platform capture protection is currently enabled on the window.
  final bool isProtected;

  /// The active content protection policy applied to the screen.
  final ContentProtectionPolicy activePolicy;

  /// The underlying platform name (android, ios, web, desktop).
  final String platform;

  /// Whether the content should be obscured/redacted from the learner right now.
  bool get isContentRedacted =>
      isCaptured && activePolicy.requiresCaptureRedaction;

  ScreenCaptureState copyWith({
    bool? isCaptured,
    bool? isProtected,
    ContentProtectionPolicy? activePolicy,
    String? platform,
  }) {
    return ScreenCaptureState(
      isCaptured: isCaptured ?? this.isCaptured,
      isProtected: isProtected ?? this.isProtected,
      activePolicy: activePolicy ?? this.activePolicy,
      platform: platform ?? this.platform,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScreenCaptureState &&
          runtimeType == other.runtimeType &&
          isCaptured == other.isCaptured &&
          isProtected == other.isProtected &&
          activePolicy == other.activePolicy &&
          platform == other.platform;

  @override
  int get hashCode =>
      Object.hash(isCaptured, isProtected, activePolicy, platform);

  @override
  String toString() =>
      'ScreenCaptureState(isCaptured: $isCaptured, isProtected: $isProtected, activePolicy: $activePolicy, platform: $platform)';
}

/// Events emitted by the native platform capture monitor.
sealed class ScreenCaptureEvent {
  const ScreenCaptureEvent();
}

/// Emitted when active screen capture/recording/mirroring starts or stops.
final class CaptureStateChangedEvent extends ScreenCaptureEvent {
  const CaptureStateChangedEvent({
    required this.isCaptured,
    this.captureType = 'unknown',
  });

  final bool isCaptured;
  final String captureType;
}

/// Emitted when a screenshot notification is received (e.g. on iOS for telemetry).
final class ScreenshotTakenEvent extends ScreenCaptureEvent {
  const ScreenshotTakenEvent({required this.timestamp});

  final DateTime timestamp;
}
