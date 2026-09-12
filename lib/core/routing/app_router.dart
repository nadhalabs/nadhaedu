import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_platform/core/motion/app_motion.dart';
import 'package:learning_platform/core/routing/app_destination.dart';
import 'package:learning_platform/core/widgets/unavailable_resource_screen.dart';
import 'package:learning_platform/features/academic/academic_profile_screen.dart';
import 'package:learning_platform/features/app_shell/presentation/app_shell.dart';
import 'package:learning_platform/features/app_shell/presentation/home_screen.dart';
import 'package:learning_platform/features/assessments/presentation/assessment_screen.dart';
import 'package:learning_platform/features/authentication/application/auth_providers.dart';
import 'package:learning_platform/features/authentication/application/auth_state.dart';
import 'package:learning_platform/features/authentication/presentation/login_screen.dart';
import 'package:learning_platform/features/authentication/presentation/onboarding_screen.dart';
import 'package:learning_platform/features/authentication/presentation/recovery_screen.dart';
import 'package:learning_platform/features/authentication/presentation/registration_screen.dart';
import 'package:learning_platform/features/authentication/presentation/session_expired_screen.dart';
import 'package:learning_platform/features/authentication/presentation/splash_screen.dart';
import 'package:learning_platform/features/certificates/presentation/certificate_detail_screen.dart';
import 'package:learning_platform/features/certificates/presentation/certificate_verification_screen.dart';
import 'package:learning_platform/features/certificates/presentation/certificates_screen.dart';
import 'package:learning_platform/features/commerce/presentation/screens/paywall_screen.dart';
import 'package:learning_platform/features/commerce/presentation/screens/subscription_management_screen.dart';
import 'package:learning_platform/features/content_catalog/presentation/bookmarks_screen.dart';
import 'package:learning_platform/features/content_catalog/presentation/categories_screen.dart';
import 'package:learning_platform/features/content_catalog/presentation/course_detail_screen.dart';
import 'package:learning_platform/features/content_catalog/presentation/discovery_screen.dart';
import 'package:learning_platform/features/content_catalog/presentation/my_learning_screen.dart';
import 'package:learning_platform/features/content_catalog/presentation/search_screen.dart';
import 'package:learning_platform/features/downloads/presentation/downloads_screen.dart';
import 'package:learning_platform/features/learning_progress/presentation/learning_screen.dart';
import 'package:learning_platform/features/notifications/presentation/notification_preferences_screen.dart';
import 'package:learning_platform/features/notifications/presentation/notifications_screen.dart';
import 'package:learning_platform/features/profile/presentation/account_security_screen.dart';
import 'package:learning_platform/features/profile/presentation/edit_profile_screen.dart';
import 'package:learning_platform/features/profile/presentation/profile_screen.dart';
import 'package:learning_platform/features/profile/presentation/session_management_screen.dart';
import 'package:learning_platform/features/settings/presentation/settings_screen.dart';

abstract final class AppRoutes {
  static const splash = '/';
  static const login = '/sign-in';
  static const registration = '/register';
  static const recovery = '/recover-account';
  static const onboarding = '/onboarding';
  static const home = '/home';
  static const discover = '/discover';
  static const search = '/search';
  static const bookmarks = '/bookmarks';
  static const myLearning = '/my-learning';
  static const categories = '/categories';
  static const certificates = '/certificates';
  static const paywall = '/paywall';
  static const subscriptionManagement = '/subscription';
  static const downloads = '/downloads';
  static const sessionExpired = '/session-expired';
  static const notifications = '/notifications';
  static const notificationPreferences = '/settings/notifications';
  static const profile = '/profile';
  static const editProfile = '/profile/edit';
  static const sessions = '/account/sessions';
  static const security = '/account/security';
  static const settings = '/settings';
  static const unavailable = '/unavailable';

