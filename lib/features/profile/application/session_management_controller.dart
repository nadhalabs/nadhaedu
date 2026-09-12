import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_platform/core/analytics/platform_analytics.dart';
import 'package:learning_platform/core/errors/app_failure.dart';
import 'package:learning_platform/core/errors/result.dart';
import 'package:learning_platform/features/profile/domain/device_session.dart';
import 'package:learning_platform/features/profile/domain/profile_repository.dart';

final class SessionManagementState {
  const SessionManagementState({
    this.isLoading = false,
    this.isRevoking = false,
    this.sessions = const [],
    this.failure,
  });

  final bool isLoading;
  final bool isRevoking;
  final List<DeviceSession> sessions;
  final AppFailure? failure;

  SessionManagementState copyWith({
    bool? isLoading,
    bool? isRevoking,
    List<DeviceSession>? sessions,
    AppFailure? failure,
    bool clearFailure = false,
  }) => SessionManagementState(
    isLoading: isLoading ?? this.isLoading,
    isRevoking: isRevoking ?? this.isRevoking,
    sessions: sessions ?? this.sessions,
    failure: clearFailure ? null : (failure ?? this.failure),
  );
}

final class SessionManagementController
    extends StateNotifier<SessionManagementState> {
  SessionManagementController(this._repository, {PlatformAnalytics? analytics})
    : _analytics = analytics,
      super(const SessionManagementState()) {
    unawaited(loadSessions());
  }

  final ProfileRepository _repository;
  final PlatformAnalytics? _analytics;

  Future<void> loadSessions() async {
    state = state.copyWith(isLoading: true, clearFailure: true);
    final result = await _repository.getActiveSessions();
    switch (result) {
      case Success(value: final sessions):
        state = state.copyWith(isLoading: false, sessions: sessions);
      case Failure(failure: final failure):
        state = state.copyWith(isLoading: false, failure: failure);
    }
  }

  Future<bool> revokeSession(String sessionId) async {
    state = state.copyWith(isRevoking: true, clearFailure: true);
    final sessionToRevoke = state.sessions
        .where((s) => s.id == sessionId)
        .firstOrNull;
    final isCurrent = sessionToRevoke?.isCurrent ?? false;

    final result = await _repository.revokeSession(sessionId);
    switch (result) {
      case Success():
        final updated = state.sessions.where((s) => s.id != sessionId).toList();
        state = state.copyWith(isRevoking: false, sessions: updated);
        await _analytics?.sessionRevoked(
          sessionId: sessionId,
          isCurrent: isCurrent,
          isAllOthers: false,
        );
        return true;
      case Failure(failure: final failure):
        state = state.copyWith(isRevoking: false, failure: failure);
        return false;
    }
  }

  Future<bool> revokeOtherSessions() async {
    state = state.copyWith(isRevoking: true, clearFailure: true);
    final result = await _repository.revokeOtherSessions();
    switch (result) {
      case Success():
        final currentOnly = state.sessions.where((s) => s.isCurrent).toList();
        state = state.copyWith(isRevoking: false, sessions: currentOnly);
        await _analytics?.sessionRevoked(
          sessionId: 'others',
          isCurrent: false,
          isAllOthers: true,
        );
        return true;
      case Failure(failure: final failure):
        state = state.copyWith(isRevoking: false, failure: failure);
        return false;
    }
  }
}
