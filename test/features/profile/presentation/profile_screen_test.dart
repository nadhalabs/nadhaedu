import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_platform/core/errors/result.dart';
import 'package:learning_platform/features/profile/application/profile_providers.dart';
import 'package:learning_platform/features/profile/domain/device_session.dart';
import 'package:learning_platform/features/profile/domain/learner_profile.dart';
import 'package:learning_platform/features/profile/domain/profile_repository.dart';
import 'package:learning_platform/features/profile/presentation/profile_screen.dart';

final class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository(this.profile);
  final LearnerProfile profile;

  @override
  Future<Result<LearnerProfile>> getProfile() async => Success(profile);

  @override
  Future<Result<LearnerProfile>> updateProfile({
    String? displayName,
    String? phone,
    List<String>? learningInterests,
    String? languagePreference,
    String? avatarUrl,
  }) async => Success(profile);

  @override
  Future<Result<String>> uploadAvatar(
    List<int> imageBytes,
    String fileName,
  ) async => const Success('https://example.com/avatar.jpg');

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
  testWidgets('ProfileScreen renders learner profile and navigation cards', (
    tester,
  ) async {
    final profile = LearnerProfile(
      id: 'learner_1',
      email: 'jane.doe@example.com',
      displayName: 'Jane Doe',
      phone: '+1-555-0100',
      learningInterests: const ['Flutter', 'Systems Design'],
      memberSince: DateTime.utc(2025, 1, 1),
    );

    final repo = _FakeProfileRepository(profile);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [profileRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Profile & Account'), findsOneWidget);
    expect(find.text('Jane Doe'), findsOneWidget);
    expect(find.text('jane.doe@example.com'), findsOneWidget);
    expect(find.text('+1-555-0100'), findsOneWidget);
    expect(find.text('Flutter'), findsOneWidget);
    expect(find.text('Systems Design'), findsOneWidget);

    expect(find.text('My Certificates'), findsOneWidget);
    expect(find.text('Downloads & Storage'), findsOneWidget);
    expect(find.text('Subscription & Billing'), findsOneWidget);
    expect(find.text('Account & Security'), findsOneWidget);
    expect(find.text('Settings & Preferences'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Sign Out'), 200);
    expect(find.text('Sign Out'), findsOneWidget);
  });
}
