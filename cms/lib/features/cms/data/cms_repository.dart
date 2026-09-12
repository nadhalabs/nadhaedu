import 'package:nadha_cms/core/errors/result.dart';
import 'package:nadha_cms/features/cms/data/cms_remote_data_source.dart';
import 'package:nadha_cms/features/cms/domain/cms_assessment.dart';
import 'package:nadha_cms/features/cms/domain/cms_audit_log.dart';
import 'package:nadha_cms/features/cms/domain/cms_course.dart';
import 'package:nadha_cms/features/cms/domain/cms_course_detail.dart';
import 'package:nadha_cms/features/cms/domain/cms_dashboard_data.dart';
import 'package:nadha_cms/features/cms/domain/cms_user.dart';

abstract interface class CmsRepository {
  Future<Result<CmsDashboardData>> getDashboardData();

  Future<Result<List<CmsCourseSummary>>> getCourses({
    String? status,
    String? search,
    int page = 1,
    int pageSize = 20,
  });

  Future<Result<CmsCourseSummary>> updateCourseStatus({
    required String courseId,
    required String status,
    String? reason,
  });

  Future<Result<List<CmsUserSummary>>> getUsers({
    String? role,
    String? search,
    int page = 1,
    int pageSize = 20,
  });

  Future<Result<List<CmsAuditLogItem>>> getAuditLogs({
    String? eventType,
    String? subjectType,
    String? actorId,
    int page = 1,
    int pageSize = 20,
  });

  // Phase 2: Categories
  Future<Result<List<CmsCategory>>> getCategories();
  Future<Result<CmsCategory>> createCategory({
    required String name,
    String iconName = 'school',
  });

  // Phase 2: Course Detail & Publishing
  Future<Result<CmsCourseDetail>> createCourse(Map<String, Object?> payload);
  Future<Result<CmsCourseDetail>> getCourseDetail(String courseId);
  Future<Result<CmsCourseDetail>> updateCourse(
    String courseId,
    Map<String, Object?> payload,
  );
  Future<Result<void>> deleteCourse(String courseId, {String? reason});
  Future<Result<CmsCourseValidation>> validateCourse(String courseId);
  Future<Result<CmsCourseDetail>> publishCourse(
    String courseId, {
    String? reason,
  });
  Future<Result<CmsCourseDetail>> unpublishCourse(
    String courseId, {
    String? reason,
  });

  // Phase 2: Modules
  Future<Result<CmsModuleDetail>> createModule(
    String courseId, {
    required String title,
    String policyKind = 'inherit',
  });
  Future<Result<CmsModuleDetail>> updateModule(
    String courseId,
    String moduleId, {
    String? title,
    String? policyKind,
  });
  Future<Result<void>> deleteModule(String courseId, String moduleId);
  Future<Result<List<CmsModuleDetail>>> reorderModules(
    String courseId,
    List<String> moduleIds,
  );

  // Phase 2: Lessons
  Future<Result<CmsLessonDetail>> createLesson(
    String courseId,
    String moduleId,
    Map<String, Object?> payload,
  );
  Future<Result<CmsLessonDetail>> updateLesson(
    String courseId,
    String moduleId,
    String lessonId,
    Map<String, Object?> payload,
  );
  Future<Result<void>> deleteLesson(
    String courseId,
    String moduleId,
    String lessonId,
  );
  Future<Result<List<CmsLessonDetail>>> reorderLessons(
    String courseId,
    String moduleId,
    List<String> lessonIds,
  );

  // Phase 2: Assessments
  Future<Result<List<CmsAssessmentSummary>>> getCourseAssessments(
    String courseId,
  );
  Future<Result<CmsAssessmentDetail>> createAssessment(
    String courseId,
    Map<String, Object?> payload,
  );
  Future<Result<CmsAssessmentDetail>> getAssessmentDetail(String assessmentId);
  Future<Result<CmsAssessmentDetail>> updateAssessment(
    String assessmentId,
    Map<String, Object?> payload,
  );
  Future<Result<void>> deleteAssessment(String assessmentId);

  // Phase 2: Questions
  Future<Result<CmsQuestionDetail>> createQuestion(
    String assessmentId,
    Map<String, Object?> payload,
  );
  Future<Result<CmsQuestionDetail>> updateQuestion(
    String assessmentId,
    String questionId,
    Map<String, Object?> payload,
  );
  Future<Result<void>> deleteQuestion(String assessmentId, String questionId);
  Future<Result<List<CmsQuestionDetail>>> reorderQuestions(
    String assessmentId,
    List<String> questionIds,
  );
}

final class CmsRepositoryImpl implements CmsRepository {
  const CmsRepositoryImpl({required CmsRemoteDataSource remoteDataSource})
    : _remote = remoteDataSource;

  final CmsRemoteDataSource _remote;

  @override
  Future<Result<CmsDashboardData>> getDashboardData() =>
      _remote.fetchDashboardData();

  @override
  Future<Result<List<CmsCourseSummary>>> getCourses({
    String? status,
    String? search,
    int page = 1,
    int pageSize = 20,
  }) => _remote.fetchCourses(
    status: status,
    search: search,
    page: page,
    pageSize: pageSize,
  );

  @override
  Future<Result<CmsCourseSummary>> updateCourseStatus({
    required String courseId,
    required String status,
    String? reason,
  }) => _remote.updateCourseStatus(
    courseId: courseId,
    status: status,
    reason: reason,
  );

