import 'package:flutter_test/flutter_test.dart';
import 'package:learning_platform/core/errors/app_failure.dart';
import 'package:learning_platform/core/errors/result.dart';
import 'package:learning_platform/features/profile/application/profile_controller.dart';
import 'package:learning_platform/features/profile/domain/device_session.dart';
import 'package:learning_platform/features/profile/domain/learner_profile.dart';
import 'package:learning_platform/features/profile/domain/profile_repository.dart';

final class _FakeProfileRepository implements ProfileRepository {
  LearnerProfile profile = LearnerProfile(
    id: 'learner_123',
    email: 'test@example.com',
    displayName: 'Test Learner',
    memberSince: DateTime.utc(2026, 1, 1),
    learningInterests: const ['Flutter', 'Dart'],
    languagePreference: 'en',
  );
  bool shouldFail = false;

  @override
  Future<Result<LearnerProfile>> getProfile() async {
    if (shouldFail) {
      return const Failure(
        NetworkFailure(code: 'network_error', message: 'Failed to fetch'),
      );
    }
    return Success(profile);
  }

  @override
  Future<Result<LearnerProfile>> updateProfile({
    String? displayName,
    String? phone,
    List<String>? learningInterests,
    String? languagePreference,
    String? avatarUrl,
  }) async {
    if (shouldFail) {
      return const Failure(
        NetworkFailure(code: 'network_error', message: 'Failed to update'),
      );
    }
    profile = profile.copyWith(
      displayName: displayName,
      phone: phone,
      learningInterests: learningInterests,
      languagePreference: languagePreference,
      avatarUrl: avatarUrl,
    );
    return Success(profile);
  }

  @override
  Future<Result<String>> uploadAvatar(
    List<int> imageBytes,
    String fileName,
  ) async {
    if (shouldFail) {
      return const Failure(
        NetworkFailure(code: 'network_error', message: 'Failed to upload'),
      );
    }
    return const Success('https://cdn.example.com/avatar.jpg');
  }

  @override
  Future<Result<List<DeviceSession>>> getActiveSessions() async =>
      const Success([]);

  @override
  Future<Result<void>> revokeSession(String sessionId) async =>
      const Success(null);

  @override
  Future<Result<int>> revokeOtherSessions() async => const Success(0);

  @override
  Future<Result<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async => const Success(null);

  @override
  Future<Result<void>> deleteAccount({
    required String password,
    required String confirmationText,
  }) async => const Success(null);
}

void main() {
  group('ProfileController', () {
    late _FakeProfileRepository repository;

    setUp(() {
      repository = _FakeProfileRepository();
    });

    test('loads profile on init', () async {
      final controller = ProfileController(repository);
      await controller.loadProfile();

      expect(controller.state.profile, isNotNull);
      expect(controller.state.profile?.displayName, 'Test Learner');
      expect(controller.state.profile?.email, 'test@example.com');
      expect(controller.state.isLoading, isFalse);
    });

    test('handles failure gracefully', () async {
      repository.shouldFail = true;
      final controller = ProfileController(repository);
      await controller.loadProfile();

      expect(controller.state.failure, isNotNull);
      expect(controller.state.isLoading, isFalse);
    });

    test('updates profile successfully', () async {
      final controller = ProfileController(repository);
      await controller.loadProfile();

      final success = await controller.updateProfile(
        displayName: 'Updated Name',
        languagePreference: 'es',
      );

      expect(success, isTrue);
      expect(controller.state.profile?.displayName, 'Updated Name');
      expect(controller.state.profile?.languagePreference, 'es');
      expect(controller.state.isSaving, isFalse);
    });

    test('uploads avatar successfully', () async {
      final controller = ProfileController(repository);
      await controller.loadProfile();

      final success = await controller.uploadAvatar([1, 2, 3], 'avatar.jpg');

      expect(success, isTrue);
      expect(
        controller.state.profile?.avatarUrl,
        'https://cdn.example.com/avatar.jpg',
      );
      expect(controller.state.isSaving, isFalse);
    });
  });
}
