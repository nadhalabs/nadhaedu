import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_platform/core/analytics/platform_analytics.dart';
import 'package:learning_platform/core/errors/app_failure.dart';
import 'package:learning_platform/core/errors/result.dart';
import 'package:learning_platform/features/profile/domain/learner_profile.dart';
import 'package:learning_platform/features/profile/domain/profile_repository.dart';

final class ProfileState {
  const ProfileState({
    this.isLoading = false,
    this.isSaving = false,
    this.profile,
    this.failure,
  });

  final bool isLoading;
  final bool isSaving;
  final LearnerProfile? profile;
  final AppFailure? failure;

  ProfileState copyWith({
    bool? isLoading,
    bool? isSaving,
    LearnerProfile? profile,
    AppFailure? failure,
    bool clearFailure = false,
  }) => ProfileState(
    isLoading: isLoading ?? this.isLoading,
    isSaving: isSaving ?? this.isSaving,
    profile: profile ?? this.profile,
    failure: clearFailure ? null : (failure ?? this.failure),
  );
}

final class ProfileController extends StateNotifier<ProfileState> {
  ProfileController(this._repository, {PlatformAnalytics? analytics})
    : _analytics = analytics,
      super(const ProfileState()) {
    unawaited(loadProfile());
  }

  final ProfileRepository _repository;
  final PlatformAnalytics? _analytics;

  Future<void> loadProfile() async {
    state = state.copyWith(isLoading: true, clearFailure: true);
    final result = await _repository.getProfile();
    switch (result) {
      case Success(value: final profile):
        state = state.copyWith(isLoading: false, profile: profile);
      case Failure(failure: final failure):
        state = state.copyWith(isLoading: false, failure: failure);
    }
  }

  Future<bool> updateProfile({
    String? displayName,
    String? phone,
    List<String>? learningInterests,
    String? languagePreference,
    String? avatarUrl,
  }) async {
    state = state.copyWith(isSaving: true, clearFailure: true);
    final result = await _repository.updateProfile(
      displayName: displayName,
      phone: phone,
      learningInterests: learningInterests,
      languagePreference: languagePreference,
      avatarUrl: avatarUrl,
    );
    switch (result) {
      case Success(value: final profile):
        state = state.copyWith(isSaving: false, profile: profile);
        unawaited(
          _analytics?.profileUpdated(
                hasDisplayName: displayName != null && displayName.isNotEmpty,
                hasPhone: phone != null && phone.isNotEmpty,
                interestsCount: profile.learningInterests.length,
                language: profile.languagePreference,
              ) ??
              Future.value(),
        );
        return true;
      case Failure(failure: final failure):
        state = state.copyWith(isSaving: false, failure: failure);
        return false;
    }
  }

  Future<bool> uploadAvatar(List<int> bytes, String fileName) async {
    state = state.copyWith(isSaving: true, clearFailure: true);
    final result = await _repository.uploadAvatar(bytes, fileName);
    switch (result) {
      case Success(value: final avatarUrl):
        final current = state.profile;
        if (current != null) {
          state = state.copyWith(
            isSaving: false,
            profile: current.copyWith(avatarUrl: avatarUrl),
          );
        } else {
          state = state.copyWith(isSaving: false);
        }
        return true;
      case Failure(failure: final failure):
        state = state.copyWith(isSaving: false, failure: failure);
        return false;
    }
  }
}
