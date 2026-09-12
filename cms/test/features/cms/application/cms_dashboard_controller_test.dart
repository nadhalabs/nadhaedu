import 'package:flutter_test/flutter_test.dart';
import 'package:nadha_cms/core/errors/app_failure.dart';
import 'package:nadha_cms/core/errors/result.dart';
import 'package:nadha_cms/features/cms/application/cms_dashboard_controller.dart';
import 'package:nadha_cms/features/cms/data/cms_repository.dart';
import 'package:nadha_cms/features/cms/data/foundation_cms_data_source.dart';
import 'package:nadha_cms/features/cms/domain/cms_audit_log.dart';
import 'package:nadha_cms/features/cms/domain/cms_course.dart';
import 'package:nadha_cms/features/cms/domain/cms_dashboard_data.dart';
import 'package:nadha_cms/features/cms/domain/cms_user.dart';

final class MockFailingCmsRepository implements CmsRepository {
  @override
  Future<Result<CmsDashboardData>> getDashboardData() async {
    return const Failure(
      UnexpectedFailure(
        code: 'SERVER_ERROR',
        message: 'Failed to fetch telemetry',
      ),
    );
  }

  @override
  Future<Result<List<CmsCourseSummary>>> getCourses({
    String? status,
    String? search,
    int page = 1,
    int pageSize = 20,
  }) async => const Failure(UnexpectedFailure(code: 'ERROR', message: 'Error'));

  @override
  Future<Result<CmsCourseSummary>> updateCourseStatus({
    required String courseId,
    required String status,
    String? reason,
  }) async => const Failure(UnexpectedFailure(code: 'ERROR', message: 'Error'));

  @override
  Future<Result<List<CmsUserSummary>>> getUsers({
    String? role,
    String? search,
    int page = 1,
    int pageSize = 20,
  }) async => const Failure(UnexpectedFailure(code: 'ERROR', message: 'Error'));

  @override
  Future<Result<List<CmsAuditLogItem>>> getAuditLogs({
    String? eventType,
    String? subjectType,
    String? actorId,
    int page = 1,
    int pageSize = 20,
  }) async => const Failure(UnexpectedFailure(code: 'ERROR', message: 'Error'));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('CmsDashboardController Tests', () {
    test('loads dashboard data successfully on initialization', () async {
      final repository = CmsRepositoryImpl(
        remoteDataSource: FoundationCmsDataSource(),
      );
      final controller = CmsDashboardController(repository: repository);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(controller.state.isLoading, isFalse);
      expect(controller.state.data, isNotNull);
      expect(controller.state.errorMessage, isNull);
    });

    test('handles failure gracefully with error message', () async {
      final failingRepo = MockFailingCmsRepository();
      final controller = CmsDashboardController(repository: failingRepo);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(controller.state.isLoading, isFalse);
      expect(controller.state.data, isNull);
      expect(controller.state.errorMessage, 'Failed to fetch telemetry');
    });

    test('refresh updates state and clears previous errors', () async {
      final repository = CmsRepositoryImpl(
        remoteDataSource: FoundationCmsDataSource(),
      );
      final controller = CmsDashboardController(repository: repository);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await controller.refresh();
      expect(controller.state.isRefreshing, isFalse);
      expect(controller.state.data, isNotNull);
    });
  });
}
