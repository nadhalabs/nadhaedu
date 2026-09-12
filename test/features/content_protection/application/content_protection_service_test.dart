import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_platform/features/content_protection/application/content_protection_service.dart';
import 'package:learning_platform/features/content_protection/data/content_protection_platform.dart';
import 'package:learning_platform/features/content_protection/domain/content_protection_policy.dart';

void main() {
  group('ContentProtectionService Tests', () {
    late MockContentProtectionPlatform mockPlatform;
    late ProviderContainer container;

    setUp(() {
      mockPlatform = MockContentProtectionPlatform();
      container = ProviderContainer(
        overrides: [
          contentProtectionPlatformProvider.overrideWithValue(mockPlatform),
        ],
      );
    });

    tearDown(() {
      container.dispose();
      mockPlatform.dispose();
    });

    test('initial state is idle and unprotected', () {
      final state = container.read(screenCaptureStateProvider);
      expect(state.isProtected, isFalse);
      expect(state.isCaptured, isFalse);
      expect(state.activePolicy, ContentProtectionPolicy.none);
    });

    test(
      'acquiring and releasing protection updates platform and locks',
      () async {
        final service = container.read(
          contentProtectionServiceProvider.notifier,
        );

        await service.acquireProtection(
          ContentProtectionPolicy.blockCaptureWhereSupported,
        );
        expect(service.activeLockCount, 1);
        expect(mockPlatform.enableCallCount, 1);
        expect(
          mockPlatform.lastEnabledPolicy,
          ContentProtectionPolicy.blockCaptureWhereSupported,
        );

        var state = container.read(screenCaptureStateProvider);
        expect(state.isProtected, isTrue);
        expect(
          state.activePolicy,
          ContentProtectionPolicy.blockCaptureWhereSupported,
        );

        // Acquire second nested lock
        await service.acquireProtection(
          ContentProtectionPolicy.blockCaptureWhereSupported,
        );
        expect(service.activeLockCount, 2);
        expect(mockPlatform.enableCallCount, 2);

        // Release first lock - protection remains active
        await service.releaseProtection();
        expect(service.activeLockCount, 1);
        expect(mockPlatform.disableCallCount, 0);
        expect(container.read(screenCaptureStateProvider).isProtected, isTrue);

        // Release second lock - protection is disabled on platform
        await service.releaseProtection();
        expect(service.activeLockCount, 0);
        expect(mockPlatform.disableCallCount, 1);

        state = container.read(screenCaptureStateProvider);
        expect(state.isProtected, isFalse);
        expect(state.activePolicy, ContentProtectionPolicy.none);
      },
    );

    test(
      'resetAll clears all active locks and disables platform flags',
      () async {
        final service = container.read(
          contentProtectionServiceProvider.notifier,
        );

        await service.acquireProtection(
          ContentProtectionPolicy.blockCaptureWhereSupported,
        );
        await service.acquireProtection(
          ContentProtectionPolicy.blockCaptureWhereSupported,
        );
        expect(service.activeLockCount, 2);

        await service.resetAll();
        expect(service.activeLockCount, 0);
        expect(mockPlatform.disableCallCount, 1);
        expect(container.read(screenCaptureStateProvider).isProtected, isFalse);
      },
    );

    test('receives native capture state changed events', () async {
      container.read(contentProtectionServiceProvider);

      mockPlatform.simulateCaptureStateChanged(
        isCaptured: true,
        type: 'screen_recording',
      );
      await Future<void>.delayed(Duration.zero);

      final state = container.read(screenCaptureStateProvider);
      expect(state.isCaptured, isTrue);

      mockPlatform.simulateCaptureStateChanged(isCaptured: false);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(screenCaptureStateProvider).isCaptured, isFalse);
    });

    test('acquiring Policy.none does not alter active locks', () async {
      final service = container.read(contentProtectionServiceProvider.notifier);

      await service.acquireProtection(ContentProtectionPolicy.none);
      expect(service.activeLockCount, 0);
      expect(mockPlatform.enableCallCount, 0);
    });
  });
}
