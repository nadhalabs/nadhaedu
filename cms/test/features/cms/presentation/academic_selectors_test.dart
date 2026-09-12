import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nadha_cms/features/cms/academic.dart';
import 'package:nadha_cms/features/cms/domain/cms_course.dart';

void main() {
  test('academic classification survives CMS summary decoding', () {
    final summary = CmsCourseSummary.fromJson({
      'id': 'offering',
      'curriculumId': 'board',
      'standardId': 'class',
      'streamId': null,
      'subjectId': 'physics',
    });
    expect(summary.academic, {
      'curriculumId': 'board',
      'standardId': 'class',
      'streamId': null,
      'subjectId': 'physics',
    });
  });

  testWidgets('curriculum change clears dependent standard and stream', (
    tester,
  ) async {
    var selection = <String, Object?>{
      'curriculumId': 'b',
      'standardId': '11',
      'streamId': 'science',
      'subjectId': 'physics',
    };
    const records = <String, List<AcademicRow>>{
      'curricula': [
        {'id': 'a', 'name': 'CBSE', 'isActive': true},
        {'id': 'b', 'name': 'Kerala', 'isActive': true},
      ],
      'standards': [
        {'id': '10', 'name': 'Class 10', 'curriculumId': 'a', 'isActive': true},
        {'id': '11', 'name': 'Plus One', 'curriculumId': 'b', 'isActive': true},
      ],
      'streams': [
        {
          'id': 'science',
          'name': 'Science',
          'standardId': '11',
          'isActive': true,
        },
      ],
      'subjects': [
        {'id': 'physics', 'name': 'Physics', 'isActive': true},
      ],
    };
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          academicRecordsProvider.overrideWith(
            (ref, kind) async => records[kind]!,
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => AcademicSelectors(
                value: selection,
                onChanged: (v) => setState(() => selection = v),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Science'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('CBSE').last);
    await tester.pumpAndSettle();
    expect(selection['standardId'], isNull);
    expect(selection['streamId'], isNull);
    expect(selection['subjectId'], 'physics');
    expect(find.text('Science'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
