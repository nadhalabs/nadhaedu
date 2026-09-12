import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_platform/features/content_protection/data/content_protection_platform.dart';
import 'package:learning_platform/features/content_protection/domain/content_protection_policy.dart';

final contentProtectionPlatformProvider = Provider<ContentProtectionPlatform>((
  ref,
) {
  return MethodChannelContentProtectionPlatform();
});

final contentProtectionServiceProvider =
    NotifierProvider<ContentProtectionService, ScreenCaptureState>(
      ContentProtectionService.new,
    );

final screenCaptureStateProvider = Provider<ScreenCaptureState>((ref) {
  return ref.watch(contentProtectionServiceProvider);
});

/// Manages active screen protection reference counting and monitors capture state.
final class ContentProtectionService extends Notifier<ScreenCaptureState> {
  StreamSubscription<ScreenCaptureEvent>? _eventSubscription;
  int _activeLocks = 0;
  ContentProtectionPolicy _currentHighestPolicy = ContentProtectionPolicy.none;

  @override
  ScreenCaptureState build() {
    final platform = ref.watch(contentProtectionPlatformProvider);

    unawaited(_eventSubscription?.cancel());
    _eventSubscription = platform.events.listen(_handlePlatformEvent);

    ref.onDispose(() {
      unawaited(_eventSubscription?.cancel());
    });

    // Asynchronously fetch initial state from native host
    unawaited(_syncInitialState(platform));

    return ScreenCaptureState.initial;
  }

  Future<void> _syncInitialState(ContentProtectionPlatform platform) async {
    final hostState = await platform.getCaptureState();
    state = state.copyWith(
      isCaptured: state.isCaptured || hostState.isCaptured,
      platform: hostState.platform,
    );
  }

  /// Acquires a protection lock for a visible protected screen or component.
  Future<void> acquireProtection(ContentProtectionPolicy policy) async {
    if (policy == ContentProtectionPolicy.none) return;

    _activeLocks++;
    if (policy.index > _currentHighestPolicy.index) {
      _currentHighestPolicy = policy;
    }

    final platform = ref.read(contentProtectionPlatformProvider);
    await platform.enableProtection(_currentHighestPolicy);

    state = state.copyWith(
      isProtected: true,
      activePolicy: _currentHighestPolicy,
    );
  }

  /// Releases a previously acquired protection lock when leaving a protected screen.
  Future<void> releaseProtection() async {
    if (_activeLocks <= 0) return;

    _activeLocks--;
    if (_activeLocks == 0) {
      _currentHighestPolicy = ContentProtectionPolicy.none;
      final platform = ref.read(contentProtectionPlatformProvider);
      await platform.disableProtection();

      state = state.copyWith(
        isProtected: false,
        activePolicy: ContentProtectionPolicy.none,
      );
    }
  }

  /// Force resets all locks (e.g. on full navigation resets / auth logouts).
  Future<void> resetAll() async {
    _activeLocks = 0;
    _currentHighestPolicy = ContentProtectionPolicy.none;
    final platform = ref.read(contentProtectionPlatformProvider);
    await platform.disableProtection();

    state = state.copyWith(
      isProtected: false,
      activePolicy: ContentProtectionPolicy.none,
    );
  }

  void _handlePlatformEvent(ScreenCaptureEvent event) {
    switch (event) {
      case CaptureStateChangedEvent(:final isCaptured):
        state = state.copyWith(isCaptured: isCaptured);
      case ScreenshotTakenEvent():
        // Log telemetry / analytics without punitive learner banning
        break;
    }
  }

  int get activeLockCount => _activeLocks;
}
