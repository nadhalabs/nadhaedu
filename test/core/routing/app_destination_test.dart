import 'package:flutter_test/flutter_test.dart';
import 'package:learning_platform/core/routing/app_destination.dart';

void main() {
  group('AppDestination.parse', () {
    test('parses root and home', () {
      expect(AppDestination.parse(Uri.parse('/')), const AppDestinationHome());
      expect(
        AppDestination.parse(Uri.parse('/home')),
        const AppDestinationHome(),
      );
    });

    test('parses discover and search', () {
      expect(
        AppDestination.parse(Uri.parse('/discover')),
        const AppDestinationDiscover(),
      );
      expect(
        AppDestination.parse(Uri.parse('/search?q=flutter')),
        const AppDestinationSearch('flutter'),
      );
    });

    test('parses course and lesson routes', () {
      expect(
        AppDestination.parse(Uri.parse('/courses/course-123')),
        const AppDestinationCourse('course-123'),
      );
      expect(
        AppDestination.parse(
          Uri.parse('/courses/course-123/lesson/lesson-456'),
        ),
        const AppDestinationLesson(
          courseId: 'course-123',
          lessonId: 'lesson-456',
        ),
      );
      expect(
        AppDestination.parse(Uri.parse('/learn/course-123?lesson=lesson-456')),
        const AppDestinationLesson(
          courseId: 'course-123',
          lessonId: 'lesson-456',
        ),
      );
    });

    test('parses paywall and subscription routes', () {
      expect(
        AppDestination.parse(Uri.parse('/paywall?source=banner')),
        const AppDestinationPaywall(source: 'banner'),
      );
      expect(
        AppDestination.parse(Uri.parse('/subscription')),
        const AppDestinationSubscription(),
      );
    });

    test('parses certificates and downloads', () {
      expect(
        AppDestination.parse(Uri.parse('/certificates')),
        const AppDestinationCertificates(),
      );
      expect(
        AppDestination.parse(Uri.parse('/certificates/cert-789')),
        const AppDestinationCertificate('cert-789'),
      );
      expect(
        AppDestination.parse(Uri.parse('/downloads')),
        const AppDestinationDownloads(),
      );
    });

    test('parses notifications and settings', () {
      expect(
        AppDestination.parse(Uri.parse('/notifications')),
        const AppDestinationNotifications(),
      );
      expect(
        AppDestination.parse(Uri.parse('/settings/notifications')),
        const AppDestinationNotificationPreferences(),
      );
      expect(
        AppDestination.parse(Uri.parse('/settings')),
        const AppDestinationSettings(),
      );
    });

    test('parses profile and account routes', () {
      expect(
        AppDestination.parse(Uri.parse('/profile')),
        const AppDestinationProfile(),
      );
      expect(
        AppDestination.parse(Uri.parse('/profile/edit')),
        const AppDestinationEditProfile(),
      );
      expect(
        AppDestination.parse(Uri.parse('/account/sessions')),
        const AppDestinationSessions(),
      );
      expect(
        AppDestination.parse(Uri.parse('/account/security')),
        const AppDestinationSecurity(),
      );
    });

    test('student app no longer recognizes admin routes', () {
      final destination = AppDestination.parse(Uri.parse('/admin/dashboard'));
      expect(destination, isA<AppDestinationUnavailable>());
    });

    test('sanitizes and detects malformed or path traversal links', () {
      final destMalformed = AppDestination.parse(Uri(path: '/courses//secret'));
      expect(destMalformed, isA<AppDestinationUnavailable>());
      expect(
        (destMalformed as AppDestinationUnavailable).title,
        'Malformed Link',
      );

      final destInvalid = AppDestination.parse(
        Uri.parse('/invalid/nonexistent/deep/path'),
      );
      expect(destInvalid, isA<AppDestinationUnavailable>());
      expect(
        (destInvalid as AppDestinationUnavailable).title,
        'Unrecognized Link',
      );

      final hostileOrigin = AppDestination.parse(
        Uri.parse('https://evil.example/courses/course-123'),
      );
      expect(hostileOrigin, isA<AppDestinationUnavailable>());
      expect(
        (hostileOrigin as AppDestinationUnavailable).title,
        'Untrusted Link',
      );
    });

    test('verifies isProtected flags', () {
      expect(const AppDestinationUnavailable(message: '').isProtected, isFalse);
      expect(const AppDestinationHome().isProtected, isTrue);
      expect(const AppDestinationDiscover().isProtected, isTrue);
      expect(const AppDestinationCourse('1').isProtected, isTrue);
      expect(const AppDestinationProfile().isProtected, isTrue);
      expect(const AppDestinationEditProfile().isProtected, isTrue);
      expect(const AppDestinationSessions().isProtected, isTrue);
      expect(const AppDestinationSecurity().isProtected, isTrue);
      expect(const AppDestinationNotifications().isProtected, isTrue);
      expect(const AppDestinationNotificationPreferences().isProtected, isTrue);
      expect(const AppDestinationCertificates().isProtected, isTrue);
      expect(const AppDestinationDownloads().isProtected, isTrue);
    });
  });
}
