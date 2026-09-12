import 'package:learning_platform/features/profile/data/profile_data_source.dart';
import 'package:learning_platform/features/profile/domain/device_session.dart';
import 'package:learning_platform/features/profile/domain/learner_profile.dart';

final class FoundationProfileDataSource implements ProfileDataSource {
  FoundationProfileDataSource({LearnerProfile? profile})
    : _profile =
          profile ??
          LearnerProfile(
            id: 'foundation-user-id',
            email: 'learner@example.com',
            displayName: 'Lead Engineer',
            phone: '+1 555 0199',
            learningInterests: const [
              'Flutter',
              'Systems Architecture',
              'Cloud',
            ],
            languagePreference: 'en',
            memberSince: DateTime(2025, 1, 15),
          );

  LearnerProfile _profile;
  final List<DeviceSession> _sessions = [
    DeviceSession(
      id: 'session-curr',
      deviceName: 'Pixel 9 Pro (This device)',
      platform: 'android',
      lastActiveAt: DateTime.now(),
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      isCurrent: true,
    ),
    DeviceSession(
      id: 'session-web',
      deviceName: 'Chrome on macOS',
      platform: 'web',
      lastActiveAt: DateTime.now().subtract(const Duration(hours: 12)),
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
      isCurrent: false,
    ),
  ];

  @override
  Future<LearnerProfile> getProfile() async => _profile;

  @override
  Future<LearnerProfile> updateProfile({
    String? displayName,
    String? phone,
    List<String>? learningInterests,
    String? languagePreference,
    String? avatarUrl,
  }) async {
    _profile = _profile.copyWith(
      displayName: displayName,
      phone: phone,
      learningInterests: learningInterests,
      languagePreference: languagePreference,
      avatarUrl: avatarUrl,
    );
    return _profile;
  }

  @override
  Future<String> getAvatarUploadUrl() async {
    return 'https://storage.learningplatform.internal/avatars/upload/foundation-user-id/intent-123';
  }

  @override
  Future<String> updateAvatar(String avatarUrl) async {
    _profile = _profile.copyWith(avatarUrl: avatarUrl);
    return avatarUrl;
  }

  @override
  Future<List<DeviceSession>> getActiveSessions() async =>
      List.unmodifiable(_sessions);

  @override
  Future<void> revokeSession(String sessionId) async {
    _sessions.removeWhere((s) => s.id == sessionId);
  }

  @override
  Future<int> revokeOtherSessions() async {
    final count = _sessions.where((s) => !s.isCurrent).length;
    _sessions.removeWhere((s) => !s.isCurrent);
    return count;
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {}

  @override
  Future<void> deleteAccount({
    required String password,
    required String confirmationText,
  }) async {}
}
