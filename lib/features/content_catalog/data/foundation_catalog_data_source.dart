import 'dart:math';
import 'package:learning_platform/features/academic/academic_profile.dart';

import 'package:learning_platform/features/content_catalog/data/catalog_data_source.dart';
import 'package:learning_platform/features/content_catalog/domain/catalog_query.dart';
import 'package:learning_platform/features/content_catalog/domain/course.dart';
import 'package:learning_platform/features/content_catalog/domain/home_feed.dart';
import 'package:learning_platform/features/entitlements/domain/access_policy.dart';

final class FoundationCatalogDataSource implements CatalogDataSource {
  FoundationCatalogDataSource({this.academicProfile})
    : _categories = const [
        CourseCategory(
          id: 'development',
          name: 'Development',
          iconName: 'code',
        ),
        CourseCategory(id: 'design', name: 'Design', iconName: 'palette'),
        CourseCategory(id: 'business', name: 'Business', iconName: 'business'),
        CourseCategory(id: 'data', name: 'Data', iconName: 'analytics'),
        CourseCategory(
          id: 'wellbeing',
          name: 'Wellbeing',
          iconName: 'wellbeing',
        ),
      ] {
    _courses = List.generate(36, _createCourse, growable: false);
    _byId = {
      for (final course in [..._courses, ..._academicFixtures])
        course.summary.id: course,
    };
  }

  final AcademicProfile? Function()? academicProfile;
  List<Course> get _visibleCourses {
    final profile = academicProfile?.call();
    if (profile == null) return _courses;
    return _academicFixtures
        .where(
          (c) =>
              c.summary.curriculumId == profile.curriculumId &&
              c.summary.standardId == profile.standardId &&
              c.summary.streamId == profile.streamId,
        )
        .toList();
  }

  // Isolated development records; never reclassify or reuse the legacy demo IDs.
  late final List<Course> _academicFixtures = [
    for (final index in [0, 1]) _createAcademicFixture(index),
  ];
  Course _createAcademicFixture(int index) {
    final id = 'academic-fixture-offering-$index';
    final title = index == 0 ? 'Reflection' : 'SI Units';
    return Course(
      summary: CourseSummary(
        id: id,
        title: index == 0 ? 'Physics — Class 10' : 'Physics — Plus One',
        subtitle: 'Academic development fixture',
        instructors: const [],
        categoryIds: const {'fixture-physics'},
        level: CourseLevel.allLevels,
        policy: const AccessPolicy.free(),
        languageCode: 'en',
        rating: 0,
        ratingCount: 0,
        duration: const Duration(minutes: 3),
        lessonCount: 1,
        publishedAt: DateTime.utc(2026),
        tags: const {},
        curriculumId: index == 0 ? 'fixture-cbse' : 'fixture-kerala',
        standardId: index == 0 ? 'fixture-10' : 'fixture-11',
        streamId: index == 0 ? null : 'fixture-science',
        subjectId: 'fixture-physics',
      ),
      description: 'Small academic fixture for profile-switch verification.',
      learningOutcomes: const [],
      prerequisites: const [],
      modules: [
        CourseModule(
          id: '$id-chapter',
          title: index == 0 ? 'Light' : 'Units and Measurements',
          position: 1,
          lessons: [
            Lesson(
              id: '$id-lesson',
              title: title,
              position: 1,
              estimatedDuration: const Duration(minutes: 3),
              content: ArticleLessonContent(documentId: '$id-note'),
              isPreview: true,
              hasContentItems: true,
              contentItems: [
                LessonContentItem(
                  id: '$id-note',
                  type: 'note',
                  title: title,
                  position: 1,
                  body: index == 0
                      ? 'The angle of incidence equals the angle of reflection. Both are measured from the normal.'
                      : 'The SI base unit of length is the metre. The SI base unit of time is the second.',
                ),
              ],
            ),
          ],
        ),
      ],
      updatedAt: DateTime.utc(2026),
    );
  }

  final List<CourseCategory> _categories;
  late final List<Course> _courses;
  late final Map<String, Course> _byId;
  final Set<String> _bookmarkedIds = {};
  final List<String> _recentlyViewedIds = [];

  @override
  Future<List<CourseCategory>> fetchCategories() async =>
      academicProfile?.call() == null
      ? List.unmodifiable(_categories)
      : const [
          CourseCategory(
            id: 'fixture-physics',
            name: 'Physics',
            iconName: 'school',
            isSubject: true,
          ),
        ];

  @override
  Future<Set<String>> fetchBookmarkedIds() async =>
      Set.unmodifiable(_bookmarkedIds);

  @override
  Future<void> setBookmarked(
    String courseId, {
    required bool bookmarked,
  }) async {
    if (!_byId.containsKey(courseId)) {
      throw const CatalogDataException(
        CatalogDataErrorKind.notFound,
        'Course not found.',
      );
    }
    bookmarked ? _bookmarkedIds.add(courseId) : _bookmarkedIds.remove(courseId);
  }

  @override
  Future<List<String>> fetchRecentlyViewedIds({required int limit}) async =>
      _recentlyViewedIds.take(limit).toList(growable: false);

