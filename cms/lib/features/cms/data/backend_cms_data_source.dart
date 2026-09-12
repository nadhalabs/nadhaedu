import 'package:nadha_cms/core/errors/result.dart';
import 'package:nadha_cms/core/networking/api_client.dart';
import 'package:nadha_cms/features/cms/data/cms_remote_data_source.dart';
import 'package:nadha_cms/features/cms/domain/cms_assessment.dart';
import 'package:nadha_cms/features/cms/domain/cms_audit_log.dart';
import 'package:nadha_cms/features/cms/domain/cms_course.dart';
import 'package:nadha_cms/features/cms/domain/cms_course_detail.dart';
import 'package:nadha_cms/features/cms/domain/cms_dashboard_data.dart';
import 'package:nadha_cms/features/cms/domain/cms_user.dart';

final class BackendCmsDataSource implements CmsRemoteDataSource {
  const BackendCmsDataSource({required ApiClient client}) : _client = client;

  final ApiClient _client;

  @override
  Future<Result<CmsDashboardData>> fetchDashboardData() async {
    final result = await _client.get('/api/v1/admin/dashboard');
    return switch (result) {
      Success(value: final data) => Success(CmsDashboardData.fromJson(data)),
      Failure(failure: final failure) => Failure(failure),
    };
  }

  @override
  Future<Result<List<CmsCourseSummary>>> fetchCourses({
    String? status,
    String? search,
    int page = 1,
    int pageSize = 20,
  }) async {
    final query = <String, Object?>{
      if (status != null && status.isNotEmpty) 'status': status,
      if (search != null && search.isNotEmpty) 'search': search,
      'page': page,
      'pageSize': pageSize,
    };
    final result = await _client.get('/api/v1/admin/courses', query: query);
    return switch (result) {
      Success(value: final data) => () {
        final items =
            (data['items'] as List<dynamic>?)
                ?.map(
                  (c) => CmsCourseSummary.fromJson(
                    Map<String, Object?>.from(c as Map),
                  ),
                )
                .toList() ??
            const <CmsCourseSummary>[];
        return Success(items);
      }(),
      Failure(failure: final failure) => Failure(failure),
    };
  }

  @override
  Future<Result<CmsCourseSummary>> updateCourseStatus({
    required String courseId,
    required String status,
    String? reason,
  }) async {
    final body = <String, Object?>{
      'status': status,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    };
    final result = await _client.post(
      '/api/v1/admin/courses/$courseId/status',
      body: body,
    );
    return switch (result) {
      Success(value: final data) => Success(CmsCourseSummary.fromJson(data)),
      Failure(failure: final failure) => Failure(failure),
    };
  }

  @override
  Future<Result<List<CmsUserSummary>>> fetchUsers({
    String? role,
    String? search,
    int page = 1,
    int pageSize = 20,
  }) async {
    final query = <String, Object?>{
      if (role != null && role.isNotEmpty) 'role': role,
      if (search != null && search.isNotEmpty) 'search': search,
      'page': page,
      'pageSize': pageSize,
    };
    final result = await _client.get('/api/v1/admin/users', query: query);
    return switch (result) {
      Success(value: final data) => () {
        final items =
            (data['items'] as List<dynamic>?)
                ?.map(
                  (u) => CmsUserSummary.fromJson(
                    Map<String, Object?>.from(u as Map),
                  ),
                )
                .toList() ??
            const <CmsUserSummary>[];
        return Success(items);
      }(),
      Failure(failure: final failure) => Failure(failure),
    };
  }

  @override
  Future<Result<List<CmsAuditLogItem>>> fetchAuditLogs({
    String? eventType,
    String? subjectType,
    String? actorId,
    int page = 1,
    int pageSize = 20,
  }) async {
    final query = <String, Object?>{
      if (eventType != null && eventType.isNotEmpty) 'eventType': eventType,
      if (subjectType != null && subjectType.isNotEmpty)
        'subjectType': subjectType,
      if (actorId != null && actorId.isNotEmpty) 'actorId': actorId,
      'page': page,
      'pageSize': pageSize,
    };
    final result = await _client.get('/api/v1/admin/audit-logs', query: query);
    return switch (result) {
      Success(value: final data) => () {
        final items =
            (data['items'] as List<dynamic>?)
                ?.map(
                  (a) => CmsAuditLogItem.fromJson(
                    Map<String, Object?>.from(a as Map),
                  ),
                )
                .toList() ??
            const <CmsAuditLogItem>[];
        return Success(items);
      }(),
      Failure(failure: final failure) => Failure(failure),
    };
  }