  @override
  Future<Result<List<CmsUserSummary>>> getUsers({
    String? role,
    String? search,
    int page = 1,
    int pageSize = 20,
  }) => _remote.fetchUsers(
    role: role,
    search: search,
    page: page,
    pageSize: pageSize,
  );

  @override
  Future<Result<List<CmsAuditLogItem>>> getAuditLogs({
    String? eventType,
    String? subjectType,
    String? actorId,
    int page = 1,
    int pageSize = 20,
  }) => _remote.fetchAuditLogs(
    eventType: eventType,
    subjectType: subjectType,
    actorId: actorId,
    page: page,
    pageSize: pageSize,
  );

  // Phase 2
  @override
  Future<Result<List<CmsCategory>>> getCategories() =>
      _remote.fetchCategories();

  @override
  Future<Result<CmsCategory>> createCategory({
    required String name,
    String iconName = 'school',
  }) => _remote.createCategory(name: name, iconName: iconName);

  @override
  Future<Result<CmsCourseDetail>> createCourse(Map<String, Object?> payload) =>
      _remote.createCourse(payload);

  @override
  Future<Result<CmsCourseDetail>> getCourseDetail(String courseId) =>
      _remote.fetchCourseDetail(courseId);

  @override
  Future<Result<CmsCourseDetail>> updateCourse(
    String courseId,
    Map<String, Object?> payload,
  ) => _remote.updateCourse(courseId, payload);

  @override
  Future<Result<void>> deleteCourse(String courseId, {String? reason}) =>
      _remote.deleteCourse(courseId, reason: reason);

  @override
  Future<Result<CmsCourseValidation>> validateCourse(String courseId) =>
      _remote.validateCourse(courseId);

  @override
  Future<Result<CmsCourseDetail>> publishCourse(
    String courseId, {
    String? reason,
  }) => _remote.publishCourse(courseId, reason: reason);

  @override
  Future<Result<CmsCourseDetail>> unpublishCourse(
    String courseId, {
    String? reason,
  }) => _remote.unpublishCourse(courseId, reason: reason);

  @override
  Future<Result<CmsModuleDetail>> createModule(
    String courseId, {
    required String title,
    String policyKind = 'inherit',
  }) => _remote.createModule(courseId, title: title, policyKind: policyKind);

  @override
  Future<Result<CmsModuleDetail>> updateModule(
    String courseId,
    String moduleId, {
    String? title,
    String? policyKind,
  }) => _remote.updateModule(
    courseId,
    moduleId,
    title: title,
    policyKind: policyKind,
  );

  @override
  Future<Result<void>> deleteModule(String courseId, String moduleId) =>
      _remote.deleteModule(courseId, moduleId);

  @override
  Future<Result<List<CmsModuleDetail>>> reorderModules(
    String courseId,
    List<String> moduleIds,
  ) => _remote.reorderModules(courseId, moduleIds);

  @override
  Future<Result<CmsLessonDetail>> createLesson(
    String courseId,
    String moduleId,
    Map<String, Object?> payload,
  ) => _remote.createLesson(courseId, moduleId, payload);

  @override
  Future<Result<CmsLessonDetail>> updateLesson(
    String courseId,
    String moduleId,
    String lessonId,
    Map<String, Object?> payload,
  ) => _remote.updateLesson(courseId, moduleId, lessonId, payload);

  @override
  Future<Result<void>> deleteLesson(
    String courseId,
    String moduleId,
    String lessonId,
  ) => _remote.deleteLesson(courseId, moduleId, lessonId);

  @override
  Future<Result<List<CmsLessonDetail>>> reorderLessons(
    String courseId,
    String moduleId,
    List<String> lessonIds,
  ) => _remote.reorderLessons(courseId, moduleId, lessonIds);

  @override
  Future<Result<List<CmsAssessmentSummary>>> getCourseAssessments(
    String courseId,
  ) => _remote.fetchCourseAssessments(courseId);

  @override
  Future<Result<CmsAssessmentDetail>> createAssessment(
    String courseId,
    Map<String, Object?> payload,
  ) => _remote.createAssessment(courseId, payload);

  @override
  Future<Result<CmsAssessmentDetail>> getAssessmentDetail(
    String assessmentId,
  ) => _remote.fetchAssessmentDetail(assessmentId);

  @override
  Future<Result<CmsAssessmentDetail>> updateAssessment(
    String assessmentId,
    Map<String, Object?> payload,
  ) => _remote.updateAssessment(assessmentId, payload);

  @override
  Future<Result<void>> deleteAssessment(String assessmentId) =>
      _remote.deleteAssessment(assessmentId);

  @override
  Future<Result<CmsQuestionDetail>> createQuestion(
    String assessmentId,
    Map<String, Object?> payload,
  ) => _remote.createQuestion(assessmentId, payload);

  @override
  Future<Result<CmsQuestionDetail>> updateQuestion(
    String assessmentId,
    String questionId,
    Map<String, Object?> payload,
  ) => _remote.updateQuestion(assessmentId, questionId, payload);

  @override
  Future<Result<void>> deleteQuestion(String assessmentId, String questionId) =>
      _remote.deleteQuestion(assessmentId, questionId);

  @override
  Future<Result<List<CmsQuestionDetail>>> reorderQuestions(
    String assessmentId,
    List<String> questionIds,
  ) => _remote.reorderQuestions(assessmentId, questionIds);
}
