import 'package:flutter_test/flutter_test.dart';
import 'package:nadha_cms/features/cms/application/cms_course_editor_controller.dart';
import 'package:nadha_cms/features/cms/data/cms_repository.dart';
import 'package:nadha_cms/features/cms/data/foundation_cms_data_source.dart';

void main() {
  group('CmsCourseEditorController Tests', () {
    late CmsRepository repository;
    late CmsCourseEditorController controller;

    setUp(() async {
      repository = CmsRepositoryImpl(
        remoteDataSource: FoundationCmsDataSource(),
      );
      controller = CmsCourseEditorController(
        repository: repository,
        courseId: 'course-1',
      );
      // Wait for initial load
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });

    test('loads course detail and categories successfully', () {
      final state = controller.state;
      expect(state.course, isNotNull);
      expect(state.course!.title, 'Complete Flutter & Dart Architecture');
      expect(state.categories, isNotEmpty);
      expect(state.course!.modules.length, 1);
      expect(state.course!.validation.canPublish, isTrue);
    });

    test('adds and edits curriculum sections and lessons', () async {
      // Add module
      final addModSuccess = await controller.addModule('Advanced Networking');
      expect(addModSuccess, isTrue);
      expect(
        controller.state.course!.modules.any(
          (m) => m.title == 'Advanced Networking',
        ),
        isTrue,
      );

      final addedMod = controller.state.course!.modules.firstWhere(
        (m) => m.title == 'Advanced Networking',
      );

      // Add lesson
      final addLessSuccess = await controller.addLesson(addedMod.id, {
        'title': 'Dio & Interceptors',
        'durationSeconds': 420,
        'contentType': 'video',
        'contentRef': 'vid_dio_01',
        'isPreview': false,
        'isDownloadable': true,
        'policyKind': 'inherit',
        'protectionPolicy': 'blockCaptureWhereSupported',
      });
      expect(addLessSuccess, isTrue);

      // Verify lesson exists in module
      final reloadedMod = controller.state.course!.modules.firstWhere(
        (m) => m.id == addedMod.id,
      );
      expect(reloadedMod.lessons.length, 1);
      expect(reloadedMod.lessons.first.title, 'Dio & Interceptors');
    });

    test('updates course metadata', () async {
      final saveSuccess = await controller.saveMetadata(
        title: 'Updated Flutter Architecture',
        subtitle: 'Production Guide',
        description:
            'Comprehensive updated guide for architecting Flutter apps.',
        level: 'advanced',
        languageCode: 'en',
        policyKind: 'premium',
        protectionPolicy: 'blockCaptureWhereSupported',
        categoryIds: ['cat-mobile'],
        tags: ['flutter', 'dart', 'advanced'],
        learningOutcomes: ['Master clean architecture'],
        prerequisites: ['Basic Dart syntax'],
      );
      expect(saveSuccess, isTrue);
      expect(controller.state.course!.title, 'Updated Flutter Architecture');
      expect(controller.state.course!.level, 'advanced');
    });

    test('publishes and unpublishes course with state updates', () async {
      // Unpublish
      final unpubSuccess = await controller.unpublish(reason: 'Maintenance');
      expect(unpubSuccess, isTrue);
      expect(controller.state.course!.isDraft, isTrue);

      // Publish
      final pubSuccess = await controller.publish(reason: 'Ready to launch');
      expect(pubSuccess, isTrue);
      expect(controller.state.course!.isPublished, isTrue);
    });
  });
}