  // --- Phase 2 Implementations ---

  @override
  Future<Result<List<CmsCategory>>> fetchCategories() async {
    final result = await _client.get('/api/v1/admin/categories');
    return switch (result) {
      Success(value: final data) => () {
        final list =
            (data as List<dynamic>?)
                ?.map(
                  (c) =>
                      CmsCategory.fromJson(Map<String, Object?>.from(c as Map)),
                )
                .toList() ??
            const <CmsCategory>[];
        return Success(list);
      }(),
      Failure(failure: final failure) => Failure(failure),
    };
  }

  @override
  Future<Result<CmsCategory>> createCategory({
    required String name,
    String iconName = 'school',
  }) async {
    final result = await _client.post(
      '/api/v1/admin/categories',
      body: {'name': name, 'iconName': iconName},
    );
    return switch (result) {
      Success(value: final data) => Success(CmsCategory.fromJson(data)),
      Failure(failure: final failure) => Failure(failure),
    };
  }

  @override
  Future<Result<CmsCourseDetail>> createCourse(
    Map<String, Object?> payload,
  ) async {
    final result = await _client.post('/api/v1/admin/courses', body: payload);
    return switch (result) {
      Success(value: final data) => Success(CmsCourseDetail.fromJson(data)),
      Failure(failure: final failure) => Failure(failure),
    };
  }

  @override
  Future<Result<CmsCourseDetail>> fetchCourseDetail(String courseId) async {
    final result = await _client.get('/api/v1/admin/courses/$courseId');
    return switch (result) {
      Success(value: final data) => Success(CmsCourseDetail.fromJson(data)),
      Failure(failure: final failure) => Failure(failure),
    };
  }

  @override
  Future<Result<CmsCourseDetail>> updateCourse(
    String courseId,
    Map<String, Object?> payload,
  ) async {
    final result = await _client.put(
      '/api/v1/admin/courses/$courseId',
      body: payload,
    );
    return switch (result) {
      Success(value: final data) => Success(CmsCourseDetail.fromJson(data)),
      Failure(failure: final failure) => Failure(failure),
    };
  }

  @override
  Future<Result<void>> deleteCourse(String courseId, {String? reason}) async {
    final query = <String, Object?>{
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    };
    final result = await _client.delete(
      '/api/v1/admin/courses/$courseId',
      query: query,
    );
    return switch (result) {
      Success() => const Success(null),
      Failure(failure: final failure) => Failure(failure),
    };
  }

  @override
  Future<Result<CmsCourseValidation>> validateCourse(String courseId) async {
    final result = await _client.get(
      '/api/v1/admin/courses/$courseId/validate',
    );
    return switch (result) {
      Success(value: final data) => Success(CmsCourseValidation.fromJson(data)),
      Failure(failure: final failure) => Failure(failure),
    };
  }

  @override
  Future<Result<CmsCourseDetail>> publishCourse(
    String courseId, {
    String? reason,
  }) async {
    final body = <String, Object?>{
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    };
    final result = await _client.post(
      '/api/v1/admin/courses/$courseId/publish',
      body: body,
    );
    return switch (result) {
      Success(value: final data) => Success(CmsCourseDetail.fromJson(data)),
      Failure(failure: final failure) => Failure(failure),
    };
  }

  @override
  Future<Result<CmsCourseDetail>> unpublishCourse(
    String courseId, {
    String? reason,
  }) async {
    final body = <String, Object?>{
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    };
    final result = await _client.post(
      '/api/v1/admin/courses/$courseId/unpublish',
      body: body,
    );
    return switch (result) {
      Success(value: final data) => Success(CmsCourseDetail.fromJson(data)),
      Failure(failure: final failure) => Failure(failure),
    };
  }

