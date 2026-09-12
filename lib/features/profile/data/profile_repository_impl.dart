import 'package:learning_platform/core/errors/app_failure.dart';
import 'package:learning_platform/core/errors/result.dart';
import 'package:learning_platform/features/profile/data/profile_data_source.dart';
import 'package:learning_platform/features/profile/domain/device_session.dart';
import 'package:learning_platform/features/profile/domain/learner_profile.dart';
import 'package:learning_platform/features/profile/domain/profile_repository.dart';

final class ProfileRepositoryImpl implements ProfileRepository {
  const ProfileRepositoryImpl(this._dataSource);
  final ProfileDataSource _dataSource;

  @override
  Future<Result<LearnerProfile>> getProfile() async {
    try {
      final profile = await _dataSource.getProfile();
      return Success(profile);
    } on Object catch (error) {
      if (error is AppFailure) return Failure(error);
      return Failure(
        NetworkFailure(
          code: 'PROFILE_FETCH_FAILED',
          message: 'Failed to load profile: $error',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Result<LearnerProfile>> updateProfile({
    String? displayName,
    String? phone,
    List<String>? learningInterests,
    String? languagePreference,
    String? avatarUrl,
  }) async {
    try {
      final profile = await _dataSource.updateProfile(
        displayName: displayName,
        phone: phone,
        learningInterests: learningInterests,
        languagePreference: languagePreference,
        avatarUrl: avatarUrl,
      );
      return Success(profile);
    } on Object catch (error) {
      if (error is AppFailure) return Failure(error);
      return Failure(
        NetworkFailure(
          code: 'PROFILE_UPDATE_FAILED',
          message: 'Failed to update profile: $error',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Result<String>> uploadAvatar(
    List<int> imageBytes,
    String fileName,
  ) async {
    try {
      if (imageBytes.length > 5 * 1024 * 1024) {
        return const Failure(
          ValidationFailure(
            code: 'AVATAR_SIZE_EXCEEDED',
            message: 'Avatar image must be under 5MB.',
          ),
        );
      }
      final uploadUrl = await _dataSource.getAvatarUploadUrl();
      final avatarUrl = await _dataSource.updateAvatar(uploadUrl);
      return Success(avatarUrl);
    } on Object catch (error) {
      if (error is AppFailure) return Failure(error);
      return Failure(
        NetworkFailure(
          code: 'AVATAR_UPLOAD_FAILED',
          message: 'Failed to upload avatar: $error',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Result<List<DeviceSession>>> getActiveSessions() async {
    try {
      final sessions = await _dataSource.getActiveSessions();
      return Success(sessions);
    } on Object catch (error) {
      if (error is AppFailure) return Failure(error);
      return Failure(
        NetworkFailure(
          code: 'SESSIONS_FETCH_FAILED',
          message: 'Failed to load active sessions: $error',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Result<void>> revokeSession(String sessionId) async {
    try {
      await _dataSource.revokeSession(sessionId);
      return const Success(null);
    } on Object catch (error) {
      if (error is AppFailure) return Failure(error);
      return Failure(
        NetworkFailure(
          code: 'SESSION_REVOKE_FAILED',
          message: 'Failed to revoke session: $error',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Result<int>> revokeOtherSessions() async {
    try {
      final count = await _dataSource.revokeOtherSessions();
      return Success(count);
    } on Object catch (error) {
      if (error is AppFailure) return Failure(error);
      return Failure(
        NetworkFailure(
          code: 'SESSIONS_REVOKE_OTHERS_FAILED',
          message: 'Failed to revoke other sessions: $error',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Result<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _dataSource.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return const Success(null);
    } on Object catch (error) {
      if (error is AppFailure) return Failure(error);
      return Failure(
        AuthFailure(
          code: 'PASSWORD_CHANGE_FAILED',
          message: 'Failed to change password: $error',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Result<void>> deleteAccount({
    required String password,
    required String confirmationText,
  }) async {
    try {
      await _dataSource.deleteAccount(
        password: password,
        confirmationText: confirmationText,
      );
      return const Success(null);
    } on Object catch (error) {
      if (error is AppFailure) return Failure(error);
      return Failure(
        AuthFailure(
          code: 'ACCOUNT_DELETION_FAILED',
          message: 'Failed to delete account: $error',
          cause: error,
        ),
      );
    }
  }
}
