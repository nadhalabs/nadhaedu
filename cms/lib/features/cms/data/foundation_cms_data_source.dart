import 'package:nadha_cms/core/errors/app_failure.dart';
import 'package:nadha_cms/core/errors/result.dart';
import 'package:nadha_cms/features/cms/data/cms_remote_data_source.dart';
import 'package:nadha_cms/features/cms/domain/cms_assessment.dart';
import 'package:nadha_cms/features/cms/domain/cms_audit_log.dart';
import 'package:nadha_cms/features/cms/domain/cms_course.dart';
import 'package:nadha_cms/features/cms/domain/cms_course_detail.dart';
import 'package:nadha_cms/features/cms/domain/cms_dashboard_data.dart';
import 'package:nadha_cms/features/cms/domain/cms_role.dart';
import 'package:nadha_cms/features/cms/domain/cms_user.dart';

final class FoundationCmsDataSource implements CmsRemoteDataSource {
  FoundationCmsDataSource() {
    _courses.addAll([
      CmsCourseSummary(
        id: 'course-1',
        title: 'Complete Flutter & Dart Architecture',
        subtitle: 'Enterprise application design and best practices',
        level: 'advanced',
        policyKind: 'premium',
        status: 'published',
        moduleCount: 6,
        lessonCount: 42,
        enrollmentCount: 156,
        durationSeconds: 36000,
        createdAt: DateTime.now().subtract(const Duration(days: 60)),
        publishedAt: DateTime.now().subtract(const Duration(days: 45)),
      ),
      CmsCourseSummary(
        id: 'course-2',
        title: 'Server-Driven UI with Flutter',
        subtitle: 'Dynamic layout engine and caching foundations',
        level: 'intermediate',
        policyKind: 'free',
        status: 'draft',
        moduleCount: 4,
        lessonCount: 24,
        enrollmentCount: 0,
        durationSeconds: 18000,
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      ),
      CmsCourseSummary(
        id: 'course-3',
        title: 'Offline Video & Download Management',
        subtitle: 'Byte-range streaming, checksums, and encrypted tokens',
        level: 'advanced',
        policyKind: 'premium',
        status: 'published',
        moduleCount: 5,
        lessonCount: 30,
        enrollmentCount: 89,
        durationSeconds: 24000,
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        publishedAt: DateTime.now().subtract(const Duration(days: 20)),
      ),
    ]);

    _users.addAll([
      CmsUserSummary(
        id: 'admin-1',
        email: 'admin@nadha.io',
        displayName: 'Dev Ops Admin',
        role: CmsRole.admin,
        isActive: true,
        onboardingComplete: true,
        enrollmentCount: 0,
        createdAt: DateTime.now().subtract(const Duration(days: 120)),
      ),
      CmsUserSummary(
        id: 'cm-1',
        email: 'content@nadha.io',
        displayName: 'Sarah Content Lead',
        role: CmsRole.contentManager,
        isActive: true,
        onboardingComplete: true,
        enrollmentCount: 0,
        createdAt: DateTime.now().subtract(const Duration(days: 90)),
      ),
      CmsUserSummary(
        id: 'sup-1',
        email: 'support@nadha.io',
        displayName: 'Alex Support Specialist',
        role: CmsRole.support,
        isActive: true,
        onboardingComplete: true,
        enrollmentCount: 0,
        createdAt: DateTime.now().subtract(const Duration(days: 80)),
      ),
      CmsUserSummary(
        id: 'user-1',
        email: 'alex.learner@example.com',
        displayName: 'Alex Chen',
        role: CmsRole.learner,
        isActive: true,
        onboardingComplete: true,
        enrollmentCount: 3,
        createdAt: DateTime.now().subtract(const Duration(days: 40)),
      ),
    ]);

    _auditLogs.addAll([
      CmsAuditLogItem(
        id: 'aud-1',
        actorId: 'admin-1',
        actorEmail: 'admin@nadha.io',
        actorName: 'Dev Ops Admin',
        action: 'course.status_updated',
        targetEntity: 'course',
        targetId: 'course-1',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        result: 'success',
        reason: 'Fall semester launch',
        data: {'previousStatus': 'draft', 'newStatus': 'published'},
      ),
      CmsAuditLogItem(
        id: 'aud-2',
        actorId: 'sup-1',
        actorEmail: 'support@nadha.io',
        actorName: 'Alex Support Specialist',
        action: 'certificate.revoked',
        targetEntity: 'certificate',
        targetId: 'cert-99',
        timestamp: DateTime.now().subtract(const Duration(hours: 6)),
        result: 'success',
        reason: 'Assessment retake requested by learner',
        data: {},
      ),
    ]);
  }

  final List<CmsCourseSummary> _courses = [];
  final List<CmsUserSummary> _users = [];
  final List<CmsAuditLogItem> _auditLogs = [];

