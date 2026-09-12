import 'package:flutter_test/flutter_test.dart';
import 'package:learning_platform/core/errors/app_failure.dart';
import 'package:learning_platform/core/errors/result.dart';
import 'package:learning_platform/features/profile/application/session_management_controller.dart';
import 'package:learning_platform/features/profile/domain/device_session.dart';
import 'package:learning_platform/features/profile/domain/learner_profile.dart';
import 'package:learning_platform/features/profile/domain/profile_repository.dart';

final class _FakeProfileRepository implements ProfileRepository {
  List<DeviceSession> sessions = [
    DeviceSession(
      id: 'sess_1',
      deviceName: 'Chrome on macOS',
      platform: 'macos',
      lastActiveAt: DateTime.utc(2026, 1, 1),
      createdAt: DateTime.utc(2026, 1, 1),
      isCurrent: true,
    ),
    DeviceSession(
      id: 'sess_2',
      deviceName: 'Pixel 8',
      platform: 'android',
      lastActiveAt: DateTime.utc(2026, 1, 1),
      createdAt: DateTime.utc(2026, 1, 1),
      isCurrent: false,
    ),
  ];
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
  Future<Result<List<DeviceSession>>> getActiveSessions() async {
    if (shouldFail) {
      return const Failure(
        NetworkFailure(
          code: 'network_error',
          message: 'Failed to fetch sessions',
        ),
      );
    }
    return Success(sessions);
  }

  @override
  Future<Result<void>> revokeSession(String sessionId) async {
    if (shouldFail) {
      return const Failure(
        NetworkFailure(code: 'network_error', message: 'Failed to revoke'),
      );
    }
    sessions = sessions.where((s) => s.id != sessionId).toList();
    return const Success(null);
  }

  @override
  Future<Result<int>> revokeOtherSessions() async {
    if (shouldFail) {
      return const Failure(
        NetworkFailure(code: 'network_error', message: 'Failed to revoke all'),
      );
    }
    final count = sessions.where((s) => !s.isCurrent).length;
    sessions = sessions.where((s) => s.isCurrent).toList();
    return Success(count);
  }

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
  group('SessionManagementController', () {
    late _FakeProfileRepository repository;

    setUp(() {
      repository = _FakeProfileRepository();
    });

    test('loads sessions on init', () async {
      final controller = SessionManagementController(repository);
      await controller.loadSessions();

      expect(controller.state.sessions.length, 2);
      expect(controller.state.sessions.first.isCurrent, isTrue);
      expect(controller.state.isLoading, isFalse);
    });

    test('revokes single session successfully', () async {
      final controller = SessionManagementController(repository);
      await controller.loadSessions();

      final success = await controller.revokeSession('sess_2');

      expect(success, isTrue);
      expect(controller.state.sessions.length, 1);
      expect(controller.state.sessions.first.id, 'sess_1');
    });

    test('revokes all other sessions successfully', () async {
      final controller = SessionManagementController(repository);
      await controller.loadSessions();

      final success = await controller.revokeOtherSessions();

      expect(success, isTrue);
      expect(controller.state.sessions.length, 1);
      expect(controller.state.sessions.first.isCurrent, isTrue);
    });
  });
}
