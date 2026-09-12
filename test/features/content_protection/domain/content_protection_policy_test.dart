import 'package:flutter_test/flutter_test.dart';
import 'package:learning_platform/features/content_catalog/domain/course.dart';
import 'package:learning_platform/features/content_protection/domain/content_protection_policy.dart';
import 'package:learning_platform/features/entitlements/domain/access_policy.dart';

void main() {
  group('ContentProtectionPolicy Domain Tests', () {
    test('policy flags evaluate correctly', () {
      expect(
        ContentProtectionPolicy.none.requiresPlatformWindowSecurity,
        isFalse,
      );
      expect(ContentProtectionPolicy.none.requiresCaptureRedaction, isFalse);

      expect(
        ContentProtectionPolicy
            .discourageCapture
            .requiresPlatformWindowSecurity,
        isFalse,
      );
      expect(
        ContentProtectionPolicy.discourageCapture.requiresCaptureRedaction,
        isFalse,
      );

      expect(
        ContentProtectionPolicy
            .blockCaptureWhereSupported
            .requiresPlatformWindowSecurity,
        isTrue,
      );
      expect(
        ContentProtectionPolicy
            .blockCaptureWhereSupported
            .requiresCaptureRedaction,
        isTrue,
      );

      expect(
        ContentProtectionPolicy.drmRequired.requiresPlatformWindowSecurity,
        isTrue,
      );
      expect(
        ContentProtectionPolicy.drmRequired.requiresCaptureRedaction,
        isTrue,
      );
    });

    test('ScreenCaptureState redaction logic', () {
      const uncaptured = ScreenCaptureState(
        isCaptured: false,
        isProtected: true,
        activePolicy: ContentProtectionPolicy.blockCaptureWhereSupported,
      );
      expect(uncaptured.isContentRedacted, isFalse);

      const capturedProtected = ScreenCaptureState(
        isCaptured: true,
        isProtected: true,
        activePolicy: ContentProtectionPolicy.blockCaptureWhereSupported,
      );
      expect(capturedProtected.isContentRedacted, isTrue);

      const capturedDiscouraged = ScreenCaptureState(
        isCaptured: true,
        isProtected: false,
        activePolicy: ContentProtectionPolicy.discourageCapture,
      );
      expect(capturedDiscouraged.isContentRedacted, isFalse);

      const capturedNone = ScreenCaptureState(
        isCaptured: true,
        isProtected: false,
        activePolicy: ContentProtectionPolicy.none,
      );
      expect(capturedNone.isContentRedacted, isFalse);
    });

    test('CourseSummary effective protection policy defaults', () {
      final freeCourse = CourseSummary(
        id: 'c_free',
        title: 'Free Course',
        subtitle: '',
        instructors: [],
        categoryIds: {},
        level: CourseLevel.beginner,
        policy: const AccessPolicy.free(),
        languageCode: 'en',
        rating: 4.8,
        ratingCount: 10,
        duration: Duration.zero,
        lessonCount: 5,
        publishedAt: DateTime.now(),
        tags: {},
      );
      expect(
        freeCourse.effectiveProtectionPolicy,
        ContentProtectionPolicy.none,
      );

      final premiumCourse = CourseSummary(
        id: 'c_prem',
        title: 'Premium Course',
        subtitle: '',
        instructors: [],
        categoryIds: {},
        level: CourseLevel.advanced,
        policy: const AccessPolicy.premium(),
        languageCode: 'en',
        rating: 4.9,
        ratingCount: 20,
        duration: Duration.zero,
        lessonCount: 12,
        publishedAt: DateTime.now(),
        tags: {},
      );
      expect(
        premiumCourse.effectiveProtectionPolicy,
        ContentProtectionPolicy.blockCaptureWhereSupported,
      );
    });

    test('Lesson resolves protection policy with course inheritance', () {
      const regularLesson = Lesson(
        id: 'l_reg',
        title: 'Lesson 1',
        position: 1,
        estimatedDuration: Duration(minutes: 10),
        content: VideoLessonContent(assetId: 'vid_1'),
        isPreview: false,
      );
      expect(
        regularLesson.resolveProtectionPolicy(
          ContentProtectionPolicy.blockCaptureWhereSupported,
        ),
        ContentProtectionPolicy.blockCaptureWhereSupported,
      );
      expect(
        regularLesson.resolveProtectionPolicy(ContentProtectionPolicy.none),
        ContentProtectionPolicy.none,
      );

      const previewLesson = Lesson(
        id: 'l_prev',
        title: 'Preview Lesson',
        position: 0,
        estimatedDuration: Duration(minutes: 5),
        content: VideoLessonContent(assetId: 'vid_0'),
        isPreview: true,
      );
      // Previews are free and do not enforce window capture blocking
      expect(
        previewLesson.resolveProtectionPolicy(
          ContentProtectionPolicy.blockCaptureWhereSupported,
        ),
        ContentProtectionPolicy.none,
      );
    });
  });
}