  @override
  Future<Result<CmsDashboardData>> fetchDashboardData() async {
    final published = _courses.where((c) => c.status == 'published').length;
    final draft = _courses.where((c) => c.status == 'draft').length;
    final totalEnrollments = _courses.fold<int>(
      0,
      (sum, c) => sum + c.enrollmentCount,
    );

    final data = CmsDashboardData(
      metrics: CmsDashboardMetrics(
        totalUsers: _users.length,
        totalLearners: _users.where((u) => u.role == CmsRole.learner).length,
        activeLearners: 1,
        totalCourses: _courses.length,
        publishedCourses: published,
        draftCourses: draft,
        archivedCourses: 0,
        totalEnrollments: totalEnrollments,
        totalPurchases: 45,
        activeSubscriptions: 28,
        totalCertificatesIssued: 14,
        recentCompletions: 8,
      ),
      recentPurchases: [
        CmsRecentPurchase(
          id: 'pur-1',
          orderId: 'ORD-9081',
          learnerId: 'user-1',
          learnerEmail: 'alex.learner@example.com',
          productId: 'course-1',
          productType: 'course',
          amountCents: 4900,
          currencyCode: 'USD',
          status: 'completed',
          purchasedAt: DateTime.now().subtract(const Duration(minutes: 45)),
        ),
      ],
      recentActivity: _auditLogs
          .map(
            (a) => CmsRecentActivity(
              id: a.id,
              actorId: a.actorId,
              actorEmail: a.actorEmail,
              actorName: a.actorName,
              action: a.action,
              targetEntity: a.targetEntity,
              targetId: a.targetId,
              timestamp: a.timestamp,
              result: a.result,
              reason: a.reason,
              metadata: a.data,
            ),
          )
          .toList(),
      systemReadiness: const CmsSystemReadiness(
        database: 'connected',
        cache: 'connected',
        migrationRevision: '0006_r3_query_indexes',
        isReady: true,
        warnings: [
          CmsSystemReadinessWarning(
            code: 'PROVIDER_MOCK_MODE',
            message:
                'Apple, Google and Stripe live billing are running in fail-closed / mock verification mode.',
          ),
        ],
      ),
    );
    return Success(data);
  }

  @override
  Future<Result<List<CmsCourseSummary>>> fetchCourses({
    String? status,
    String? search,
    int page = 1,
    int pageSize = 20,
  }) async {
    var list = _courses.toList();
    if (status != null && status.isNotEmpty) {
      list = list.where((c) => c.status == status).toList();
    }
    if (search != null && search.isNotEmpty) {
      list = list
          .where(
            (c) =>
                c.title.toLowerCase().contains(search.toLowerCase()) ||
                c.subtitle.toLowerCase().contains(search.toLowerCase()),
          )
          .toList();
    }
    return Success(list);
  }

  @override
  Future<Result<CmsCourseSummary>> updateCourseStatus({
    required String courseId,
    required String status,
    String? reason,
  }) async {
    final idx = _courses.indexWhere((c) => c.id == courseId);
    if (idx < 0) {
      return const Failure(
        NotFoundFailure(code: 'NOT_FOUND', message: 'Course not found.'),
      );
    }
    final existing = _courses[idx];
    final updated = CmsCourseSummary(
      id: existing.id,
      title: existing.title,
      subtitle: existing.subtitle,
      level: existing.level,
      policyKind: existing.policyKind,
      status: status,
      moduleCount: existing.moduleCount,
      lessonCount: existing.lessonCount,
      enrollmentCount: existing.enrollmentCount,
      durationSeconds: existing.durationSeconds,
      createdAt: existing.createdAt,
      publishedAt: status == 'published'
          ? (existing.publishedAt ?? DateTime.now())
          : existing.publishedAt,
    );
    _courses[idx] = updated;

    _auditLogs.insert(
      0,
      CmsAuditLogItem(
        id: 'aud-${DateTime.now().millisecondsSinceEpoch}',
        actorId: 'admin-1',
        actorEmail: 'admin@nadha.io',
        actorName: 'Dev Ops Admin',
        action: 'course.status_updated',
        targetEntity: 'course',
        targetId: courseId,
        timestamp: DateTime.now(),
        result: 'success',
        reason: reason,
        data: {'previousStatus': existing.status, 'newStatus': status},
      ),
    );

    return Success(updated);
  }

  @override
  Future<Result<List<CmsUserSummary>>> fetchUsers({
    String? role,
    String? search,
    int page = 1,
    int pageSize = 20,
  }) async {
    var list = _users.toList();
    if (role != null && role.isNotEmpty) {
      list = list.where((u) => u.role.value == role).toList();
    }
    if (search != null && search.isNotEmpty) {
      list = list
          .where(
            (u) =>
                u.email.toLowerCase().contains(search.toLowerCase()) ||
                u.displayName.toLowerCase().contains(search.toLowerCase()),
          )
          .toList();
    }
    return Success(list);
  }

  @override
  Future<Result<List<CmsAuditLogItem>>> fetchAuditLogs({
    String? eventType,
    String? subjectType,
    String? actorId,
    int page = 1,
    int pageSize = 20,
  }) async {
    var list = _auditLogs.toList();
    if (eventType != null && eventType.isNotEmpty) {
      list = list
          .where(
            (a) => a.action.toLowerCase().contains(eventType.toLowerCase()),
          )
          .toList();
    }
    if (subjectType != null && subjectType.isNotEmpty) {
      list = list.where((a) => a.targetEntity == subjectType).toList();
    }
    if (actorId != null && actorId.isNotEmpty) {
      list = list.where((a) => a.actorId == actorId).toList();
    }
    return Success(list);
  }