  @override
  Future<Result<CmsModuleDetail>> createModule(
    String courseId, {
    required String title,
    String policyKind = 'inherit',
  }) async {
    final result = await _client.post(
      '/api/v1/admin/courses/$courseId/modules',
      body: {'title': title, 'policyKind': policyKind},
    );
    return switch (result) {
      Success(value: final data) => Success(CmsModuleDetail.fromJson(data)),
      Failure(failure: final failure) => Failure(failure),
    };
  }

  @override
  Future<Result<CmsModuleDetail>> updateModule(
    String courseId,
    String moduleId, {
    String? title,
    String? policyKind,
  }) async {
    final body = <String, Object?>{'title': ?title, 'policyKind': ?policyKind};
    final result = await _client.put(
      '/api/v1/admin/courses/$courseId/modules/$moduleId',
      body: body,
    );
    return switch (result) {
      Success(value: final data) => Success(CmsModuleDetail.fromJson(data)),
      Failure(failure: final failure) => Failure(failure),
    };
  }

  @override
  Future<Result<void>> deleteModule(String courseId, String moduleId) async {
    final result = await _client.delete(
      '/api/v1/admin/courses/$courseId/modules/$moduleId',
    );
    return switch (result) {
      Success() => const Success(null),
      Failure(failure: final failure) => Failure(failure),
    };
  }

  @override
  Future<Result<List<CmsModuleDetail>>> reorderModules(
    String courseId,
    List<String> moduleIds,
  ) async {
    final result = await _client.post(
      '/api/v1/admin/courses/$courseId/modules/reorder',
      body: {'moduleIds': moduleIds},
    );
    return switch (result) {
      Success(value: final data) => () {
        final list =
            (data as List<dynamic>?)
                ?.map(
                  (m) => CmsModuleDetail.fromJson(
                    Map<String, Object?>.from(m as Map),
                  ),
                )
                .toList() ??
            const <CmsModuleDetail>[];
        return Success(list);
      }(),
      Failure(failure: final failure) => Failure(failure),
    };
  }

  @override
  Future<Result<CmsLessonDetail>> createLesson(
    String courseId,
    String moduleId,
    Map<String, Object?> payload,
  ) async {
    final result = await _client.post(
      '/api/v1/admin/courses/$courseId/modules/$moduleId/lessons',
      body: payload,
    );
    return switch (result) {
      Success(value: final data) => Success(CmsLessonDetail.fromJson(data)),
      Failure(failure: final failure) => Failure(failure),
    };
  }

  @override
  Future<Result<CmsLessonDetail>> updateLesson(
    String courseId,
    String moduleId,
    String lessonId,
    Map<String, Object?> payload,
  ) async {
    final result = await _client.put(
      '/api/v1/admin/courses/$courseId/modules/$moduleId/lessons/$lessonId',
      body: payload,
    );
    return switch (result) {
      Success(value: final data) => Success(CmsLessonDetail.fromJson(data)),
      Failure(failure: final failure) => Failure(failure),
    };
  }

  @override
  Future<Result<void>> deleteLesson(
    String courseId,
    String moduleId,
    String lessonId,
  ) async {
    final result = await _client.delete(
      '/api/v1/admin/courses/$courseId/modules/$moduleId/lessons/$lessonId',
    );
    return switch (result) {
      Success() => const Success(null),
      Failure(failure: final failure) => Failure(failure),
    };
  }

  @override
  Future<Result<List<CmsLessonDetail>>> reorderLessons(
    String courseId,
    String moduleId,
    List<String> lessonIds,
  ) async {
    final result = await _client.post(
      '/api/v1/admin/courses/$courseId/modules/$moduleId/lessons/reorder',
      body: {'lessonIds': lessonIds},
    );
    return switch (result) {
      Success(value: final data) => () {
        final list =
            (data as List<dynamic>?)
                ?.map(
                  (l) => CmsLessonDetail.fromJson(
                    Map<String, Object?>.from(l as Map),
                  ),
                )
                .toList() ??
            const <CmsLessonDetail>[];
        return Success(list);
      }(),
      Failure(failure: final failure) => Failure(failure),
    };
  }

