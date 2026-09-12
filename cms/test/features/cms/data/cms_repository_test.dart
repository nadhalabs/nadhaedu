import 'package:flutter_test/flutter_test.dart';
import 'package:nadha_cms/core/errors/result.dart';
import 'package:nadha_cms/features/cms/data/cms_repository.dart';
import 'package:nadha_cms/features/cms/data/foundation_cms_data_source.dart';

void main() {
  group('CmsRepository & FoundationDataSource Tests', () {
    late CmsRepository repository;

    setUp(() {
      repository = CmsRepositoryImpl(
        remoteDataSource: FoundationCmsDataSource(),
      );
    });

    test('getDashboardData returns structured operational telemetry', () async {
      final result = await repository.getDashboardData();
      expect(result, isA<Success>());
      final data = (result as Success).value;
      expect(data.metrics.totalCourses, greaterThanOrEqualTo(3));
      expect(data.metrics.totalUsers, greaterThanOrEqualTo(4));
      expect(data.systemReadiness.isReady, isTrue);
      expect(data.recentPurchases, isNotEmpty);
      expect(data.recentActivity, isNotEmpty);
    });

    test('getCourses filters by status and search', () async {
      final allResult = await repository.getCourses();
      expect(allResult, isA<Success>());
      expect((allResult as Success).value.length, 3);

      final publishedResult = await repository.getCourses(status: 'published');
      expect(publishedResult, isA<Success>());
      expect((publishedResult as Success).value.length, 2);

      final searchResult = await repository.getCourses(search: 'Flutter');
      expect(searchResult, isA<Success>());
      expect((searchResult as Success).value.length, 2);
    });

    test(
      'updateCourseStatus updates course status and adds audit record',
      () async {
        final updateResult = await repository.updateCourseStatus(
          courseId: 'course-2',
          status: 'published',
          reason: 'Ready for launch',
        );
        expect(updateResult, isA<Success>());
        final updated = (updateResult as Success).value;
        expect(updated.status, 'published');

        // Verify audit logs now contain this operation
        final auditResult = await repository.getAuditLogs();
        expect(auditResult, isA<Success>());
        final logs = (auditResult as Success).value;
        expect(logs.first.action, 'course.status_updated');
        expect(logs.first.targetId, 'course-2');
        expect(logs.first.reason, 'Ready for launch');
      },
    );

    test('getUsers filters by role', () async {
      final adminsResult = await repository.getUsers(role: 'admin');
      expect(adminsResult, isA<Success>());
      expect((adminsResult as Success).value.length, 1);
    });

    test('Phase 2: categories CRUD and course detail retrieval', () async {
      final catsResult = await repository.getCategories();
      expect(catsResult, isA<Success>());
      final cats = (catsResult as Success).value;
      expect(cats, isNotEmpty);

      final courseResult = await repository.getCourseDetail('course-1');
      expect(courseResult, isA<Success>());
      final course = (courseResult as Success).value;
      expect(course.title, 'Complete Flutter & Dart Architecture');
      expect(course.modules, isNotEmpty);
      expect(course.modules.first.lessons, isNotEmpty);
      expect(course.validation.canPublish, isTrue);
    });

    test('Phase 2: module and lesson management workflow', () async {
      // Add a module
      final addModResult = await repository.createModule(
        'course-2',
        title: 'New Advanced Section',
      );
      expect(addModResult, isA<Success>());
      final newMod = (addModResult as Success).value;
      expect(newMod.title, 'New Advanced Section');

      // Add a lesson to the new module
      final addLessResult = await repository
          .createLesson('course-2', newMod.id, {
            'title': 'Advanced State Machine',
            'durationSeconds': 600,
            'contentType': 'video',
            'contentRef': 'vid_state_machine_01',
            'isPreview': false,
            'isDownloadable': true,
            'policyKind': 'inherit',
            'protectionPolicy': 'blockCaptureWhereSupported',
          });
      expect(addLessResult, isA<Success>());
      final newLess = (addLessResult as Success).value;
      expect(newLess.title, 'Advanced State Machine');
      expect(newLess.durationSeconds, 600);

      // Verify course detail updated duration
      final updatedCourseResult = await repository.getCourseDetail('course-2');
      expect(updatedCourseResult, isA<Success>());
      final updatedCourse = (updatedCourseResult as Success).value;
      expect(updatedCourse.modules.any((m) => m.id == newMod.id), isTrue);

      // Reorder modules
      final modIds = updatedCourse.modules
          .map((m) => m.id)
          .toList()
          .reversed
          .cast<String>()
          .toList();
      final reorderResult = await repository.reorderModules('course-2', modIds);
      expect(reorderResult, isA<Success>());
    });

    test('Phase 2: assessment and question management', () async {
      final assResult = await repository.getAssessmentDetail('quiz-1');
      expect(assResult, isA<Success>());
      final ass = (assResult as Success).value;
      expect(ass.title, 'Architecture Readiness Assessment');
      expect(ass.questions, isNotEmpty);
      expect(ass.questions.first.gradingData['correctOptionId'], isNotNull);

      // Add question
      final addQResult = await repository.createQuestion('quiz-1', {
        'type': 'singleChoice',
        'prompt': 'What does Riverpod use to store state?',
        'points': 2,
        'explanation': 'Riverpod stores provider state in a ProviderContainer.',
        'options': [
          {'id': 'opt-0', 'text': 'ProviderContainer', 'position': 1},
          {'id': 'opt-1', 'text': 'InheritedWidget', 'position': 2},
        ],
        'gradingData': {'correctOptionId': 'opt-0'},
      });
      expect(addQResult, isA<Success>());
      final newQ = (addQResult as Success).value;
      expect(newQ.prompt, 'What does Riverpod use to store state?');
    });

    test('Phase 2: course publishing and unpublishing', () async {
      final publishResult = await repository.publishCourse(
        'course-2',
        reason: 'Passed QA',
      );
      expect(publishResult, isA<Success>());
      final published = (publishResult as Success).value;
      expect(published.status, 'published');

      final unpublishResult = await repository.unpublishCourse(
        'course-2',
        reason: 'Updating content',
      );
      expect(unpublishResult, isA<Success>());
      final draft = (unpublishResult as Success).value;
      expect(draft.status, 'draft');
    });
  });
}
