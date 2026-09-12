import 'package:flutter/foundation.dart';

@immutable
sealed class AppDestination {
  const AppDestination();

  String toLocation();
  bool get isProtected;

  static const home = AppDestinationHome();
  static const discover = AppDestinationDiscover();
  static const bookmarks = AppDestinationBookmarks();
  static const myLearning = AppDestinationMyLearning();
  static const certificates = AppDestinationCertificates();
  static const downloads = AppDestinationDownloads();
  static const subscription = AppDestinationSubscription();
  static const notifications = AppDestinationNotifications();
  static const profile = AppDestinationProfile();
  static const editProfile = AppDestinationEditProfile();
  static const sessions = AppDestinationSessions();
  static const security = AppDestinationSecurity();
  static const settings = AppDestinationSettings();
  static const notificationPreferences =
      AppDestinationNotificationPreferences();
  static const none = AppDestinationNone();

  static AppDestination search([String? query]) => AppDestinationSearch(query);
  static AppDestination course(String id) => AppDestinationCourse(id);
  static AppDestination lesson(String courseId, String lessonId) =>
      AppDestinationLesson(courseId: courseId, lessonId: lessonId);
  static AppDestination assessment(String id) => AppDestinationAssessment(id);
  static AppDestination certificate(String id) => AppDestinationCertificate(id);
  static AppDestination verifyCredential(String id) =>
      AppDestinationVerifyCredential(id);
  static AppDestination paywall([String? source]) =>
      AppDestinationPaywall(source: source ?? 'direct');
  static AppDestination unavailable({
    required String message,
    String title = 'Resource Unavailable',
  }) => AppDestinationUnavailable(message: message, title: title);