  static String course(String id) => '/courses/$id';
  static String certificate(String id) => '/certificates/$id';
  static String assessment(String id) => '/assessments/$id';
  static String verify(String credentialId) => '/verify/$credentialId';
  static String learn(String courseId, {String? lessonId}) => Uri(
    path: '/learn/$courseId',
    queryParameters: lessonId == null ? null : {'lesson': lessonId},
  ).toString();
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (previous, next) {
    if (previous?.status != next.status) refresh.value++;
  });
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    redirect: (context, state) =>
        _redirect(ref.read(authControllerProvider), state),
    routes: [
      GoRoute(
        path: '/settings/academic-profile',
        builder: (_, _) => const AcademicProfileScreen(),
      ),
      _animatedRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      _animatedRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      _animatedRoute(
        path: AppRoutes.registration,
        builder: (context, state) => const RegistrationScreen(),
      ),
      _animatedRoute(
        path: AppRoutes.recovery,
        builder: (context, state) => RecoveryScreen(
          initialEmail: state.uri.queryParameters['email'],
          resetToken: state.uri.queryParameters['token'],
        ),
      ),
      _animatedRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      _animatedRoute(
        path: AppRoutes.sessionExpired,
        builder: (context, state) => const SessionExpiredScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          _animatedRoute(
            path: AppRoutes.home,
            builder: (context, state) => const HomeScreen(),
          ),
          _animatedRoute(
            path: AppRoutes.discover,
            builder: (context, state) => const DiscoveryScreen(),
          ),
          _animatedRoute(
            path: AppRoutes.search,
            builder: (context, state) => const CourseSearchScreen(),
          ),
          _animatedRoute(
            path: AppRoutes.bookmarks,
            builder: (context, state) => const BookmarksScreen(),
          ),
          _animatedRoute(
            path: AppRoutes.myLearning,
            builder: (context, state) => const MyLearningScreen(),
          ),
          _animatedRoute(
            path: AppRoutes.profile,
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
      _animatedRoute(
        path: AppRoutes.categories,
        builder: (context, state) => const CategoriesScreen(),
      ),
      _animatedRoute(
        path: '/courses/:courseId',
        builder: (context, state) =>
            CourseDetailScreen(courseId: state.pathParameters['courseId']!),
      ),
      _animatedRoute(
        path: '/learn/:courseId',
        builder: (context, state) => LearningScreen(
          courseId: state.pathParameters['courseId']!,
          initialLessonId: state.uri.queryParameters['lesson'],
        ),
      ),
      _animatedRoute(
        path: '/assessments/:assessmentId',
        builder: (context, state) => AssessmentScreen(
          assessmentId: state.pathParameters['assessmentId']!,
        ),
      ),
      _animatedRoute(
        path: AppRoutes.certificates,
        builder: (context, state) => const CertificatesScreen(),
      ),
      _animatedRoute(
        path: '/certificates/:certificateId',
        builder: (context, state) => CertificateDetailScreen(
          certificateId: state.pathParameters['certificateId']!,
        ),
      ),
      _animatedRoute(
        path: '/verify/:credentialId',
        builder: (context, state) => CertificateVerificationScreen(
          credentialId: state.pathParameters['credentialId']!,
        ),
      ),
      _animatedRoute(
        path: AppRoutes.paywall,
        builder: (context, state) => PaywallScreen(
          source: state.uri.queryParameters['source'] ?? 'direct',
        ),
      ),
      _animatedRoute(
        path: AppRoutes.subscriptionManagement,
        builder: (context, state) => const SubscriptionManagementScreen(),
      ),
      _animatedRoute(
        path: AppRoutes.downloads,
        builder: (context, state) => const DownloadsScreen(),
      ),
      _animatedRoute(
        path: AppRoutes.notifications,
        builder: (context, state) => const NotificationsScreen(),
      ),
      _animatedRoute(
        path: AppRoutes.notificationPreferences,
        builder: (context, state) => const NotificationPreferencesScreen(),
      ),
      _animatedRoute(
        path: AppRoutes.editProfile,
        builder: (context, state) => const EditProfileScreen(),
      ),
      _animatedRoute(
        path: AppRoutes.sessions,
        builder: (context, state) => const SessionManagementScreen(),
      ),
      _animatedRoute(
        path: AppRoutes.security,
        builder: (context, state) => const AccountSecurityScreen(),
      ),
      _animatedRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      _animatedRoute(
        path: AppRoutes.unavailable,
        builder: (context, state) => UnavailableResourceScreen(
          title: state.uri.queryParameters['title'] ?? 'Resource Unavailable',
          message:
              state.uri.queryParameters['message'] ??
              'The requested resource could not be found or is no longer available.',
        ),
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});

String? _redirect(AuthState authState, GoRouterState state) {
  final location = state.matchedLocation;
  final fullUri = state.uri.toString();

  final isPublic =
      location == AppRoutes.login ||
      location == AppRoutes.registration ||
      location == AppRoutes.recovery ||
      location.startsWith('/verify') ||
      location == AppRoutes.unavailable;

  return switch (authState.status) {
    AuthStatus.bootstrapping || AuthStatus.bootstrapFailure =>
      location == AppRoutes.splash ? null : AppRoutes.splash,
    AuthStatus.unauthenticated =>
      isPublic
          ? null
          : fullUri == AppRoutes.splash
          ? AppRoutes.login
          : Uri(
              path: AppRoutes.login,
              queryParameters: {'redirect': fullUri},
            ).toString(),
    AuthStatus.expired =>
      isPublic || location == AppRoutes.sessionExpired
          ? null
          : AppRoutes.sessionExpired,
    AuthStatus.onboardingRequired =>
      location == AppRoutes.onboarding ? null : AppRoutes.onboarding,
    AuthStatus.authenticated => _resolveAuthenticatedDestination(
      authState,
      state,
      location,
    ),
  };
}

String? _resolveAuthenticatedDestination(
  AuthState authState,
  GoRouterState state,
  String location,
) {
  if (location == AppRoutes.splash ||
      location == AppRoutes.onboarding ||
      location == AppRoutes.login ||
      location == AppRoutes.registration) {
    final redirectParam = state.uri.queryParameters['redirect'];
    if (redirectParam != null &&
        redirectParam.isNotEmpty &&
        redirectParam.startsWith('/') &&
        !redirectParam.startsWith('//') &&
        !redirectParam.contains('..')) {
      final parsed = Uri.tryParse(redirectParam);
      if (parsed != null) {
        final destination = AppDestination.parse(parsed);
        if (destination is! AppDestinationUnavailable) {
          final targetLoc = destination.toLocation();
          return targetLoc;
        }
      }
    }
    return AppRoutes.home;
  }
  return null;
}

GoRoute _animatedRoute({
  required String path,
  required GoRouterWidgetBuilder builder,
}) => GoRoute(
  path: path,
  pageBuilder: (context, state) => CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: AppMotion.duration(context, AppMotion.navigation),
    reverseTransitionDuration: AppMotion.duration(context, AppMotion.standard),
    child: builder(context, state),
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        AppMotion.transition(context, animation, child),
  ),
);
