import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_platform/core/errors/app_failure.dart';
import 'package:learning_platform/core/errors/result.dart';
import 'package:learning_platform/features/notifications/domain/notification_preferences.dart';
import 'package:learning_platform/features/notifications/domain/notification_repository.dart';

final class NotificationPreferencesState {
  const NotificationPreferencesState({
    this.isLoading = false,
    this.isSaving = false,
    this.preferences = const NotificationPreferences(),
    this.failure,
  });

  final bool isLoading;
  final bool isSaving;
  final NotificationPreferences preferences;
  final AppFailure? failure;

  NotificationPreferencesState copyWith({
    bool? isLoading,
    bool? isSaving,
    NotificationPreferences? preferences,
    AppFailure? failure,
    bool clearFailure = false,
  }) => NotificationPreferencesState(
    isLoading: isLoading ?? this.isLoading,
    isSaving: isSaving ?? this.isSaving,
    preferences: preferences ?? this.preferences,
    failure: clearFailure ? null : (failure ?? this.failure),
  );
}

final class NotificationPreferencesController
    extends StateNotifier<NotificationPreferencesState> {
  NotificationPreferencesController(this._repository)
    : super(const NotificationPreferencesState()) {
    unawaited(loadPreferences());
  }

  final NotificationRepository _repository;

  Future<void> loadPreferences() async {
    state = state.copyWith(isLoading: true, clearFailure: true);
    final result = await _repository.getPreferences();
    switch (result) {
      case Success(value: final prefs):
        state = state.copyWith(isLoading: false, preferences: prefs);
      case Failure(failure: final failure):
        state = state.copyWith(isLoading: false, failure: failure);
    }
  }

  Future<void> updatePreferences(NotificationPreferences updated) async {
    final previous = state.preferences;
    state = state.copyWith(
      isSaving: true,
      preferences: updated,
      clearFailure: true,
    );

    final result = await _repository.updatePreferences(updated);
    switch (result) {
      case Success(value: final saved):
        state = state.copyWith(isSaving: false, preferences: saved);
      case Failure(failure: final failure):
        state = state.copyWith(
          isSaving: false,
          preferences: previous,
          failure: failure,
        );
    }
  }
}