  /// Centralized parser that sanitizes and converts URIs into typed destinations.
  static AppDestination parse(Uri uri) {
    // Platform link handlers must validate their configured host before passing
    // only the relative path/query into this parser.
    if (uri.hasScheme || uri.hasAuthority || uri.host.isNotEmpty) {
      return AppDestination.unavailable(
        message:
            'External link origins are not accepted by the internal router.',
        title: 'Untrusted Link',
      );
    }

    // 1. Sanitize against path traversal and dangerous path forms.
    final path = uri.path.trim();
    if (path.contains('..') ||
        path.contains('//') ||
        path.contains(r'\') ||
        path.contains('<') ||
        path.contains('>')) {
      return AppDestination.unavailable(
        message: 'Invalid link format detected.',
        title: 'Malformed Link',
      );
    }

    final segments = uri.pathSegments
        .where((s) => s.isNotEmpty)
        .map(Uri.decodeComponent)
        .toList();

    if (segments.isEmpty) {
      return const AppDestinationHome();
    }

    final root = segments[0].toLowerCase();

    switch (root) {
      case 'home':
        return const AppDestinationHome();
      case 'discover':
        return const AppDestinationDiscover();
      case 'search':
        final q = uri.queryParameters['q'] ?? uri.queryParameters['query'];
        return AppDestinationSearch(q);
      case 'bookmarks':
        return const AppDestinationBookmarks();
      case 'my-learning':
      case 'mylearning':
        return const AppDestinationMyLearning();
      case 'courses':
      case 'course':
        if (segments.length >= 4 && segments[2].toLowerCase() == 'lesson') {
          final courseId = _cleanId(segments[1]);
          final lessonId = _cleanId(segments[3]);
          if (courseId == null || lessonId == null) {
            return AppDestination.unavailable(
              message: 'Course or lesson ID is invalid.',
            );
          }
          return AppDestinationLesson(courseId: courseId, lessonId: lessonId);
        } else if (segments.length >= 2) {
          final courseId = _cleanId(segments[1]);
          if (courseId == null) {
            return AppDestination.unavailable(message: 'Course ID is invalid.');
          }
          return AppDestinationCourse(courseId);
        }
        return const AppDestinationDiscover();
      case 'learn':
        if (segments.length >= 2) {
          final courseId = _cleanId(segments[1]);
          final lessonId = _cleanId(
            uri.queryParameters['lesson'] ??
                (segments.length >= 3 ? segments[2] : null),
          );
          if (courseId == null) {
            return AppDestination.unavailable(message: 'Course ID is invalid.');
          }
          if (lessonId != null) {
            return AppDestinationLesson(courseId: courseId, lessonId: lessonId);
          }
          return AppDestinationCourse(courseId);
        }
        return const AppDestinationMyLearning();
      case 'assessments':
      case 'assessment':
        if (segments.length >= 2) {
          final id = _cleanId(segments[1]);
          if (id == null) {
            return AppDestination.unavailable(
              message: 'Assessment ID is invalid.',
            );
          }
          return AppDestinationAssessment(id);
        }
        return const AppDestinationHome();
      case 'certificates':
      case 'certificate':
        if (segments.length >= 2) {
          final id = _cleanId(segments[1]);
          if (id == null) {
            return AppDestination.unavailable(
              message: 'Certificate ID is invalid.',
            );
          }
          return AppDestinationCertificate(id);
        }
        return const AppDestinationCertificates();
      case 'verify':
        if (segments.length >= 2) {
          final id = _cleanId(segments[1]);
          if (id == null) {
            return AppDestination.unavailable(
              message: 'Credential ID is invalid.',
            );
          }
          return AppDestinationVerifyCredential(id);
        }
        return const AppDestinationHome();
      case 'downloads':
        return const AppDestinationDownloads();
      case 'subscription':
      case 'subscriptions':
        return const AppDestinationSubscription();
      case 'paywall':
        return AppDestinationPaywall(
          source: uri.queryParameters['source'] ?? 'direct',
        );
      case 'notifications':
        return const AppDestinationNotifications();
      case 'profile':
        if (segments.length >= 2 && segments[1].toLowerCase() == 'edit') {
          return const AppDestinationEditProfile();
        }
        return const AppDestinationProfile();
      case 'account':
        if (segments.length >= 2) {
          final sub = segments[1].toLowerCase();
          if (sub == 'sessions') return const AppDestinationSessions();
          if (sub == 'security') return const AppDestinationSecurity();
        }
        return const AppDestinationProfile();
      case 'settings':
        if (segments.length == 2 &&
            segments[1].toLowerCase() == 'academic-profile') {
          return const AppDestinationAcademicProfile();
        }
        if (segments.length >= 2 &&
            segments[1].toLowerCase() == 'notifications') {
          return const AppDestinationNotificationPreferences();
        }
        return const AppDestinationSettings();
      case 'unavailable':
        return AppDestinationUnavailable(
          message:
              uri.queryParameters['message'] ?? 'This resource is unavailable.',
          title: uri.queryParameters['title'] ?? 'Resource Unavailable',
        );
      default:
        return AppDestination.unavailable(
          message: 'The requested link is not recognized by this platform.',
          title: 'Unrecognized Link',
        );
    }
  }

  static String? _cleanId(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty ||
        trimmed.length > 120 ||
        trimmed.contains('..') ||
        trimmed.contains('/') ||
        trimmed.contains(r'\')) {
      return null;
    }
    return trimmed;
  }
}

final class AppDestinationHome extends AppDestination {
  const AppDestinationHome();
  @override
  String toLocation() => '/home';
  @override
  bool get isProtected => true;
  @override
  bool operator ==(Object other) => other is AppDestinationHome;
  @override
  int get hashCode => 1;
}

final class AppDestinationDiscover extends AppDestination {
  const AppDestinationDiscover();
  @override
  String toLocation() => '/discover';
  @override
  bool get isProtected => true;
  @override
  bool operator ==(Object other) => other is AppDestinationDiscover;
  @override
  int get hashCode => 2;
}

final class AppDestinationSearch extends AppDestination {
  const AppDestinationSearch([this.query]);
  final String? query;
  @override
  String toLocation() => query == null || query!.isEmpty
      ? '/search'
      : Uri(path: '/search', queryParameters: {'q': query}).toString();
  @override
  bool get isProtected => true;
  @override
  bool operator ==(Object other) =>
      other is AppDestinationSearch && other.query == query;
  @override
  int get hashCode => query.hashCode ^ 3;
}

final class AppDestinationBookmarks extends AppDestination {
  const AppDestinationBookmarks();
  @override
  String toLocation() => '/bookmarks';
  @override
  bool get isProtected => true;
  @override
  bool operator ==(Object other) => other is AppDestinationBookmarks;
  @override
  int get hashCode => 4;
}

final class AppDestinationMyLearning extends AppDestination {
  const AppDestinationMyLearning();
  @override
  String toLocation() => '/my-learning';
  @override
  bool get isProtected => true;
  @override
  bool operator ==(Object other) => other is AppDestinationMyLearning;
  @override
  int get hashCode => 5;
}

final class AppDestinationCourse extends AppDestination {
  const AppDestinationCourse(this.courseId);
  final String courseId;
  @override
  String toLocation() => '/courses/$courseId';
  @override
  bool get isProtected => true;
  @override
  bool operator ==(Object other) =>
      other is AppDestinationCourse && other.courseId == courseId;
  @override
  int get hashCode => courseId.hashCode ^ 6;
}

final class AppDestinationLesson extends AppDestination {
  const AppDestinationLesson({required this.courseId, required this.lessonId});
  final String courseId;
  final String lessonId;
  @override
  String toLocation() => Uri(
    path: '/learn/$courseId',
    queryParameters: {'lesson': lessonId},
  ).toString();
  @override
  bool get isProtected => true;
  @override
  bool operator ==(Object other) =>
      other is AppDestinationLesson &&
      other.courseId == courseId &&
      other.lessonId == lessonId;
  @override
  int get hashCode => courseId.hashCode ^ lessonId.hashCode ^ 7;
}

final class AppDestinationAssessment extends AppDestination {
  const AppDestinationAssessment(this.assessmentId);
  final String assessmentId;
  @override
  String toLocation() => '/assessments/$assessmentId';
  @override
  bool get isProtected => true;
  @override
  bool operator ==(Object other) =>
      other is AppDestinationAssessment && other.assessmentId == assessmentId;
  @override
  int get hashCode => assessmentId.hashCode ^ 8;
}

final class AppDestinationCertificates extends AppDestination {
  const AppDestinationCertificates();
  @override
  String toLocation() => '/certificates';
  @override
  bool get isProtected => true;
  @override
  bool operator ==(Object other) => other is AppDestinationCertificates;
  @override
  int get hashCode => 9;
}

final class AppDestinationCertificate extends AppDestination {
  const AppDestinationCertificate(this.certificateId);
  final String certificateId;
  @override
  String toLocation() => '/certificates/$certificateId';
  @override
  bool get isProtected => true;
  @override
  bool operator ==(Object other) =>
      other is AppDestinationCertificate &&
      other.certificateId == certificateId;
  @override
  int get hashCode => certificateId.hashCode ^ 10;
}

final class AppDestinationVerifyCredential extends AppDestination {
  const AppDestinationVerifyCredential(this.credentialId);
  final String credentialId;
  @override
  String toLocation() => '/verify/$credentialId';
  @override
  bool get isProtected => false; // Public credential verification
  @override
  bool operator ==(Object other) =>
      other is AppDestinationVerifyCredential &&
      other.credentialId == credentialId;
  @override
  int get hashCode => credentialId.hashCode ^ 11;
}

final class AppDestinationDownloads extends AppDestination {
  const AppDestinationDownloads();
  @override
  String toLocation() => '/downloads';
  @override
  bool get isProtected => true;
  @override
  bool operator ==(Object other) => other is AppDestinationDownloads;
  @override
  int get hashCode => 12;
}

final class AppDestinationSubscription extends AppDestination {
  const AppDestinationSubscription();
  @override
  String toLocation() => '/subscription';
  @override
  bool get isProtected => true;
  @override
  bool operator ==(Object other) => other is AppDestinationSubscription;
  @override
  int get hashCode => 13;
}

final class AppDestinationPaywall extends AppDestination {
  const AppDestinationPaywall({this.source = 'direct'});
  final String source;
  @override
  String toLocation() =>
      Uri(path: '/paywall', queryParameters: {'source': source}).toString();
  @override
  bool get isProtected => true;
  @override
  bool operator ==(Object other) =>
      other is AppDestinationPaywall && other.source == source;
  @override
  int get hashCode => source.hashCode ^ 14;
}

final class AppDestinationNotifications extends AppDestination {
  const AppDestinationNotifications();
  @override
  String toLocation() => '/notifications';
  @override
  bool get isProtected => true;
  @override
  bool operator ==(Object other) => other is AppDestinationNotifications;
  @override
  int get hashCode => 15;
}

final class AppDestinationProfile extends AppDestination {
  const AppDestinationProfile();
  @override
  String toLocation() => '/profile';
  @override
  bool get isProtected => true;
  @override
  bool operator ==(Object other) => other is AppDestinationProfile;
  @override
  int get hashCode => 16;
}

final class AppDestinationEditProfile extends AppDestination {
  const AppDestinationEditProfile();
  @override
  String toLocation() => '/profile/edit';
  @override
  bool get isProtected => true;
  @override
  bool operator ==(Object other) => other is AppDestinationEditProfile;
  @override
  int get hashCode => 17;
}

final class AppDestinationSessions extends AppDestination {
  const AppDestinationSessions();
  @override
  String toLocation() => '/account/sessions';
  @override
  bool get isProtected => true;
  @override
  bool operator ==(Object other) => other is AppDestinationSessions;
  @override
  int get hashCode => 18;
}

final class AppDestinationSecurity extends AppDestination {
  const AppDestinationSecurity();
  @override
  String toLocation() => '/account/security';
  @override
  bool get isProtected => true;
  @override
  bool operator ==(Object other) => other is AppDestinationSecurity;
  @override
  int get hashCode => 19;
}

final class AppDestinationSettings extends AppDestination {
  const AppDestinationSettings();
  @override
  String toLocation() => '/settings';
  @override
  bool get isProtected => true;
  @override
  bool operator ==(Object other) => other is AppDestinationSettings;
  @override
  int get hashCode => 20;
}

final class AppDestinationAcademicProfile extends AppDestination {
  const AppDestinationAcademicProfile();
  @override
  String toLocation() => '/settings/academic-profile';
  @override
  bool get isProtected => true;
  @override
  bool operator ==(Object other) => other is AppDestinationAcademicProfile;
  @override
  int get hashCode => 24;
}

final class AppDestinationNotificationPreferences extends AppDestination {
  const AppDestinationNotificationPreferences();
  @override
  String toLocation() => '/settings/notifications';
  @override
  bool get isProtected => true;
  @override
  bool operator ==(Object other) =>
      other is AppDestinationNotificationPreferences;
  @override
  int get hashCode => 21;
}

final class AppDestinationUnavailable extends AppDestination {
  const AppDestinationUnavailable({
    required this.message,
    this.title = 'Resource Unavailable',
  });
  final String message;
  final String title;
  @override
  String toLocation() => Uri(
    path: '/unavailable',
    queryParameters: {'message': message, 'title': title},
  ).toString();
  @override
  bool get isProtected => false;
  @override
  bool operator ==(Object other) =>
      other is AppDestinationUnavailable &&
      other.message == message &&
      other.title == title;
  @override
  int get hashCode => message.hashCode ^ title.hashCode ^ 22;
}

final class AppDestinationNone extends AppDestination {
  const AppDestinationNone();
  @override
  String toLocation() => '/home';
  @override
  bool get isProtected => true;
  @override
  bool operator ==(Object other) => other is AppDestinationNone;
  @override
  int get hashCode => 0;
}
