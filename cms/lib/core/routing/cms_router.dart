import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nadha_cms/features/authentication/application/auth_providers.dart';
import 'package:nadha_cms/features/authentication/application/auth_state.dart';
import 'package:nadha_cms/features/authentication/presentation/cms_login_screen.dart';
import 'package:nadha_cms/features/cms/academic.dart';
import 'package:nadha_cms/features/cms/content_items.dart';
import 'package:nadha_cms/features/cms/presentation/screens/cms_assessment_editor_screen.dart';
import 'package:nadha_cms/features/cms/presentation/screens/cms_audit_logs_screen.dart';
import 'package:nadha_cms/features/cms/presentation/screens/cms_course_editor_screen.dart';
import 'package:nadha_cms/features/cms/presentation/screens/cms_courses_screen.dart';
import 'package:nadha_cms/features/cms/presentation/screens/cms_dashboard_screen.dart';
import 'package:nadha_cms/features/cms/presentation/screens/cms_system_health_screen.dart';
import 'package:nadha_cms/features/cms/presentation/screens/cms_unauthorized_screen.dart';
import 'package:nadha_cms/features/cms/presentation/screens/cms_users_screen.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_shell.dart';
import 'package:nadha_cms/features/operations/presentation/cms_admins_screen.dart';
import 'package:nadha_cms/features/operations/presentation/cms_commerce_screen.dart';
import 'package:nadha_cms/features/operations/presentation/cms_entitlements_screen.dart';
import 'package:nadha_cms/features/operations/presentation/cms_learners_screen.dart';
import 'package:nadha_cms/features/operations/presentation/cms_notifications_screen.dart';
import 'package:nadha_cms/features/operations/presentation/cms_operations_screen.dart';
import 'package:nadha_cms/features/operations/presentation/cms_platform_controls_screen.dart';

abstract final class CmsRoutes {
  static const root = '/';
  static const signIn = '/sign-in';
  static const dashboard = '/admin/dashboard';
  static const courses = '/admin/courses';
  static const users = '/admin/users';
  static const learners = '/admin/learners';
  static const commerce = '/admin/commerce';
  static const entitlements = '/admin/entitlements';
  static const notifications = '/admin/notifications';
  static const admins = '/admin/super/admins';
  static const controls = '/admin/super/controls';
  static const integrations = '/admin/super/integrations';
  static const readiness = '/admin/super/readiness';
  static const auditLogs = '/admin/audit-logs';
  static const system = '/admin/system';
  static const unauthorized = '/unauthorized';
}

final cmsRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authControllerProvider);
  final router = GoRouter(
    initialLocation: CmsRoutes.root,
    redirect: (_, state) => cmsRedirect(auth, state.matchedLocation),
    routes: [
      GoRoute(path: CmsRoutes.root, builder: (_, _) => const _LoadingScreen()),
      GoRoute(
        path: CmsRoutes.signIn,
        builder: (_, _) => const CmsLoginScreen(),
      ),
      GoRoute(
        path: CmsRoutes.unauthorized,
        builder: (_, _) => const CmsUnauthorizedScreen(),
      ),
      ShellRoute(
        builder: (_, _, child) => CmsShell(child: child),
        routes: [
          GoRoute(
            path: '/admin/academic',
            builder: (_, _) => const CmsAcademicScreen(),
          ),
          GoRoute(
            path: '/admin/courses/:courseId/lessons/:lessonId/content',
            builder: (_, state) => CmsContentItemsScreen(
              courseId: state.pathParameters['courseId']!,
              lessonId: state.pathParameters['lessonId']!,
            ),
          ),
          GoRoute(
            path: CmsRoutes.dashboard,
            builder: (_, _) => const CmsDashboardScreen(),
          ),
          GoRoute(
            path: CmsRoutes.courses,
            builder: (_, _) => const CmsCoursesScreen(),
          ),
          GoRoute(
            path: '/admin/courses/:id',
            builder: (_, state) => CmsCourseEditorScreen(
              courseId: state.pathParameters['id'] ?? 'new',
            ),
          ),
          GoRoute(
            path: '/admin/assessments/:id',
            builder: (_, state) => CmsAssessmentEditorScreen(
              assessmentId: state.pathParameters['id'] ?? 'new',
              courseId: state.uri.queryParameters['courseId'],
            ),
          ),
          GoRoute(
            path: CmsRoutes.users,
            builder: (_, _) => const CmsUsersScreen(),
          ),
          GoRoute(
            path: CmsRoutes.learners,
            builder: (_, _) => const CmsLearnersScreen(),
          ),
          GoRoute(
            path: '/admin/learners/:id',
            builder: (_, state) => CmsOperationsScreen(
              title: 'Learner Detail',
              subtitle:
                  'Support-safe account, progress, commerce and entitlement evidence.',
              path: '/api/v1/admin/learners/${state.pathParameters['id']}',
            ),
          ),
          GoRoute(
            path: CmsRoutes.commerce,
            builder: (_, _) => const CmsCommerceScreen(),
          ),
          GoRoute(
            path: CmsRoutes.entitlements,
            builder: (_, _) => const CmsEntitlementsScreen(),
          ),
          GoRoute(
            path: CmsRoutes.notifications,
            builder: (_, _) => const CmsNotificationsScreen(),
          ),
          GoRoute(
            path: CmsRoutes.admins,
            builder: (_, _) => const CmsAdminsScreen(),
          ),
          GoRoute(
            path: CmsRoutes.controls,
            builder: (_, _) => const CmsPlatformControlsScreen(),
          ),
          GoRoute(
            path: CmsRoutes.integrations,
            builder: (_, _) => const CmsOperationsScreen(
              title: 'Integration Status',
              dangerous: true,
              subtitle:
                  'Credential-safe provider and infrastructure availability.',
              path: '/api/v1/admin/super/integrations',
            ),
          ),
          GoRoute(
            path: CmsRoutes.readiness,
            builder: (_, _) => const CmsOperationsScreen(
              title: 'System Readiness',
              dangerous: true,
              subtitle: 'Schema, migration and runtime readiness evidence.',
              path: '/api/v1/admin/super/readiness',
            ),
          ),
          GoRoute(
            path: CmsRoutes.auditLogs,
            builder: (_, _) => const CmsAuditLogsScreen(),
          ),
          GoRoute(
            path: CmsRoutes.system,
            builder: (_, _) => const CmsSystemHealthScreen(),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

String? cmsRedirect(AuthState auth, String location) {
  switch (auth.status) {
    case AuthStatus.bootstrapping:
    case AuthStatus.bootstrapFailure:
      return location == CmsRoutes.root ? null : CmsRoutes.root;
    case AuthStatus.unauthenticated:
    case AuthStatus.expired:
      return location == CmsRoutes.signIn ? null : CmsRoutes.signIn;
    case AuthStatus.onboardingRequired:
    case AuthStatus.authenticated:
      if (!(auth.session?.identity.isCmsUser ?? false)) {
        return location == CmsRoutes.unauthorized
            ? null
            : CmsRoutes.unauthorized;
      }
      if (location.startsWith('/admin/super') &&
          !(auth.session?.identity.isSuperAdmin ?? false)) {
        return CmsRoutes.dashboard;
      }
      return location == CmsRoutes.root ||
              location == CmsRoutes.signIn ||
              location == CmsRoutes.unauthorized
          ? CmsRoutes.dashboard
          : null;
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