  // --- Phase 2 Mock Implementations ---

  final List<CmsCategory> _categories = [
    const CmsCategory(
      id: 'cat-1',
      name: 'Mobile Development',
      iconName: 'phone_android',
    ),
    const CmsCategory(
      id: 'cat-2',
      name: 'Cloud Architecture',
      iconName: 'cloud',
    ),
    const CmsCategory(id: 'cat-3', name: 'DevOps & CI/CD', iconName: 'build'),
  ];

  final Map<String, CmsCourseDetail> _courseDetails = {};
  final Map<String, CmsAssessmentDetail> _assessmentDetails = {};

  CmsCourseDetail _getOrCreateCourse(String courseId) {
    final existing = _courseDetails[courseId];
    if (existing != null) return existing;

    final detail = CmsCourseDetail(
      id: courseId,
      title: 'Complete Flutter & Dart Architecture',
      subtitle: 'Enterprise application design and best practices',
      description:
          'Master clean architecture, Riverpod 3.0, and offline-first data sync.',
      level: 'advanced',
      languageCode: 'en',
      policyKind: 'premium',
      protectionPolicy: 'blockCaptureWhereSupported',
      status: 'published',
      publishedAt: DateTime.now().subtract(const Duration(days: 45)),
      rating: 4.9,
      ratingCount: 128,
      durationSeconds: 36000,
      learningOutcomes: const [
        'Design scalable apps',
        'Master state management',
      ],
      prerequisites: const ['Basic Dart knowledge'],
      categories: _categories.take(1).toList(),
      tags: const ['flutter', 'dart', 'architecture'],
      modules: [
        CmsModuleDetail(
          id: 'mod-1',
          courseId: courseId,
          title: 'Foundations of Clean Architecture',
          position: 1,
          policyKind: 'inherit',
          lessons: [
            CmsLessonDetail(
              id: 'les-1',
              moduleId: 'mod-1',
              title: 'Domain, Data, Presentation Layers',
              position: 1,
              durationSeconds: 600,
              contentType: 'video',
              contentRef: 'arch-vid-1',
              isPreview: true,
              isDownloadable: true,
              policyKind: 'inherit',
              protectionPolicy: 'blockCaptureWhereSupported',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          ],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ],
      assessments: [
        CmsAssessmentSummary(
          id: 'quiz-1',
          courseId: courseId,
          title: 'Architecture Readiness Assessment',
          description: 'Evaluate mastery of layer separation',
          passingPercentage: 80,
          timeLimitSeconds: 1800,
          maxAttempts: 3,
          requiredForCertificate: true,
          protectionPolicy: 'blockCaptureWhereSupported',
          status: 'published',
          questionCount: 1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ],
      validation: const CmsCourseValidation(
        isValid: true,
        canPublish: true,
        errors: [],
        warnings: [],
      ),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _courseDetails[courseId] = detail;
    return detail;
  }

  CmsAssessmentDetail _getOrCreateAssessment(String assessmentId) {
    final existing = _assessmentDetails[assessmentId];
    if (existing != null) return existing;

    final ass = CmsAssessmentDetail(
      id: assessmentId,
      courseId: 'course-1',
      title: 'Architecture Readiness Assessment',
      description: 'Evaluate mastery of layer separation',
      instructions: const ['Read questions carefully'],
      passingPercentage: 80,
      timeLimitSeconds: 1800,
      maxAttempts: 3,
      requiredForCertificate: true,
      protectionPolicy: 'blockCaptureWhereSupported',
      status: 'published',
      questions: [
        CmsQuestionDetail(
          id: 'q-1',
          assessmentId: assessmentId,
          type: 'singleChoice',
          prompt: 'What layer does an API client belong to?',
          points: 2,
          position: 1,
          explanation: 'API client lives in the Data layer.',
          settings: const {},
          options: const [
            CmsQuestionOption(id: 'opt-1', text: 'Data Layer', position: 1),
            CmsQuestionOption(id: 'opt-2', text: 'Domain Layer', position: 2),
            CmsQuestionOption(
              id: 'opt-3',
              text: 'Presentation Layer',
              position: 3,
            ),
          ],
          gradingData: const {'correctOptionId': 'opt-1'},
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _assessmentDetails[assessmentId] = ass;
    return ass;
  }

  @override
  Future<Result<List<CmsCategory>>> fetchCategories() async =>
      Success(List.unmodifiable(_categories));

  @override
  Future<Result<CmsCategory>> createCategory({
    required String name,
    String iconName = 'school',
  }) async {
    final cat = CmsCategory(
      id: 'cat-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      iconName: iconName,
    );
    _categories.add(cat);
    return Success(cat);
  }

  @override
  Future<Result<CmsCourseDetail>> createCourse(
    Map<String, Object?> payload,
  ) async {
    final courseId = 'course-${DateTime.now().millisecondsSinceEpoch}';
    final detail = CmsCourseDetail(
      id: courseId,
      title: payload['title'] as String? ?? 'New Untitled Course',
      subtitle: payload['subtitle'] as String? ?? '',
      description: payload['description'] as String? ?? '',
      level: payload['level'] as String? ?? 'allLevels',
      languageCode: payload['languageCode'] as String? ?? 'en',
      policyKind: payload['policyKind'] as String? ?? 'free',
      protectionPolicy:
          payload['protectionPolicy'] as String? ??
          'blockCaptureWhereSupported',
      status: 'draft',
      publishedAt: null,
      rating: 0,
      ratingCount: 0,
      durationSeconds: 0,
      learningOutcomes:
          (payload['learningOutcomes'] as List<dynamic>?)?.cast<String>() ??
          const [],
      prerequisites:
          (payload['prerequisites'] as List<dynamic>?)?.cast<String>() ??
          const [],
      categories: const [],
      tags: (payload['tags'] as List<dynamic>?)?.cast<String>() ?? const [],
      modules: const [],
      assessments: const [],
      validation: const CmsCourseValidation(
        isValid: false,
        canPublish: false,
        errors: [
          CmsValidationItem(
            code: 'NO_SECTIONS',
            message: 'Course must contain at least one module.',
            severity: 'error',
          ),
        ],
        warnings: [],
      ),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _courseDetails[courseId] = detail;
    return Success(detail);
  }

  @override
  Future<Result<CmsCourseDetail>> fetchCourseDetail(String courseId) async {
    return Success(_getOrCreateCourse(courseId));
  }

  @override
  Future<Result<CmsCourseDetail>> updateCourse(
    String courseId,
    Map<String, Object?> payload,
  ) async {
    final detail = _getOrCreateCourse(courseId);
    final updated = CmsCourseDetail(
      id: detail.id,
      title: payload['title'] as String? ?? detail.title,
      subtitle: payload['subtitle'] as String? ?? detail.subtitle,
      description: payload['description'] as String? ?? detail.description,
      level: payload['level'] as String? ?? detail.level,
      languageCode: payload['languageCode'] as String? ?? detail.languageCode,
      policyKind: payload['policyKind'] as String? ?? detail.policyKind,
      protectionPolicy:
          payload['protectionPolicy'] as String? ?? detail.protectionPolicy,
      status: detail.status,
      publishedAt: detail.publishedAt,
      rating: detail.rating,
      ratingCount: detail.ratingCount,
      durationSeconds: detail.durationSeconds,
      learningOutcomes:
          (payload['learningOutcomes'] as List<dynamic>?)?.cast<String>() ??
          detail.learningOutcomes,
      prerequisites:
          (payload['prerequisites'] as List<dynamic>?)?.cast<String>() ??
          detail.prerequisites,
      categories: detail.categories,
      tags: (payload['tags'] as List<dynamic>?)?.cast<String>() ?? detail.tags,
      modules: detail.modules,
      assessments: detail.assessments,
      validation: detail.validation,
      createdAt: detail.createdAt,
      updatedAt: DateTime.now(),
    );
    _courseDetails[courseId] = updated;
    return Success(updated);
  }

  @override
  Future<Result<void>> deleteCourse(String courseId, {String? reason}) async {
    _courseDetails.remove(courseId);
    return const Success(null);
  }

  @override
  Future<Result<CmsCourseValidation>> validateCourse(String courseId) async {
    final detail = _getOrCreateCourse(courseId);
    return Success(detail.validation);
  }

  @override
  Future<Result<CmsCourseDetail>> publishCourse(
    String courseId, {
    String? reason,
  }) async {
    final existing = _getOrCreateCourse(courseId);
    final updated = CmsCourseDetail(
      id: existing.id,
      title: existing.title,
      subtitle: existing.subtitle,
      description: existing.description,
      level: existing.level,
      languageCode: existing.languageCode,
      policyKind: existing.policyKind,
      protectionPolicy: existing.protectionPolicy,
      status: 'published',
      publishedAt: DateTime.now(),
      rating: existing.rating,
      ratingCount: existing.ratingCount,
      durationSeconds: existing.durationSeconds,
      learningOutcomes: existing.learningOutcomes,
      prerequisites: existing.prerequisites,
      categories: existing.categories,
      tags: existing.tags,
      modules: existing.modules,
      assessments: existing.assessments,
      validation: existing.validation,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now(),
    );
    _courseDetails[courseId] = updated;
    return Success(updated);
  }

  @override
  Future<Result<CmsCourseDetail>> unpublishCourse(
    String courseId, {
    String? reason,
  }) async {
    final existing = _getOrCreateCourse(courseId);
    final updated = CmsCourseDetail(
      id: existing.id,
      title: existing.title,
      subtitle: existing.subtitle,
      description: existing.description,
      level: existing.level,
      languageCode: existing.languageCode,
      policyKind: existing.policyKind,
      protectionPolicy: existing.protectionPolicy,
      status: 'draft',
      publishedAt: existing.publishedAt,
      rating: existing.rating,
      ratingCount: existing.ratingCount,
      durationSeconds: existing.durationSeconds,
      learningOutcomes: existing.learningOutcomes,
      prerequisites: existing.prerequisites,
      categories: existing.categories,
      tags: existing.tags,
      modules: existing.modules,
      assessments: existing.assessments,
      validation: existing.validation,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now(),
    );
    _courseDetails[courseId] = updated;
    return Success(updated);
  }

  @override
  Future<Result<CmsModuleDetail>> createModule(
    String courseId, {
    required String title,
    String policyKind = 'inherit',
  }) async {
    final current = _getOrCreateCourse(courseId);
    final mod = CmsModuleDetail(
      id: 'mod-${DateTime.now().millisecondsSinceEpoch}',
      courseId: courseId,
      title: title,
      position: current.modules.length + 1,
      policyKind: policyKind,
      lessons: const [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final updatedModules = <CmsModuleDetail>[...current.modules, mod];
    _courseDetails[courseId] = CmsCourseDetail(
      id: current.id,
      title: current.title,
      subtitle: current.subtitle,
      description: current.description,
      level: current.level,
      languageCode: current.languageCode,
      policyKind: current.policyKind,
      protectionPolicy: current.protectionPolicy,
      status: current.status,
      publishedAt: current.publishedAt,
      rating: current.rating,
      ratingCount: current.ratingCount,
      durationSeconds: current.durationSeconds,
      learningOutcomes: current.learningOutcomes,
      prerequisites: current.prerequisites,
      categories: current.categories,
      tags: current.tags,
      modules: updatedModules,
      assessments: current.assessments,
      validation: current.validation,
      createdAt: current.createdAt,
      updatedAt: DateTime.now(),
    );
    return Success(mod);
  }

  @override
  Future<Result<CmsModuleDetail>> updateModule(
    String courseId,
    String moduleId, {
    String? title,
    String? policyKind,
  }) async {
    final current = _getOrCreateCourse(courseId);
    final updatedModules = current.modules.map((m) {
      if (m.id == moduleId) {
        return CmsModuleDetail(
          id: m.id,
          courseId: m.courseId,
          title: title ?? m.title,
          position: m.position,
          policyKind: policyKind ?? m.policyKind,
          lessons: m.lessons,
          createdAt: m.createdAt,
          updatedAt: DateTime.now(),
        );
      }
      return m;
    }).toList();

    _courseDetails[courseId] = CmsCourseDetail(
      id: current.id,
      title: current.title,
      subtitle: current.subtitle,
      description: current.description,
      level: current.level,
      languageCode: current.languageCode,
      policyKind: current.policyKind,
      protectionPolicy: current.protectionPolicy,
      status: current.status,
      publishedAt: current.publishedAt,
      rating: current.rating,
      ratingCount: current.ratingCount,
      durationSeconds: current.durationSeconds,
      learningOutcomes: current.learningOutcomes,
      prerequisites: current.prerequisites,
      categories: current.categories,
      tags: current.tags,
      modules: updatedModules,
      assessments: current.assessments,
      validation: current.validation,
      createdAt: current.createdAt,
      updatedAt: DateTime.now(),
    );

    final updatedModule = updatedModules.firstWhere((m) => m.id == moduleId);
    return Success(updatedModule);
  }

  @override
  Future<Result<void>> deleteModule(String courseId, String moduleId) async {
    final current = _getOrCreateCourse(courseId);
    final updatedModules = current.modules
        .where((m) => m.id != moduleId)
        .toList();
    _courseDetails[courseId] = CmsCourseDetail(
      id: current.id,
      title: current.title,
      subtitle: current.subtitle,
      description: current.description,
      level: current.level,
      languageCode: current.languageCode,
      policyKind: current.policyKind,
      protectionPolicy: current.protectionPolicy,
      status: current.status,
      publishedAt: current.publishedAt,
      rating: current.rating,
      ratingCount: current.ratingCount,
      durationSeconds: current.durationSeconds,
      learningOutcomes: current.learningOutcomes,
      prerequisites: current.prerequisites,
      categories: current.categories,
      tags: current.tags,
      modules: updatedModules,
      assessments: current.assessments,
      validation: current.validation,
      createdAt: current.createdAt,
      updatedAt: DateTime.now(),
    );
    return const Success(null);
  }

  @override
  Future<Result<List<CmsModuleDetail>>> reorderModules(
    String courseId,
    List<String> moduleIds,
  ) async {
    final current = _getOrCreateCourse(courseId);
    final moduleMap = {for (final m in current.modules) m.id: m};
    final reordered = <CmsModuleDetail>[];
    for (var i = 0; i < moduleIds.length; i++) {
      final m = moduleMap[moduleIds[i]];
      if (m != null) {
        reordered.add(
          CmsModuleDetail(
            id: m.id,
            courseId: m.courseId,
            title: m.title,
            position: i + 1,
            policyKind: m.policyKind,
            lessons: m.lessons,
            createdAt: m.createdAt,
            updatedAt: DateTime.now(),
          ),
        );
      }
    }
    _courseDetails[courseId] = CmsCourseDetail(
      id: current.id,
      title: current.title,
      subtitle: current.subtitle,
      description: current.description,
      level: current.level,
      languageCode: current.languageCode,
      policyKind: current.policyKind,
      protectionPolicy: current.protectionPolicy,
      status: current.status,
      publishedAt: current.publishedAt,
      rating: current.rating,
      ratingCount: current.ratingCount,
      durationSeconds: current.durationSeconds,
      learningOutcomes: current.learningOutcomes,
      prerequisites: current.prerequisites,
      categories: current.categories,
      tags: current.tags,
      modules: reordered,
      assessments: current.assessments,
      validation: current.validation,
      createdAt: current.createdAt,
      updatedAt: DateTime.now(),
    );
    return Success(reordered);
  }

  @override
  Future<Result<CmsLessonDetail>> createLesson(
    String courseId,
    String moduleId,
    Map<String, Object?> payload,
  ) async {
    final dur = (payload['durationSeconds'] as num?)?.toInt() ?? 300;
    final les = CmsLessonDetail(
      id: 'les-${DateTime.now().millisecondsSinceEpoch}',
      moduleId: moduleId,
      title: payload['title'] as String? ?? 'New Lesson',
      position: 1,
      durationSeconds: dur,
      contentType: payload['contentType'] as String? ?? 'video',
      contentRef: payload['contentRef'] as String? ?? 'ref-1',
      isPreview: payload['isPreview'] as bool? ?? false,
      isDownloadable: payload['isDownloadable'] as bool? ?? true,
      policyKind: payload['policyKind'] as String? ?? 'inherit',
      protectionPolicy:
          payload['protectionPolicy'] as String? ??
          'blockCaptureWhereSupported',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final current = _getOrCreateCourse(courseId);
    final updatedModules = current.modules.map((m) {
      if (m.id == moduleId) {
        return CmsModuleDetail(
          id: m.id,
          courseId: m.courseId,
          title: m.title,
          position: m.position,
          policyKind: m.policyKind,
          lessons: [...m.lessons, les],
          createdAt: m.createdAt,
          updatedAt: DateTime.now(),
        );
      }
      return m;
    }).toList();

    _courseDetails[courseId] = CmsCourseDetail(
      id: current.id,
      title: current.title,
      subtitle: current.subtitle,
      description: current.description,
      level: current.level,
      languageCode: current.languageCode,
      policyKind: current.policyKind,
      protectionPolicy: current.protectionPolicy,
      status: current.status,
      publishedAt: current.publishedAt,
      rating: current.rating,
      ratingCount: current.ratingCount,
      durationSeconds: current.durationSeconds + dur,
      learningOutcomes: current.learningOutcomes,
      prerequisites: current.prerequisites,
      categories: current.categories,
      tags: current.tags,
      modules: updatedModules,
      assessments: current.assessments,
      validation: current.validation,
      createdAt: current.createdAt,
      updatedAt: DateTime.now(),
    );

    return Success(les);
  }

  @override
  Future<Result<CmsLessonDetail>> updateLesson(
    String courseId,
    String moduleId,
    String lessonId,
    Map<String, Object?> payload,
  ) async {
    final current = _getOrCreateCourse(courseId);
    CmsLessonDetail? updatedLesson;
    final updatedModules = current.modules.map((m) {
      if (m.id == moduleId) {
        final updatedLessons = m.lessons.map((l) {
          if (l.id == lessonId) {
            updatedLesson = CmsLessonDetail(
              id: l.id,
              moduleId: l.moduleId,
              title: payload['title'] as String? ?? l.title,
              position: l.position,
              durationSeconds:
                  (payload['durationSeconds'] as num?)?.toInt() ??
                  l.durationSeconds,
              contentType: payload['contentType'] as String? ?? l.contentType,
              contentRef: payload['contentRef'] as String? ?? l.contentRef,
              isPreview: payload['isPreview'] as bool? ?? l.isPreview,
              isDownloadable:
                  payload['isDownloadable'] as bool? ?? l.isDownloadable,
              policyKind: payload['policyKind'] as String? ?? l.policyKind,
              protectionPolicy:
                  payload['protectionPolicy'] as String? ?? l.protectionPolicy,
              createdAt: l.createdAt,
              updatedAt: DateTime.now(),
            );
            return updatedLesson!;
          }
          return l;
        }).toList();
        return CmsModuleDetail(
          id: m.id,
          courseId: m.courseId,
          title: m.title,
          position: m.position,
          policyKind: m.policyKind,
          lessons: updatedLessons,
          createdAt: m.createdAt,
          updatedAt: DateTime.now(),
        );
      }
      return m;
    }).toList();

    _courseDetails[courseId] = CmsCourseDetail(
      id: current.id,
      title: current.title,
      subtitle: current.subtitle,
      description: current.description,
      level: current.level,
      languageCode: current.languageCode,
      policyKind: current.policyKind,
      protectionPolicy: current.protectionPolicy,
      status: current.status,
      publishedAt: current.publishedAt,
      rating: current.rating,
      ratingCount: current.ratingCount,
      durationSeconds: current.durationSeconds,
      learningOutcomes: current.learningOutcomes,
      prerequisites: current.prerequisites,
      categories: current.categories,
      tags: current.tags,
      modules: updatedModules,
      assessments: current.assessments,
      validation: current.validation,
      createdAt: current.createdAt,
      updatedAt: DateTime.now(),
    );

    return Success(updatedLesson!);
  }

  @override
  Future<Result<void>> deleteLesson(
    String courseId,
    String moduleId,
    String lessonId,
  ) async {
    final current = _getOrCreateCourse(courseId);
    final updatedModules = current.modules.map((m) {
      if (m.id == moduleId) {
        return CmsModuleDetail(
          id: m.id,
          courseId: m.courseId,
          title: m.title,
          position: m.position,
          policyKind: m.policyKind,
          lessons: m.lessons.where((l) => l.id != lessonId).toList(),
          createdAt: m.createdAt,
          updatedAt: DateTime.now(),
        );
      }
      return m;
    }).toList();

    _courseDetails[courseId] = CmsCourseDetail(
      id: current.id,
      title: current.title,
      subtitle: current.subtitle,
      description: current.description,
      level: current.level,
      languageCode: current.languageCode,
      policyKind: current.policyKind,
      protectionPolicy: current.protectionPolicy,
      status: current.status,
      publishedAt: current.publishedAt,
      rating: current.rating,
      ratingCount: current.ratingCount,
      durationSeconds: current.durationSeconds,
      learningOutcomes: current.learningOutcomes,
      prerequisites: current.prerequisites,
      categories: current.categories,
      tags: current.tags,
      modules: updatedModules,
      assessments: current.assessments,
      validation: current.validation,
      createdAt: current.createdAt,
      updatedAt: DateTime.now(),
    );
    return const Success(null);
  }

  @override
  Future<Result<List<CmsLessonDetail>>> reorderLessons(
    String courseId,
    String moduleId,
    List<String> lessonIds,
  ) async {
    final current = _getOrCreateCourse(courseId);
    final module = current.modules.firstWhere((m) => m.id == moduleId);
    final lessonMap = {for (final l in module.lessons) l.id: l};
    final reordered = <CmsLessonDetail>[];
    for (var i = 0; i < lessonIds.length; i++) {
      final l = lessonMap[lessonIds[i]];
      if (l != null) {
        reordered.add(
          CmsLessonDetail(
            id: l.id,
            moduleId: l.moduleId,
            title: l.title,
            position: i + 1,
            durationSeconds: l.durationSeconds,
            contentType: l.contentType,
            contentRef: l.contentRef,
            isPreview: l.isPreview,
            isDownloadable: l.isDownloadable,
            policyKind: l.policyKind,
            protectionPolicy: l.protectionPolicy,
            createdAt: l.createdAt,
            updatedAt: DateTime.now(),
          ),
        );
      }
    }
    return Success(reordered);
  }

  @override
  Future<Result<List<CmsAssessmentSummary>>> fetchCourseAssessments(
    String courseId,
  ) async {
    final course = _getOrCreateCourse(courseId);
    return Success(course.assessments);
  }

  @override
  Future<Result<CmsAssessmentDetail>> createAssessment(
    String courseId,
    Map<String, Object?> payload,
  ) async {
    final ass = CmsAssessmentDetail(
      id: 'ass-${DateTime.now().millisecondsSinceEpoch}',
      courseId: courseId,
      title: payload['title'] as String? ?? 'New Quiz',
      description: payload['description'] as String? ?? '',
      instructions:
          (payload['instructions'] as List<dynamic>?)?.cast<String>() ??
          const [],
      passingPercentage: (payload['passingPercentage'] as num?)?.toInt() ?? 70,
      maxAttempts: (payload['maxAttempts'] as num?)?.toInt() ?? 3,
      requiredForCertificate:
          payload['requiredForCertificate'] as bool? ?? true,
      protectionPolicy: 'blockCaptureWhereSupported',
      status: 'draft',
      questions: const [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _assessmentDetails[ass.id] = ass;
    return Success(ass);
  }

  @override
  Future<Result<CmsAssessmentDetail>> fetchAssessmentDetail(
    String assessmentId,
  ) async {
    return Success(_getOrCreateAssessment(assessmentId));
  }

  @override
  Future<Result<CmsAssessmentDetail>> updateAssessment(
    String assessmentId,
    Map<String, Object?> payload,
  ) async {
    final detail = _getOrCreateAssessment(assessmentId);
    final updated = CmsAssessmentDetail(
      id: detail.id,
      courseId: detail.courseId,
      title: payload['title'] as String? ?? detail.title,
      description: payload['description'] as String? ?? detail.description,
      instructions:
          (payload['instructions'] as List<dynamic>?)?.cast<String>() ??
          detail.instructions,
      passingPercentage:
          (payload['passingPercentage'] as num?)?.toInt() ??
          detail.passingPercentage,
      timeLimitSeconds:
          (payload['timeLimitSeconds'] as num?)?.toInt() ??
          detail.timeLimitSeconds,
      maxAttempts:
          (payload['maxAttempts'] as num?)?.toInt() ?? detail.maxAttempts,
      requiredForCertificate:
          payload['requiredForCertificate'] as bool? ??
          detail.requiredForCertificate,
      protectionPolicy:
          payload['protectionPolicy'] as String? ?? detail.protectionPolicy,
      status: payload['status'] as String? ?? detail.status,
      questions: detail.questions,
      createdAt: detail.createdAt,
      updatedAt: DateTime.now(),
    );
    _assessmentDetails[assessmentId] = updated;
    return Success(updated);
  }

  @override
  Future<Result<void>> deleteAssessment(String assessmentId) async {
    _assessmentDetails.remove(assessmentId);
    return const Success(null);
  }

  @override
  Future<Result<CmsQuestionDetail>> createQuestion(
    String assessmentId,
    Map<String, Object?> payload,
  ) async {
    final optionsRaw = payload['options'] as List<dynamic>? ?? const [];
    final options = optionsRaw.map((o) {
      if (o is CmsQuestionOption) return o;
      final m = (o as Map).cast<String, Object?>();
      return CmsQuestionOption(
        id: m['id'] as String? ?? '',
        text: m['text'] as String? ?? '',
        position: (m['position'] as num?)?.toInt() ?? 1,
      );
    }).toList();

    final q = CmsQuestionDetail(
      id: 'q-${DateTime.now().millisecondsSinceEpoch}',
      assessmentId: assessmentId,
      type: payload['type'] as String? ?? 'singleChoice',
      prompt: payload['prompt'] as String? ?? '',
      points: (payload['points'] as num?)?.toInt() ?? 1,
      position: 1,
      explanation: payload['explanation'] as String?,
      settings:
          (payload['settings'] as Map?)?.cast<String, Object?>() ?? const {},
      options: options,
      gradingData:
          (payload['gradingData'] as Map?)?.cast<String, Object?>() ?? const {},
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final ass = _getOrCreateAssessment(assessmentId);
    final updated = CmsAssessmentDetail(
      id: ass.id,
      courseId: ass.courseId,
      title: ass.title,
      description: ass.description,
      instructions: ass.instructions,
      passingPercentage: ass.passingPercentage,
      timeLimitSeconds: ass.timeLimitSeconds,
      maxAttempts: ass.maxAttempts,
      requiredForCertificate: ass.requiredForCertificate,
      protectionPolicy: ass.protectionPolicy,
      status: ass.status,
      questions: [...ass.questions, q],
      createdAt: ass.createdAt,
      updatedAt: DateTime.now(),
    );
    _assessmentDetails[assessmentId] = updated;

    return Success(q);
  }

  @override
  Future<Result<CmsQuestionDetail>> updateQuestion(
    String assessmentId,
    String questionId,
    Map<String, Object?> payload,
  ) async {
    final optionsRaw = payload['options'] as List<dynamic>? ?? const [];
    final options = optionsRaw.map((o) {
      if (o is CmsQuestionOption) return o;
      final m = (o as Map).cast<String, Object?>();
      return CmsQuestionOption(
        id: m['id'] as String? ?? '',
        text: m['text'] as String? ?? '',
        position: (m['position'] as num?)?.toInt() ?? 1,
      );
    }).toList();

    final q = CmsQuestionDetail(
      id: questionId,
      assessmentId: assessmentId,
      type: payload['type'] as String? ?? 'singleChoice',
      prompt: payload['prompt'] as String? ?? '',
      points: (payload['points'] as num?)?.toInt() ?? 1,
      position: 1,
      explanation: payload['explanation'] as String?,
      settings:
          (payload['settings'] as Map?)?.cast<String, Object?>() ?? const {},
      options: options,
      gradingData:
          (payload['gradingData'] as Map?)?.cast<String, Object?>() ?? const {},
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    return Success(q);
  }

  @override
  Future<Result<void>> deleteQuestion(
    String assessmentId,
    String questionId,
  ) async {
    final ass = _getOrCreateAssessment(assessmentId);
    final updated = CmsAssessmentDetail(
      id: ass.id,
      courseId: ass.courseId,
      title: ass.title,
      description: ass.description,
      instructions: ass.instructions,
      passingPercentage: ass.passingPercentage,
      timeLimitSeconds: ass.timeLimitSeconds,
      maxAttempts: ass.maxAttempts,
      requiredForCertificate: ass.requiredForCertificate,
      protectionPolicy: ass.protectionPolicy,
      status: ass.status,
      questions: ass.questions.where((q) => q.id != questionId).toList(),
      createdAt: ass.createdAt,
      updatedAt: DateTime.now(),
    );
    _assessmentDetails[assessmentId] = updated;
    return const Success(null);
  }

  @override
  Future<Result<List<CmsQuestionDetail>>> reorderQuestions(
    String assessmentId,
    List<String> questionIds,
  ) async {
    return const Success([]);
  }
}
