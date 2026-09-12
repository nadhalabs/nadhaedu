import 'package:learning_platform/core/errors/result.dart';
import 'package:learning_platform/features/profile/domain/device_session.dart';
import 'package:learning_platform/features/profile/domain/learner_profile.dart';

abstract interface class ProfileRepository {
  Future<Result<LearnerProfile>> getProfile();

  Future<Result<LearnerProfile>> updateProfile({
    String? displayName,
    String? phone,
    List<String>? learningInterests,
    String? languagePreference,
    String? avatarUrl,
  });

  Future<Result<String>> uploadAvatar(List<int> imageBytes, String fileName);

  Future<Result<List<DeviceSession>>> getActiveSessions();

  Future<Result<void>> revokeSession(String sessionId);

  Future<Result<int>> revokeOtherSessions();

  Future<Result<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<Result<void>> deleteAccount({
    required String password,
    required String confirmationText,
  });
}
