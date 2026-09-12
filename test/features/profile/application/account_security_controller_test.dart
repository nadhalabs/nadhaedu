import 'package:flutter_test/flutter_test.dart';
import 'package:learning_platform/core/errors/app_failure.dart';
import 'package:learning_platform/core/errors/result.dart';
import 'package:learning_platform/features/profile/application/account_security_controller.dart';
import 'package:learning_platform/features/profile/domain/device_session.dart';
import 'package:learning_platform/features/profile/domain/learner_profile.dart';
import 'package:learning_platform/features/profile/domain/profile_repository.dart';

final class _FakeProfileRepository implements ProfileRepository {
  bool shouldFail = false;

  @override
  Future<Result<LearnerProfile>> getProfile() async =>
      throw UnimplementedError();

  @override
  Future<Result<LearnerProfile>> updateProfile({
    String? displayName,
    String? phone,
    List<String>? learningInterests,
    String? languagePreference,
    String? avatarUrl,
  }) async => throw UnimplementedError();

  @override
  Future<Result<String>> uploadAvatar(
    List<int> imageBytes,
    String fileName,
  ) async => throw UnimplementedError();

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
  }) async {
    if (shouldFail) {
      return const Failure(
        ValidationFailure(
          code: 'invalid_password',
          message: 'Current password wrong',
        ),
      );
    }
    return const Success(null);
  }

  @override
  Future<Result<void>> deleteAccount({
    required String password,
    required String confirmationText,
  }) async {
    if (shouldFail) {
      return const Failure(
        ValidationFailure(
          code: 'deletion_failed',
          message: 'Deletion rejected',
        ),
      );
    }
    return const Success(null);
  }
}

void main() {
  group('AccountSecurityController', () {
    late _FakeProfileRepository repository;

    setUp(() {
      repository = _FakeProfileRepository();
    });

    test('changes password successfully', () async {
      final controller = AccountSecurityController(repository);

      final success = await controller.changePassword(
        currentPassword: 'old-password',
        newPassword: 'new-password-123',
      );

      expect(success, isTrue);
      expect(controller.state.successMessage, isNotNull);
      expect(controller.state.failure, isNull);
    });

    test('handles change password failure', () async {
      repository.shouldFail = true;
      final controller = AccountSecurityController(repository);

      final success = await controller.changePassword(
        currentPassword: 'wrong-password',
        newPassword: 'new-password-123',
      );

      expect(success, isFalse);
      expect(controller.state.failure, isNotNull);
    });

    test('deletes account successfully', () async {
      final controller = AccountSecurityController(repository);

      final success = await controller.deleteAccount(
        password: 'correct-password',
        confirmationText: 'DELETE',
      );

      expect(success, isTrue);
      expect(controller.state.failure, isNull);
    });
  });
}