  @override
  Future<void> recordRecentlyViewed(String courseId) async {
    if (!_byId.containsKey(courseId)) return;
    _recentlyViewedIds.remove(courseId);
    _recentlyViewedIds.insert(0, courseId);
    if (_recentlyViewedIds.length > 20) _recentlyViewedIds.removeLast();
  }

  @override
  Future<Course> fetchCourse(String courseId) async {
    for (final course in _visibleCourses) {
      if (course.summary.id == courseId) return course;
    }
    final course = _byId[courseId];
    if (course == null) {
      throw const CatalogDataException(
        CatalogDataErrorKind.notFound,
        'Course not found.',
      );
    }
    return course;
  }

  @override
  Future<List<CourseSummary>> fetchCoursesByIds(List<String> courseIds) async =>
      [
        for (final id in courseIds)
          for (final course in _visibleCourses)
            if (course.summary.id == id) course.summary,
      ];

  @override
  Future<CursorPage<CourseSummary>> fetchCourses(CatalogQuery query) async {
    final normalized = query.searchTerm.trim().toLowerCase();
    final filtered = _visibleCourses
        .where((course) {
          final summary = course.summary;
          final matchesSearch =
              normalized.isEmpty ||
              summary.title.toLowerCase().contains(normalized) ||
              summary.subtitle.toLowerCase().contains(normalized) ||
              summary.tags.any((tag) => tag.contains(normalized));
          final matchesCategory =
              query.categoryId == null ||
              summary.categoryIds.contains(query.categoryId);
          final matchesLevel =
              query.level == null || summary.level == query.level;
          return matchesSearch && matchesCategory && matchesLevel;
        })
        .toList(growable: false);

    switch (query.sort) {
      case CatalogSort.relevance:
        break;
      case CatalogSort.newest:
        filtered.sort(
          (a, b) => b.summary.publishedAt.compareTo(a.summary.publishedAt),
        );
      case CatalogSort.rating:
        filtered.sort((a, b) => b.summary.rating.compareTo(a.summary.rating));
      case CatalogSort.popularity:
        filtered.sort(
          (a, b) => b.summary.ratingCount.compareTo(a.summary.ratingCount),
        );
    }
    final offset = int.tryParse(query.cursor ?? '') ?? 0;
    final end = min(offset + query.pageSize, filtered.length);
    final items = offset >= filtered.length
        ? const <CourseSummary>[]
        : filtered
              .sublist(offset, end)
              .map((course) => course.summary)
              .toList(growable: false);
    return CursorPage(
      items: items,
      nextCursor: end < filtered.length ? '$end' : null,
      isFromCache: false,
    );
  }

