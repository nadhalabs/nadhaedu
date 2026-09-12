import 'package:learning_platform/features/profile/domain/device_session.dart';
import 'package:learning_platform/features/profile/domain/learner_profile.dart';

abstract interface class ProfileDataSource {
  Future<LearnerProfile> getProfile();

  Future<LearnerProfile> updateProfile({
    String? displayName,
    String? phone,
    List<String>? learningInterests,
    String? languagePreference,
    String? avatarUrl,
  });

  Future<String> getAvatarUploadUrl();

  Future<String> updateAvatar(String avatarUrl);

  Future<List<DeviceSession>> getActiveSessions();

  Future<void> revokeSession(String sessionId);

  Future<int> revokeOtherSessions();

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<void> deleteAccount({
    required String password,
    required String confirmationText,
  });
}
