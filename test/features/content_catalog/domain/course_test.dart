import 'package:flutter_test/flutter_test.dart';

import 'package:learning_platform/features/content_catalog/domain/catalog_query.dart';
import 'package:learning_platform/features/content_catalog/domain/course.dart';

void main() {
  test('lesson content model covers every supported delivery type', () {
    final contents = <LessonContent>[
      const VideoLessonContent(assetId: 'video'),
      const ArticleLessonContent(documentId: 'article'),
      const ResourceLessonContent(resourceId: 'resource', fileType: 'pdf'),
      const QuizLessonContent(assessmentId: 'quiz', questionCount: 5),
      const AssignmentLessonContent(assignmentId: 'assignment'),
      LiveClassLessonContent(eventId: 'event', startsAt: DateTime.utc(2026)),
      const ProjectLessonContent(
        projectId: 'project',
        briefDocumentId: 'brief',
      ),
    ];
    expect(contents, hasLength(7));
    expect(
      contents.map((content) => content.runtimeType).toSet(),
      hasLength(7),
    );
  });

  test('catalog query creates stable keys and bounded page sizes', () {
    const first = CatalogQuery(searchTerm: 'Design', pageSize: 20);
    const same = CatalogQuery(searchTerm: 'design', pageSize: 20);
    expect(first.cacheKey, same.cacheKey);
    expect(() => CatalogQuery(pageSize: 51), throwsAssertionError);
  });
}