  @override
  Future<HomeFeed> fetchHomeFeed() async {
    if (academicProfile?.call() != null) {
      return HomeFeed(
        sections: [
          HomeFeedSection(
            id: 'academic-subjects',
            kind: HomeSectionKind.recommended,
            title: 'Your subjects',
            content: CourseSectionContent(
              _visibleCourses.map((x) => x.summary).toList(),
            ),
          ),
        ],
        isFromCache: false,
        updatedAt: DateTime.now().toUtc(),
      );
    }
    final summaries = _courses
        .map((course) => course.summary)
        .toList(growable: false);
    return HomeFeed(
      sections: [
        HomeFeedSection(
          id: 'continue-learning',
          kind: HomeSectionKind.continueLearning,
          title: 'Continue Learning',
          content: CourseSectionContent(
            summaries
                .take(3)
                .map((course) => _withProgress(course))
                .toList(growable: false),
          ),
        ),
        HomeFeedSection(
          id: 'recommended',
          kind: HomeSectionKind.recommended,
          title: 'Recommended for You',
          content: CourseSectionContent(
            summaries.skip(3).take(8).toList(growable: false),
          ),
        ),
        HomeFeedSection(
          id: 'popular-categories',
          kind: HomeSectionKind.popularCategories,
          title: 'Popular Categories',
          content: CategorySectionContent(_categories),
        ),
        HomeFeedSection(
          id: 'trending',
          kind: HomeSectionKind.trending,
          title: 'Trending Now',
          content: CourseSectionContent(
            summaries.skip(11).take(8).toList(growable: false),
          ),
        ),
        HomeFeedSection(
          id: 'new-releases',
          kind: HomeSectionKind.newReleases,
          title: 'New Releases',
          content: CourseSectionContent(
            summaries.reversed.take(8).toList(growable: false),
          ),
        ),
        HomeFeedSection(
          id: 'recently-viewed',
          kind: HomeSectionKind.recentlyViewed,
          title: 'Recently Viewed',
          content: CourseSectionContent(
            summaries.skip(8).take(6).toList(growable: false),
          ),
        ),
        HomeFeedSection(
          id: 'because-learned',
          kind: HomeSectionKind.contextualRecommendation,
          title: 'Because You Learned Design Foundations',
          content: CourseSectionContent(
            summaries.skip(20).take(8).toList(growable: false),
          ),
        ),
      ],
      isFromCache: false,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  Course _createCourse(int index) {
    final category = _categories[index % _categories.length];
    final level = CourseLevel.values[index % CourseLevel.values.length];
    final summary = CourseSummary(
      id: 'course-${index + 1}',
      title: _titles[index % _titles.length],
      subtitle: 'Practical, project-based learning for modern professionals.',
      instructors: [
        Instructor(
          id: 'instructor-${index % 6}',
          name: _instructors[index % _instructors.length],
        ),
      ],
      categoryIds: {category.id},
      level: level,
      policy: index % 4 == 0
          ? const AccessPolicy.free()
          : const AccessPolicy.premium(),
      languageCode: 'en',
      rating: 4.2 + (index % 7) / 10,
      ratingCount: 120 + index * 43,
      duration: Duration(hours: 3 + index % 12),
      lessonCount: 14 + index % 20,
      publishedAt: DateTime.utc(2026, 1, 1).add(Duration(days: index * 5)),
      tags: {category.name.toLowerCase(), 'skills', 'project'},
    );
    return Course(
      summary: summary,
      description:
          'Build durable knowledge through concise explanations, guided practice, and an applied project.',
      learningOutcomes: const [
        'Apply core concepts to realistic scenarios',
        'Evaluate tradeoffs with a repeatable framework',
        'Complete a portfolio-ready project',
      ],
      prerequisites: const ['Curiosity and consistent practice'],
      modules: [_module(index, 1), _module(index, 2)],
      updatedAt: DateTime.utc(2026, 8, 1),
    );
  }

  CourseModule _module(int courseIndex, int position) => CourseModule(
    id: 'module-$courseIndex-$position',
    title: position == 1 ? 'Foundations' : 'Applied Practice',
    position: position,
    policy: courseIndex == 3 && position == 1
        ? const AccessPolicy.free()
        : null,
    lessons: position == 1
        ? [
            Lesson(
              id: 'lesson-$courseIndex-1',
              title: 'Welcome and roadmap',
              position: 1,
              estimatedDuration: const Duration(minutes: 8),
              content: VideoLessonContent(
                assetId: 'video-$courseIndex-1',
                transcriptAvailable: true,
              ),
              isPreview: true,
            ),
            Lesson(
              id: 'lesson-$courseIndex-2',
              title: 'Core concepts',
              position: 2,
              estimatedDuration: const Duration(minutes: 12),
              content: ArticleLessonContent(
                documentId: 'article-$courseIndex-2',
              ),
              isPreview: false,
            ),
            Lesson(
              id: 'lesson-$courseIndex-3',
              title: 'Reference guide',
              position: 3,
              estimatedDuration: const Duration(minutes: 5),
              content: ResourceLessonContent(
                resourceId: 'resource-$courseIndex-3',
                fileType: 'pdf',
              ),
              isPreview: false,
            ),
            Lesson(
              id: 'lesson-$courseIndex-4',
              title: 'Knowledge check',
              position: 4,
              estimatedDuration: const Duration(minutes: 10),
              content: QuizLessonContent(
                assessmentId: 'quiz-$courseIndex-4',
                questionCount: 8,
              ),
              isPreview: false,
            ),
          ]
        : [
            Lesson(
              id: 'lesson-$courseIndex-5',
              title: 'Practice assignment',
              position: 1,
              estimatedDuration: const Duration(minutes: 30),
              content: AssignmentLessonContent(
                assignmentId: 'assignment-$courseIndex-5',
              ),
              isPreview: false,
            ),
            Lesson(
              id: 'lesson-$courseIndex-6',
              title: 'Live workshop',
              position: 2,
              estimatedDuration: const Duration(hours: 1),
              content: LiveClassLessonContent(
                eventId: 'event-$courseIndex-6',
                startsAt: DateTime.utc(2026, 10, 15, 12),
              ),
              isPreview: false,
            ),
            Lesson(
              id: 'lesson-$courseIndex-7',
              title: 'Capstone project',
              position: 3,
              estimatedDuration: const Duration(hours: 2),
              content: ProjectLessonContent(
                projectId: 'project-$courseIndex-7',
                briefDocumentId: 'brief-$courseIndex-7',
              ),
              isPreview: false,
            ),
          ],
  );

  CourseSummary _withProgress(CourseSummary course) => CourseSummary(
    id: course.id,
    title: course.title,
    subtitle: course.subtitle,
    instructors: course.instructors,
    categoryIds: course.categoryIds,
    level: course.level,
    policy: course.policy,
    languageCode: course.languageCode,
    rating: course.rating,
    ratingCount: course.ratingCount,
    duration: course.duration,
    lessonCount: course.lessonCount,
    publishedAt: course.publishedAt,
    tags: course.tags,
    progress: 0.35,
  );

  static const _titles = [
    'Modern Application Development',
    'Design Systems in Practice',
    'Data Analysis Essentials',
    'Product Strategy Foundations',
    'Mindful Leadership',
    'Cloud Architecture Patterns',
    'User Research Methods',
    'Practical Business Analytics',
    'Responsible Artificial Intelligence',
  ];
  static const _instructors = [
    'Avery Morgan',
    'Jordan Lee',
    'Samira Patel',
    'Taylor Kim',
    'Noah Williams',
    'Maya Chen',
  ];
}
