import 'package:nadha_cms/core/errors/result.dart';
import 'package:nadha_cms/features/cms/domain/cms_assessment.dart';
import 'package:nadha_cms/features/cms/domain/cms_audit_log.dart';
import 'package:nadha_cms/features/cms/domain/cms_course.dart';
import 'package:nadha_cms/features/cms/domain/cms_course_detail.dart';
import 'package:nadha_cms/features/cms/domain/cms_dashboard_data.dart';
import 'package:nadha_cms/features/cms/domain/cms_user.dart';

abstract interface class CmsRemoteDataSource {
  Future<Result<CmsDashboardData>> fetchDashboardData();

  Future<Result<List<CmsCourseSummary>>> fetchCourses({
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

  Future<Result<List<CmsUserSummary>>> fetchUsers({
    String? role,
    String? search,
    int page = 1,
    int pageSize = 20,
  });

  Future<Result<List<CmsAuditLogItem>>> fetchAuditLogs({
    String? eventType,
    String? subjectType,
    String? actorId,
    int page = 1,
    int pageSize = 20,
  });

  // Phase 2: Categories
  Future<Result<List<CmsCategory>>> fetchCategories();
  Future<Result<CmsCategory>> createCategory({
    required String name,
    String iconName = 'school',
  });

  // Phase 2: Course Full Management
  Future<Result<CmsCourseDetail>> createCourse(Map<String, Object?> payload);
  Future<Result<CmsCourseDetail>> fetchCourseDetail(String courseId);
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

  // Phase 2: Curriculum (Sections / Modules)
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

  // Phase 2: Assessments & Quizzes
  Future<Result<List<CmsAssessmentSummary>>> fetchCourseAssessments(
    String courseId,
  );
  Future<Result<CmsAssessmentDetail>> createAssessment(
    String courseId,
    Map<String, Object?> payload,
  );
  Future<Result<CmsAssessmentDetail>> fetchAssessmentDetail(
    String assessmentId,
  );
  Future<Result<CmsAssessmentDetail>> updateAssessment(
    String assessmentId,
    Map<String, Object?> payload,
  );
  Future<Result<void>> deleteAssessment(String assessmentId);

  // Phase 2: Questions & Grading Keys
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
