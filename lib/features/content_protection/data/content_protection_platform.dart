import 'dart:async';

import 'package:flutter/services.dart';
import 'package:learning_platform/features/content_protection/domain/content_protection_policy.dart';

/// Platform channel contract for managing screen protection and monitoring capture state.
abstract class ContentProtectionPlatform {
  /// Enables platform-level protection (e.g. FLAG_SECURE on Android, capture observation on iOS).
  Future<void> enableProtection(ContentProtectionPolicy policy);

  /// Disables platform-level protection, restoring standard window behavior.
  Future<void> disableProtection();

  /// Gets the current capture state directly from the platform host.
  Future<ScreenCaptureState> getCaptureState();

  /// Stream of native screen capture and screenshot telemetry events.
  Stream<ScreenCaptureEvent> get events;
}

/// Default implementation using MethodChannel and EventChannel.
final class MethodChannelContentProtectionPlatform
    implements ContentProtectionPlatform {
  MethodChannelContentProtectionPlatform({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  }) : _methodChannel =
           methodChannel ??
           const MethodChannel(
             'com.learningplatform/content_protection/methods',
           ),
       _eventChannel =
           eventChannel ??
           const EventChannel('com.learningplatform/content_protection/events');

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;
  Stream<ScreenCaptureEvent>? _eventStream;

  @override
  Future<void> enableProtection(ContentProtectionPolicy policy) async {
    try {
      await _methodChannel.invokeMethod<void>('enableProtection', {
        'policy': policy.name,
      });
    } on MissingPluginException {
      // Graceful fallback on unsupported platforms (e.g. desktop/web in dev)
    } on PlatformException {
      // Fail safely without crashing the UI layer
    }
  }

  @override
  Future<void> disableProtection() async {
    try {
      await _methodChannel.invokeMethod<void>('disableProtection');
    } on MissingPluginException {
      // Graceful fallback
    } on PlatformException {
      // Fail safely
    }
  }

  @override
  Future<ScreenCaptureState> getCaptureState() async {
    try {
      final map = await _methodChannel.invokeMapMethod<String, dynamic>(
        'getCaptureState',
      );
      if (map == null) return ScreenCaptureState.initial;

      return ScreenCaptureState(
        isCaptured: map['isCaptured'] as bool? ?? false,
        isProtected: map['isProtected'] as bool? ?? false,
        activePolicy: _parsePolicy(map['policy'] as String?),
        platform: map['platform'] as String? ?? 'unknown',
      );
    } on MissingPluginException {
      return ScreenCaptureState.initial;
    } on PlatformException {
      return ScreenCaptureState.initial;
    }
  }

  @override
  Stream<ScreenCaptureEvent> get events {
    _eventStream ??= _eventChannel
        .receiveBroadcastStream()
        .map(_parseEvent)
        .where((e) => e != null)
        .cast<ScreenCaptureEvent>()
        .handleError((Object error) {
          // Keep stream alive on transient platform errors
        });
    return _eventStream!;
  }

  ContentProtectionPolicy _parsePolicy(String? name) {
    if (name == null) return ContentProtectionPolicy.none;
    try {
      return ContentProtectionPolicy.values.byName(name);
    } on Object catch (_) {
      return ContentProtectionPolicy.none;
    }
  }

  ScreenCaptureEvent? _parseEvent(dynamic data) {
    if (data is! Map) return null;
    final eventType = data['event'] as String?;

    if (eventType == 'capture_state_changed') {
      return CaptureStateChangedEvent(
        isCaptured: data['isCaptured'] as bool? ?? false,
        captureType: data['captureType'] as String? ?? 'unknown',
      );
    } else if (eventType == 'screenshot_taken') {
      return ScreenshotTakenEvent(timestamp: DateTime.now());
    }

    return null;
  }
}

/// Mock implementation for unit tests and deterministic simulation.
final class MockContentProtectionPlatform implements ContentProtectionPlatform {
  MockContentProtectionPlatform({
    ScreenCaptureState initialState = ScreenCaptureState.initial,
  }) : _state = initialState;

  ScreenCaptureState _state;
  final StreamController<ScreenCaptureEvent> _controller =
      StreamController<ScreenCaptureEvent>.broadcast();

  int enableCallCount = 0;
  int disableCallCount = 0;
  ContentProtectionPolicy? lastEnabledPolicy;

  @override
  Future<void> enableProtection(ContentProtectionPolicy policy) async {
    enableCallCount++;
    lastEnabledPolicy = policy;
    _state = _state.copyWith(isProtected: true, activePolicy: policy);
  }

  @override
  Future<void> disableProtection() async {
    disableCallCount++;
    _state = _state.copyWith(
      isProtected: false,
      activePolicy: ContentProtectionPolicy.none,
    );
  }

  @override
  Future<ScreenCaptureState> getCaptureState() async => _state;

  @override
  Stream<ScreenCaptureEvent> get events => _controller.stream;

  /// Simulates a capture state change event from the native platform.
  void simulateCaptureStateChanged({
    required bool isCaptured,
    String type = 'screen_recording',
  }) {
    _state = _state.copyWith(isCaptured: isCaptured);
    _controller.add(
      CaptureStateChangedEvent(isCaptured: isCaptured, captureType: type),
    );
  }

  /// Simulates a screenshot detection event from the native platform.
  void simulateScreenshotTaken() {
    _controller.add(ScreenshotTakenEvent(timestamp: DateTime.now()));
  }

  void dispose() {
    unawaited(_controller.close());
  }
}
