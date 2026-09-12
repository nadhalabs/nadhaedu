import 'package:learning_platform/core/errors/result.dart';
import 'package:learning_platform/core/networking/api_client.dart';
import 'package:learning_platform/features/profile/data/profile_data_source.dart';
import 'package:learning_platform/features/profile/domain/device_session.dart';
import 'package:learning_platform/features/profile/domain/learner_profile.dart';

final class RemoteProfileDataSource implements ProfileDataSource {
  const RemoteProfileDataSource(this._apiClient);
  final ApiClient _apiClient;

  @override
  Future<LearnerProfile> getProfile() async {
    final result = await _apiClient.get('/api/v1/profile');
    switch (result) {
      case Success(value: final data):
        return LearnerProfile.fromJson(data['profile'] as Map<String, dynamic>);
      case Failure(failure: final f):
        throw f;
    }
  }

  @override
  Future<LearnerProfile> updateProfile({
    String? displayName,
    String? phone,
    List<String>? learningInterests,
    String? languagePreference,
    String? avatarUrl,
  }) async {
    final result = await _apiClient.put(
      '/api/v1/profile',
      body: {
        'displayName': ?displayName,
        'phone': ?phone,
        'learningInterests': ?learningInterests,
        'languagePreference': ?languagePreference,
        'avatarUrl': ?avatarUrl,
      },
    );
    switch (result) {
      case Success(value: final data):
        return LearnerProfile.fromJson(data['profile'] as Map<String, dynamic>);
      case Failure(failure: final f):
        throw f;
    }
  }

  @override
  Future<String> getAvatarUploadUrl() async {
    final result = await _apiClient.post('/api/v1/profile/avatar/upload-url');
    switch (result) {
      case Success(value: final data):
        return data['uploadUrl'] as String;
      case Failure(failure: final f):
        throw f;
    }
  }

  @override
  Future<String> updateAvatar(String avatarUrl) async {
    final result = await _apiClient.post(
      '/api/v1/profile/avatar',
      body: {'avatarUrl': avatarUrl},
    );
    switch (result) {
      case Success(value: final data):
        return data['avatarUrl'] as String;
      case Failure(failure: final f):
        throw f;
    }
  }

  @override
  Future<List<DeviceSession>> getActiveSessions() async {
    final result = await _apiClient.get('/api/v1/account/sessions');
    switch (result) {
      case Success(value: final data):
        final list = (data['sessions'] as List<dynamic>?) ?? [];
        return list
            .map((e) => DeviceSession.fromJson(e as Map<String, dynamic>))
            .toList();
      case Failure(failure: final f):
        throw f;
    }
  }

  @override
  Future<void> revokeSession(String sessionId) async {
    final result = await _apiClient.post(
      '/api/v1/account/sessions/$sessionId/revoke',
    );
    if (result case Failure(failure: final f)) {
      throw f;
    }
  }

  @override
  Future<int> revokeOtherSessions() async {
    final result = await _apiClient.post(
      '/api/v1/account/sessions/revoke-others',
    );
    switch (result) {
      case Success(value: final data):
        return (data['revokedCount'] as num?)?.toInt() ?? 0;
      case Failure(failure: final f):
        throw f;
    }
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final result = await _apiClient.post(
      '/api/v1/account/password-change',
      body: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
    if (result case Failure(failure: final f)) {
      throw f;
    }
  }

  @override
  Future<void> deleteAccount({
    required String password,
    required String confirmationText,
  }) async {
    final result = await _apiClient.post(
      '/api/v1/account/delete',
      body: {'password': password, 'confirmationText': confirmationText},
    );
    if (result case Failure(failure: final f)) {
      throw f;
    }
  }
}