  @override
  Future<Result<List<CmsAssessmentSummary>>> fetchCourseAssessments(
    String courseId,
  ) async {
    final result = await _client.get(
      '/api/v1/admin/courses/$courseId/assessments',
    );
    return switch (result) {
      Success(value: final data) => () {
        final list =
            (data as List<dynamic>?)
                ?.map(
                  (a) => CmsAssessmentSummary.fromJson(
                    Map<String, Object?>.from(a as Map),
                  ),
                )
                .toList() ??
            const <CmsAssessmentSummary>[];
        return Success(list);
      }(),
      Failure(failure: final failure) => Failure(failure),
    };
  }

  @override
  Future<Result<CmsAssessmentDetail>> createAssessment(
    String courseId,
    Map<String, Object?> payload,
  ) async {
    final result = await _client.post(
      '/api/v1/admin/courses/$courseId/assessments',
      body: payload,
    );
    return switch (result) {
      Success(value: final data) => Success(CmsAssessmentDetail.fromJson(data)),
      Failure(failure: final failure) => Failure(failure),
    };
  }

  @override
  Future<Result<CmsAssessmentDetail>> fetchAssessmentDetail(
    String assessmentId,
  ) async {
    final result = await _client.get('/api/v1/admin/assessments/$assessmentId');
    return switch (result) {
      Success(value: final data) => Success(CmsAssessmentDetail.fromJson(data)),
      Failure(failure: final failure) => Failure(failure),
    };
  }

  @override
  Future<Result<CmsAssessmentDetail>> updateAssessment(
    String assessmentId,
    Map<String, Object?> payload,
  ) async {
    final result = await _client.put(
      '/api/v1/admin/assessments/$assessmentId',
      body: payload,
    );
    return switch (result) {
      Success(value: final data) => Success(CmsAssessmentDetail.fromJson(data)),
      Failure(failure: final failure) => Failure(failure),
    };
  }

  @override
  Future<Result<void>> deleteAssessment(String assessmentId) async {
    final result = await _client.delete(
      '/api/v1/admin/assessments/$assessmentId',
    );
    return switch (result) {
      Success() => const Success(null),
      Failure(failure: final failure) => Failure(failure),
    };
  }

  @override
  Future<Result<CmsQuestionDetail>> createQuestion(
    String assessmentId,
    Map<String, Object?> payload,
  ) async {
    final result = await _client.post(
      '/api/v1/admin/assessments/$assessmentId/questions',
      body: payload,
    );
    return switch (result) {
      Success(value: final data) => Success(CmsQuestionDetail.fromJson(data)),
      Failure(failure: final failure) => Failure(failure),
    };
  }

  @override
  Future<Result<CmsQuestionDetail>> updateQuestion(
    String assessmentId,
    String questionId,
    Map<String, Object?> payload,
  ) async {
    final result = await _client.put(
      '/api/v1/admin/assessments/$assessmentId/questions/$questionId',
      body: payload,
    );
    return switch (result) {
      Success(value: final data) => Success(CmsQuestionDetail.fromJson(data)),
      Failure(failure: final failure) => Failure(failure),
    };
  }

  @override
  Future<Result<void>> deleteQuestion(
    String assessmentId,
    String questionId,
  ) async {
    final result = await _client.delete(
      '/api/v1/admin/assessments/$assessmentId/questions/$questionId',
    );
    return switch (result) {
      Success() => const Success(null),
      Failure(failure: final failure) => Failure(failure),
    };
  }

  @override
  Future<Result<List<CmsQuestionDetail>>> reorderQuestions(
    String assessmentId,
    List<String> questionIds,
  ) async {
    final result = await _client.post(
      '/api/v1/admin/assessments/$assessmentId/questions/reorder',
      body: {'questionIds': questionIds},
    );
    return switch (result) {
      Success(value: final data) => () {
        final list =
            (data as List<dynamic>?)
                ?.map(
                  (q) => CmsQuestionDetail.fromJson(
                    Map<String, Object?>.from(q as Map),
                  ),
                )
                .toList() ??
            const <CmsQuestionDetail>[];
        return Success(list);
      }(),
      Failure(failure: final failure) => Failure(failure),
    };
  }
}
