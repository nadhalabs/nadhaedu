import 'package:flutter_test/flutter_test.dart';
import 'package:nadha_cms/features/cms/application/cms_assessment_editor_controller.dart';
import 'package:nadha_cms/features/cms/data/cms_repository.dart';
import 'package:nadha_cms/features/cms/data/foundation_cms_data_source.dart';

void main() {
  group('CmsAssessmentEditorController Tests', () {
    late CmsRepository repository;
    late CmsAssessmentEditorController controller;

    setUp(() async {
      repository = CmsRepositoryImpl(
        remoteDataSource: FoundationCmsDataSource(),
      );
      controller = CmsAssessmentEditorController(
        repository: repository,
        assessmentId: 'quiz-1',
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });

    test('loads assessment details and questions with grading keys', () {
      final state = controller.state;
      expect(state.assessment, isNotNull);
      expect(state.assessment!.title, 'Architecture Readiness Assessment');
      expect(state.assessment!.questions.length, 1);
      expect(
        state.assessment!.questions.first.gradingData['correctOptionId'],
        isNotNull,
      );
    });

    test('adds question and updates total points', () async {
      final addSuccess = await controller.addQuestion({
        'type': 'trueFalse',
        'prompt': 'StatelessWidget can maintain mutable state across frames.',
        'points': 1,
        'explanation': 'StatelessWidget is immutable.',
        'options': const [],
        'gradingData': {'correctValue': false},
        'settings': const {},
      });
      expect(addSuccess, isTrue);

      final state = controller.state;
      expect(state.assessment!.questions.length, 2);
      expect(state.assessment!.questions.last.type, 'trueFalse');
    });

    test(
      'updates assessment pass criteria and certificate requirements',
      () async {
        final saveSuccess = await controller.saveAssessment(
          title: 'Updated Final Quiz',
          description: 'Comprehensive evaluation',
          instructions: ['Complete in one sitting'],
          passingPercentage: 80,
          timeLimitSeconds: 2400,
          maxAttempts: 2,
          requiredForCertificate: true,
          protectionPolicy: 'blockCaptureWhereSupported',
          status: 'published',
        );
        expect(saveSuccess, isTrue);
        expect(controller.state.assessment!.passingPercentage, 80);
        expect(controller.state.assessment!.maxAttempts, 2);
      },
    );
  });
}
