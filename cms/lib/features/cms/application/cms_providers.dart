import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nadha_cms/bootstrap/cms_providers.dart';
import 'package:nadha_cms/features/cms/application/cms_assessment_editor_controller.dart';
import 'package:nadha_cms/features/cms/application/cms_audit_controller.dart';
import 'package:nadha_cms/features/cms/application/cms_course_editor_controller.dart';
import 'package:nadha_cms/features/cms/application/cms_courses_controller.dart';
import 'package:nadha_cms/features/cms/application/cms_dashboard_controller.dart';
import 'package:nadha_cms/features/cms/application/cms_users_controller.dart';
import 'package:nadha_cms/features/cms/data/backend_cms_data_source.dart';
import 'package:nadha_cms/features/cms/data/cms_remote_data_source.dart';
import 'package:nadha_cms/features/cms/data/cms_repository.dart';

final cmsDataSourceProvider = Provider<CmsRemoteDataSource>((ref) {
  return BackendCmsDataSource(client: ref.watch(apiClientProvider));
});

final cmsRepositoryProvider = Provider<CmsRepository>((ref) {
  return CmsRepositoryImpl(remoteDataSource: ref.watch(cmsDataSourceProvider));
});

final cmsDashboardControllerProvider =
    StateNotifierProvider.autoDispose<
      CmsDashboardController,
      CmsDashboardState
    >(
      (ref) =>
          CmsDashboardController(repository: ref.watch(cmsRepositoryProvider)),
    );

final cmsCoursesControllerProvider =
    StateNotifierProvider.autoDispose<CmsCoursesController, CmsCoursesState>(
      (ref) =>
          CmsCoursesController(repository: ref.watch(cmsRepositoryProvider)),
    );

final cmsUsersControllerProvider =
    StateNotifierProvider.autoDispose<CmsUsersController, CmsUsersState>(
      (ref) => CmsUsersController(repository: ref.watch(cmsRepositoryProvider)),
    );

final cmsAuditControllerProvider =
    StateNotifierProvider.autoDispose<CmsAuditController, CmsAuditState>(
      (ref) => CmsAuditController(repository: ref.watch(cmsRepositoryProvider)),
    );

final cmsCourseEditorControllerProvider = StateNotifierProvider.autoDispose
    .family<CmsCourseEditorController, CmsCourseEditorState, String>(
      (ref, courseId) => CmsCourseEditorController(
        repository: ref.watch(cmsRepositoryProvider),
        courseId: courseId,
      ),
    );

typedef CmsAssessmentEditorParams = ({String assessmentId, String? courseId});

final cmsAssessmentEditorControllerProvider = StateNotifierProvider.autoDispose
    .family<
      CmsAssessmentEditorController,
      CmsAssessmentEditorState,
      CmsAssessmentEditorParams
    >(
      (ref, params) => CmsAssessmentEditorController(
        repository: ref.watch(cmsRepositoryProvider),
        assessmentId: params.assessmentId,
        courseId: params.courseId,
      ),
    );
