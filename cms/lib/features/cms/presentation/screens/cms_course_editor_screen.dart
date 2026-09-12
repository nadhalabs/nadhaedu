import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nadha_cms/core/theme/app_breakpoints.dart';
import 'package:nadha_cms/features/cms/academic.dart';
import 'package:nadha_cms/features/cms/application/cms_course_editor_controller.dart';
import 'package:nadha_cms/features/cms/application/cms_providers.dart';
import 'package:nadha_cms/features/cms/content_items.dart';
import 'package:nadha_cms/features/cms/domain/cms_course_detail.dart';
import 'package:nadha_cms/features/cms/media/media_upload.dart';
import 'package:nadha_cms/features/cms/presentation/theme/cms_theme.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_badge.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_card.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_confirm_dialog.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_header.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_section_lesson_dialogs.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_state_views.dart';

class CmsCourseEditorScreen extends ConsumerStatefulWidget {
  const CmsCourseEditorScreen({
    super.key,
    required this.courseId,
    this.currentRoute,
  });

  final String courseId;
  final String? currentRoute;

  @override
  ConsumerState<CmsCourseEditorScreen> createState() =>
      _CmsCourseEditorScreenState();
}

class _CmsCourseEditorScreenState extends ConsumerState<CmsCourseEditorScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Metadata form controllers
  late final TextEditingController _titleController;
  late final TextEditingController _subtitleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _tagsController;
  late final TextEditingController _newOutcomeController;
  late final TextEditingController _newPrereqController;

  String _level = 'allLevels';
  Map<String, Object?> _academic = {};
  String _languageCode = 'en';
  String _policyKind = 'free';
  String _protectionPolicy = 'blockCaptureWhereSupported';
  String? _requiredTier;
  final List<String> _selectedCategoryIds = [];
  final List<String> _learningOutcomes = [];
  final List<String> _prerequisites = [];

  bool _isFormInitialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _titleController = TextEditingController();
    _subtitleController = TextEditingController();
    _descriptionController = TextEditingController();
    _tagsController = TextEditingController();
    _newOutcomeController = TextEditingController();
    _newPrereqController = TextEditingController();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _subtitleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    _newOutcomeController.dispose();
    _newPrereqController.dispose();
    super.dispose();
  }

  void _syncFormWithCourse(CmsCourseDetail course) {
    if (_isFormInitialized) return;
    _isFormInitialized = true;
    _titleController.text = course.title;
    _subtitleController.text = course.subtitle;
    _descriptionController.text = course.description;
    _tagsController.text = course.tags.join(', ');
    _level = course.level;
    _academic = Map.of(course.academic);
    _languageCode = course.languageCode;
    _policyKind = course.policyKind;
    _protectionPolicy = course.protectionPolicy;
    _requiredTier = course.requiredTier;
    _selectedCategoryIds
      ..clear()
      ..addAll(course.categories.map((c) => c.id));
    _learningOutcomes
      ..clear()
      ..addAll(course.learningOutcomes);
    _prerequisites
      ..clear()
      ..addAll(course.prerequisites);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cmsCourseEditorControllerProvider(widget.courseId));
    final notifier = ref.read(
      cmsCourseEditorControllerProvider(widget.courseId).notifier,
    );
    final route = widget.currentRoute ?? '/admin/courses/${widget.courseId}';
    final isMobile = MediaQuery.sizeOf(context).width < AppBreakpoints.medium;

    if (state.course != null) {
      _syncFormWithCourse(state.course!);
    }

    return Scaffold(
      backgroundColor: CmsTheme.canvasColor,
      body: Column(
        children: [
          CmsHeader(
            currentRoute: route,
            title: state.course == null || state.course?.id == 'new'
                ? 'Create New Course'
                : 'Edit: ${state.course!.title}',
            subtitle:
                'Course ID: ${widget.courseId} • Status: ${(state.course?.status ?? "draft").toUpperCase()}',
            showMenuButton: isMobile,
            onMenuTap: () => Scaffold.of(context).openDrawer(),
            actions: [
              OutlinedButton.icon(
                onPressed: () => context.go('/admin/courses'),
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Back to Catalog'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: CmsTheme.textSecondary,
                  side: const BorderSide(color: CmsTheme.borderColor),
                ),
              ),
              const SizedBox(width: 8),
              if (state.course != null && state.course!.id != 'new') ...[
                if (state.course!.isPublished)
                  OutlinedButton.icon(
                    onPressed: state.isSaving
                        ? null
                        : () async {
                            final reason = await CmsConfirmDialog.show(
                              context,
                              title: 'Unpublish Course',
                              message:
                                  'Are you sure you want to unpublish this course? It will immediately become inaccessible to students who have not enrolled.',
                              confirmLabel: 'Unpublish to Draft',
                              requireReason: true,
                            );
                            if (reason != null) {
                              await notifier.unpublish(reason: reason);
                            }
                          },
                    icon: const Icon(Icons.unpublished, size: 16),
                    label: const Text('Unpublish'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: CmsTheme.warningColor,
                      side: const BorderSide(color: CmsTheme.warningColor),
                    ),
                  )
                else
                  FilledButton.icon(
                    onPressed: state.isSaving
                        ? null
                        : () async {
                            final reason = await CmsConfirmDialog.show(
                              context,
                              title: 'Publish Course',
                              message:
                                  'Publishing this course will validate all chapters, lessons, and assessments before making it publicly accessible.',
                              confirmLabel: 'Publish Now',
                              requireReason: false,
                            );
                            if (reason != null) {
                              await notifier.publish(reason: reason);
                            }
                          },
                    icon: const Icon(Icons.publish, size: 16),
                    label: const Text('Publish Course'),
                    style: FilledButton.styleFrom(
                      backgroundColor: CmsTheme.successColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                const SizedBox(width: 8),
              ],
              FilledButton.icon(
                onPressed: state.isSaving ? null : _saveCourseMetadata,
                icon: state.isSaving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save, size: 16),
                label: const Text('Save Details'),
                style: FilledButton.styleFrom(
                  backgroundColor: CmsTheme.primaryAccent,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),

          // Messages
          if (state.errorMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              color: CmsTheme.dangerBg,
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 16,
                    color: CmsTheme.dangerText,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.errorMessage!,
                      style: const TextStyle(
                        color: CmsTheme.dangerText,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (state.successMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              color: CmsTheme.successBg,
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    size: 16,
                    color: CmsTheme.successText,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.successMessage!,
                      style: const TextStyle(
                        color: CmsTheme.successText,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Tab Bar
          Container(
            color: CmsTheme.surfaceColor,
            child: TabBar(
              controller: _tabController,
              indicatorColor: CmsTheme.primaryAccent,
              indicatorWeight: 3,
              labelColor: CmsTheme.primaryAccent,
              unselectedLabelColor: CmsTheme.textSecondary,
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              tabs: [
                const Tab(
                  icon: Icon(Icons.info_outline, size: 16),
                  text: 'General Metadata',
                ),
                Tab(
                  icon: const Icon(Icons.view_timeline, size: 16),
                  text:
                      'Curriculum (${state.course?.modules.length ?? 0} Chapters)',
                ),
                Tab(
                  icon: const Icon(Icons.quiz_outlined, size: 16),
                  text:
                      'Assessments (${state.course?.assessments.length ?? 0})',
                ),
                Tab(
                  icon: Icon(
                    state.course?.validation.canPublish == true
                        ? Icons.check_circle_outline
                        : Icons.warning_amber_rounded,
                    size: 16,
                    color: state.course?.validation.canPublish == true
                        ? CmsTheme.successColor
                        : CmsTheme.warningColor,
                  ),
                  text: 'Validation & Publishing',
                ),
              ],
            ),
          ),

          // Tab Views
          Expanded(
            child: state.isLoading && state.course == null
                ? const CmsLoadingView(message: 'Loading course structure...')
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildMetadataTab(state),
                      _buildCurriculumTab(state, notifier),
                      _buildAssessmentsTab(state),
                      _buildPublishingTab(state, notifier),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveCourseMetadata() async {
    final tags = _tagsController.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final success = await ref
        .read(cmsCourseEditorControllerProvider(widget.courseId).notifier)
        .saveMetadata(
          academic: _academic,
          title: _titleController.text,
          subtitle: _subtitleController.text,
          description: _descriptionController.text,
          level: _level,
          languageCode: _languageCode,
          policyKind: _policyKind,
          protectionPolicy: _protectionPolicy,
          requiredTier: _requiredTier,
          categoryIds: _selectedCategoryIds,
          tags: tags,
          learningOutcomes: _learningOutcomes,
          prerequisites: _prerequisites,
        );

    if (success && widget.courseId == 'new') {
      final newCourse = ref
          .read(cmsCourseEditorControllerProvider(widget.courseId))
          .course;
      if (newCourse != null && newCourse.id != 'new' && mounted) {
        context.go('/admin/courses/${newCourse.id}');
      }
    }
  }

  // --- TAB 1: METADATA ---

  Widget _buildMetadataTab(CmsCourseEditorState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.courseId != 'new')
            ref
                .watch(
                  contentEditorDataProvider('admin/courses/${widget.courseId}'),
                )
                .when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) =>
                      MediaUpload(courseId: widget.courseId, onReady: (_) {}),
                  data: (data) => MediaUpload(
                    courseId: widget.courseId,
                    posterUrl: data['coverReference'] as String?,
                    onReady: (_) => ref.invalidate(
                      contentEditorDataProvider(
                        'admin/courses/${widget.courseId}',
                      ),
                    ),
                  ),
                ),
          CmsCard(
            title: 'Basic Course Information',
            subtitle:
                'Core identification, summary, and metadata for learner discovery',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Academic subject offering (leave all empty for legacy content)',
                ),
                AcademicSelectors(
                  value: _academic,
                  onChanged: (value) => setState(() => _academic = value),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Course Title *',
                  style: TextStyle(
                    color: CmsTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _titleController,
                  style: const TextStyle(
                    color: CmsTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'e.g. Advanced Flutter Architecture',
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Subtitle / Hook',
                  style: TextStyle(
                    color: CmsTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _subtitleController,
                  style: const TextStyle(
                    color: CmsTheme.textPrimary,
                    fontSize: 13,
                  ),
                  decoration: const InputDecoration(
                    hintText:
                        'A concise one-line summary of what learners will accomplish',
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Description *',
                  style: TextStyle(
                    color: CmsTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _descriptionController,
                  maxLines: 4,
                  style: const TextStyle(
                    color: CmsTheme.textPrimary,
                    fontSize: 13,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Full comprehensive course overview...',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Classification & Access Policy
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: CmsCard(
                  title: 'Subject & Categories',
                  subtitle: 'Assign to subject catalogs',
                  child: state.categories.isEmpty
                      ? const Text(
                          'No categories configured.',
                          style: TextStyle(
                            color: CmsTheme.textMuted,
                            fontSize: 12,
                          ),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: state.categories.map((cat) {
                            final isSelected = _selectedCategoryIds.contains(
                              cat.id,
                            );
                            return FilterChip(
                              label: Text(cat.name),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedCategoryIds.add(cat.id);
                                  } else {
                                    _selectedCategoryIds.remove(cat.id);
                                  }
                                });
                              },
                              selectedColor: CmsTheme.primaryAccent.withValues(
                                alpha: 0.25,
                              ),
                              backgroundColor: CmsTheme.cardColor,
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? CmsTheme.primaryAccent
                                    : CmsTheme.textSecondary,
                                fontSize: 12,
                              ),
                            );
                          }).toList(),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: CmsCard(
                  title: 'Level & Access Policy',
                  subtitle: 'Monetization and protection configuration',
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _level,
                        isExpanded: true,
                        dropdownColor: CmsTheme.cardColor,
                        style: const TextStyle(
                          color: CmsTheme.textPrimary,
                          fontSize: 13,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Target Level',
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'beginner',
                            child: Text('Beginner'),
                          ),
                          DropdownMenuItem(
                            value: 'intermediate',
                            child: Text('Intermediate'),
                          ),
                          DropdownMenuItem(
                            value: 'advanced',
                            child: Text('Advanced'),
                          ),
                          DropdownMenuItem(
                            value: 'allLevels',
                            child: Text('All Levels'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _level = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _policyKind,
                        isExpanded: true,
                        dropdownColor: CmsTheme.cardColor,
                        style: const TextStyle(
                          color: CmsTheme.textPrimary,
                          fontSize: 13,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Pricing / Access Policy',
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'free',
                            child: Text('Free (Open Access)'),
                          ),
                          DropdownMenuItem(
                            value: 'premium',
                            child: Text('Premium (Individual Purchase)'),
                          ),
                          DropdownMenuItem(
                            value: 'tier_subscription',
                            child: Text('Subscription Tier'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _policyKind = val);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Learning Outcomes & Prerequisites
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: CmsCard(
                  title: 'Learning Outcomes',
                  subtitle: 'What students will learn',
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _newOutcomeController,
                              style: const TextStyle(
                                color: CmsTheme.textPrimary,
                                fontSize: 12,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Add outcome item...',
                                isDense: true,
                              ),
                              onSubmitted: (val) {
                                if (val.trim().isNotEmpty) {
                                  setState(() {
                                    _learningOutcomes.add(val.trim());
                                    _newOutcomeController.clear();
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(
                              Icons.add_circle,
                              color: CmsTheme.primaryAccent,
                            ),
                            onPressed: () {
                              final text = _newOutcomeController.text.trim();
                              if (text.isNotEmpty) {
                                setState(() {
                                  _learningOutcomes.add(text);
                                  _newOutcomeController.clear();
                                });
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (var i = 0; i < _learningOutcomes.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check,
                                size: 14,
                                color: CmsTheme.successText,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _learningOutcomes[i],
                                  style: const TextStyle(
                                    color: CmsTheme.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  size: 14,
                                  color: CmsTheme.textMuted,
                                ),
                                onPressed: () => setState(
                                  () => _learningOutcomes.removeAt(i),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: CmsCard(
                  title: 'Prerequisites',
                  subtitle: 'Required prior knowledge',
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _newPrereqController,
                              style: const TextStyle(
                                color: CmsTheme.textPrimary,
                                fontSize: 12,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Add prerequisite item...',
                                isDense: true,
                              ),
                              onSubmitted: (val) {
                                if (val.trim().isNotEmpty) {
                                  setState(() {
                                    _prerequisites.add(val.trim());
                                    _newPrereqController.clear();
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(
                              Icons.add_circle,
                              color: CmsTheme.primaryAccent,
                            ),
                            onPressed: () {
                              final text = _newPrereqController.text.trim();
                              if (text.isNotEmpty) {
                                setState(() {
                                  _prerequisites.add(text);
                                  _newPrereqController.clear();
                                });
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (var i = 0; i < _prerequisites.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.arrow_right,
                                size: 16,
                                color: CmsTheme.infoText,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _prerequisites[i],
                                  style: const TextStyle(
                                    color: CmsTheme.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  size: 14,
                                  color: CmsTheme.textMuted,
                                ),
                                onPressed: () =>
                                    setState(() => _prerequisites.removeAt(i)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- TAB 2: CURRICULUM BUILDER ---

  Widget _buildCurriculumTab(
    CmsCourseEditorState state,
    CmsCourseEditorController notifier,
  ) {
    final course = state.course;
    if (course == null || course.id == 'new') {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Text(
            'Save course metadata first before building chapters.',
            style: TextStyle(color: CmsTheme.textMuted, fontSize: 13),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Curriculum Structure',
                      style: TextStyle(
                        color: CmsTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${course.modules.length} chapters • ${course.totalLessons} total lessons • ${course.durationSeconds ~/ 60} minutes estimated',
                      style: const TextStyle(
                        color: CmsTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () async {
                  final data = await CmsSectionDialog.show(context);
                  if (data != null) {
                    await notifier.addModule(
                      data['title']!,
                      policyKind: data['policyKind'] ?? 'inherit',
                    );
                  }
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Chapter'),
                style: FilledButton.styleFrom(
                  backgroundColor: CmsTheme.primaryAccent,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (course.modules.isEmpty)
            CmsCard(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.layers_outlined,
                        size: 48,
                        color: CmsTheme.textMuted,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No Chapters Created Yet',
                        style: TextStyle(
                          color: CmsTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Subject offerings require at least one chapter with lessons before publishing.',
                        style: TextStyle(
                          color: CmsTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () async {
                          final data = await CmsSectionDialog.show(context);
                          if (data != null) {
                            await notifier.addModule(
                              data['title']!,
                              policyKind: data['policyKind'] ?? 'inherit',
                            );
                          }
                        },
                        child: const Text('Create First Chapter'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: course.modules.length,
              onReorder: (oldIdx, newIdx) =>
                  notifier.reorderModules(oldIdx, newIdx),
              itemBuilder: (context, mIdx) {
                final module = course.modules[mIdx];
                return _buildModuleCard(context, notifier, module, mIdx);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildModuleCard(
    BuildContext context,
    CmsCourseEditorController notifier,
    CmsModuleDetail module,
    int mIdx,
  ) {
    return Container(
      key: ValueKey(module.id),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: CmsTheme.surfaceColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CmsTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: CmsTheme.cardColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(10),
              ),
              border: Border(
                bottom: BorderSide(
                  color: CmsTheme.borderColor.withValues(alpha: 0.6),
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.drag_indicator,
                  size: 18,
                  color: CmsTheme.textMuted,
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: CmsTheme.primaryAccent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Chapter ${mIdx + 1}',
                    style: const TextStyle(
                      color: CmsTheme.primaryAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    module.title,
                    style: const TextStyle(
                      color: CmsTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${module.lessons.length} lessons • ${module.totalDurationSeconds ~/ 60}m',
                  style: const TextStyle(
                    color: CmsTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(
                    Icons.add,
                    size: 18,
                    color: CmsTheme.primaryAccent,
                  ),
                  tooltip: 'Add Lesson',
                  onPressed: () async {
                    final data = await CmsLessonDialog.show(context);
                    if (data != null) {
                      await notifier.addLesson(module.id, data);
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: CmsTheme.textMuted,
                  ),
                  tooltip: 'Edit Chapter Title',
                  onPressed: () async {
                    final data = await CmsSectionDialog.show(
                      context,
                      initialModule: module,
                    );
                    if (data != null) {
                      await notifier.updateModule(
                        module.id,
                        title: data['title'],
                        policyKind: data['policyKind'],
                      );
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 16,
                    color: CmsTheme.dangerText,
                  ),
                  tooltip: 'Delete Chapter',
                  onPressed: () async {
                    final confirm = await CmsConfirmDialog.show(
                      context,
                      title: 'Delete Chapter',
                      message:
                          'Delete chapter "${module.title}" and its ${module.lessons.length} lessons? The server blocks deletion when learner history exists.',
                      confirmLabel: 'Delete Chapter',
                    );
                    if (confirm != null) {
                      await notifier.deleteModule(module.id);
                    }
                  },
                ),
              ],
            ),
          ),

          // Lessons list
          if (module.lessons.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'No lessons in this chapter. Click + to create a lesson, then add content items.',
                  style: TextStyle(color: CmsTheme.textMuted, fontSize: 12),
                ),
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: module.lessons.length,
              onReorder: (oldIdx, newIdx) =>
                  notifier.reorderLessons(module.id, oldIdx, newIdx),
              itemBuilder: (context, lIdx) {
                final lesson = module.lessons[lIdx];
                return Container(
                  key: ValueKey(lesson.id),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: lIdx == module.lessons.length - 1
                            ? Colors.transparent
                            : CmsTheme.borderColor.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.drag_handle,
                        size: 16,
                        color: CmsTheme.textMuted,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${mIdx + 1}.${lIdx + 1}',
                        style: const TextStyle(
                          color: CmsTheme.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        lesson.contentType == 'video'
                            ? Icons.play_circle_outline
                            : Icons.article_outlined,
                        size: 16,
                        color: CmsTheme.primaryAccent,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lesson.title,
                              style: const TextStyle(
                                color: CmsTheme.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              'Ref: ${lesson.contentRef}',
                              style: const TextStyle(
                                color: CmsTheme.textMuted,
                                fontSize: 11,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push(
                          '/admin/courses/${widget.courseId}/lessons/${lesson.id}/content',
                        ),
                        child: const Text('Content items'),
                      ),
                      if (lesson.isPreview) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: CmsTheme.successBg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'PREVIEW',
                            style: TextStyle(
                              color: CmsTheme.successText,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: CmsTheme.cardColor,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: CmsTheme.borderColor),
                        ),
                        child: Text(
                          lesson.formattedDuration,
                          style: const TextStyle(
                            color: CmsTheme.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        icon: const Icon(
                          Icons.edit_outlined,
                          size: 15,
                          color: CmsTheme.textMuted,
                        ),
                        onPressed: () async {
                          final data = await CmsLessonDialog.show(
                            context,
                            initialLesson: lesson,
                          );
                          if (data != null) {
                            await notifier.updateLesson(
                              module.id,
                              lesson.id,
                              data,
                            );
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 15,
                          color: CmsTheme.dangerText,
                        ),
                        onPressed: () async {
                          final confirm = await CmsConfirmDialog.show(
                            context,
                            title: 'Delete Lesson',
                            message:
                                'Are you sure you want to remove lesson "${lesson.title}"?',
                            confirmLabel: 'Delete Lesson',
                          );
                          if (confirm != null) {
                            await notifier.deleteLesson(module.id, lesson.id);
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // --- TAB 3: ASSESSMENTS ---

  Widget _buildAssessmentsTab(CmsCourseEditorState state) {
    final course = state.course;
    if (course == null || course.id == 'new') {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Text(
            'Save course metadata first before adding assessments.',
            style: TextStyle(color: CmsTheme.textMuted, fontSize: 13),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Assessments & Quizzes',
                    style: TextStyle(
                      color: CmsTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Knowledge evaluations, pass criteria, and certificate eligibility gates',
                    style: TextStyle(
                      color: CmsTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              FilledButton.icon(
                onPressed: () {
                  context.go('/admin/assessments/new?courseId=${course.id}');
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Create Assessment'),
                style: FilledButton.styleFrom(
                  backgroundColor: CmsTheme.primaryAccent,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (course.assessments.isEmpty)
            CmsCard(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.quiz_outlined,
                        size: 48,
                        color: CmsTheme.textMuted,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No Quizzes / Assessments Attached',
                        style: TextStyle(
                          color: CmsTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Assessments test student mastery and serve as certification requirements.',
                        style: TextStyle(
                          color: CmsTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => context.go(
                          '/admin/assessments/new?courseId=${course.id}',
                        ),
                        child: const Text('Create New Assessment'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            for (final ass in course.assessments)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CmsTheme.cardColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: CmsTheme.borderColor),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.assignment_turned_in,
                      size: 24,
                      color: CmsTheme.primaryAccent,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ass.title,
                            style: const TextStyle(
                              color: CmsTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (ass.description.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              ass.description,
                              style: const TextStyle(
                                color: CmsTheme.textSecondary,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              CmsBadge(
                                label: 'Pass Score: ${ass.passingPercentage}%',
                                type: CmsBadgeType.info,
                              ),
                              const SizedBox(width: 8),
                              CmsBadge(
                                label: '${ass.questionCount} Questions',
                                type: CmsBadgeType.neutral,
                              ),
                              if (ass.requiredForCertificate) ...[
                                const SizedBox(width: 8),
                                const CmsBadge(
                                  label: 'Certificate Gate',
                                  type: CmsBadgeType.warning,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () {
                        context.go(
                          '/admin/assessments/${ass.id}?courseId=${course.id}',
                        );
                      },
                      icon: const Icon(Icons.edit, size: 14),
                      label: const Text('Edit Questions & Keys'),
                      style: FilledButton.styleFrom(
                        backgroundColor: CmsTheme.primaryAccent.withValues(
                          alpha: 0.2,
                        ),
                        foregroundColor: CmsTheme.primaryAccent,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  // --- TAB 4: VALIDATION & PUBLISHING ---

  Widget _buildPublishingTab(
    CmsCourseEditorState state,
    CmsCourseEditorController notifier,
  ) {
    final course = state.course;
    if (course == null || course.id == 'new') {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Text(
            'Save course metadata first to view publishing validation.',
            style: TextStyle(color: CmsTheme.textMuted, fontSize: 13),
          ),
        ),
      );
    }

    final validation = course.validation;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Readiness Banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: validation.canPublish
                  ? CmsTheme.successBg
                  : CmsTheme.dangerBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: validation.canPublish
                    ? CmsTheme.successColor
                    : CmsTheme.dangerColor,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  validation.canPublish
                      ? Icons.check_circle_outline
                      : Icons.error_outline,
                  size: 32,
                  color: validation.canPublish
                      ? CmsTheme.successText
                      : CmsTheme.dangerText,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        validation.canPublish
                            ? 'Course is Complete & Ready for Publishing'
                            : 'Publishing Blocked: ${validation.errors.length} Criteria Missing',
                        style: TextStyle(
                          color: validation.canPublish
                              ? CmsTheme.successText
                              : CmsTheme.dangerText,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        validation.canPublish
                            ? 'All required chapters, lessons, content references, and assessment checks have passed server validation.'
                            : 'Resolve all errors below before attempting to publish this course.',
                        style: TextStyle(
                          color: validation.canPublish
                              ? CmsTheme.successText
                              : CmsTheme.dangerText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Validation Breakdown Card
          CmsCard(
            title: 'Authoritative Server Validation Report',
            subtitle:
                'Rule verification against content model integrity constraints',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (validation.errors.isEmpty && validation.warnings.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 18,
                          color: CmsTheme.successColor,
                        ),
                        SizedBox(width: 10),
                        Text(
                          '100% of publishing criteria satisfied.',
                          style: TextStyle(
                            color: CmsTheme.successText,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                if (validation.errors.isNotEmpty) ...[
                  const Text(
                    'BLOCKING ERRORS (Must be resolved)',
                    style: TextStyle(
                      color: CmsTheme.dangerText,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final err in validation.errors)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.cancel,
                            size: 16,
                            color: CmsTheme.dangerText,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  err.message,
                                  style: const TextStyle(
                                    color: CmsTheme.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  'Code: ${err.code}${err.field != null ? " • Field: ${err.field}" : ""}',
                                  style: const TextStyle(
                                    color: CmsTheme.textMuted,
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                ],

                if (validation.warnings.isNotEmpty) ...[
                  const Text(
                    'WARNINGS / RECOMMENDATIONS',
                    style: TextStyle(
                      color: CmsTheme.warningColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final w in validation.warnings)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.warning_amber,
                            size: 16,
                            color: CmsTheme.warningColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              w.message,
                              style: const TextStyle(
                                color: CmsTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Danger Zone Card
          CmsCard(
            title: 'Danger Zone',
            subtitle: 'Irreversible content management operations',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delete this Course',
                      style: TextStyle(
                        color: CmsTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Deletes all associated modules, lessons, and assessment links.',
                      style: TextStyle(color: CmsTheme.textMuted, fontSize: 11),
                    ),
                  ],
                ),
                FilledButton.icon(
                  onPressed: () async {
                    final reason = await CmsConfirmDialog.show(
                      context,
                      title: 'Delete Entire Course',
                      message:
                          'Are you sure you want to permanently delete "${course.title}"? This cannot be undone.',
                      confirmLabel: 'Delete Course Permanently',
                      requireReason: true,
                    );
                    if (reason != null) {
                      final success = await notifier.deleteCourse(
                        reason: reason,
                      );
                      if (success && mounted) {
                        await ref
                            .read(cmsCoursesControllerProvider.notifier)
                            .load();
                        if (!mounted) return;
                        context.go('/admin/courses');
                      }
                    }
                  },
                  icon: const Icon(Icons.delete_forever, size: 16),
                  label: const Text('Delete Course'),
                  style: FilledButton.styleFrom(
                    backgroundColor: CmsTheme.dangerColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
