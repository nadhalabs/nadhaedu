import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nadha_cms/core/theme/app_breakpoints.dart';
import 'package:nadha_cms/features/cms/application/cms_assessment_editor_controller.dart';
import 'package:nadha_cms/features/cms/application/cms_providers.dart';
import 'package:nadha_cms/features/cms/domain/cms_assessment.dart';
import 'package:nadha_cms/features/cms/presentation/theme/cms_theme.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_badge.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_card.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_confirm_dialog.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_header.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_section_lesson_dialogs.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_state_views.dart';

class CmsAssessmentEditorScreen extends ConsumerStatefulWidget {
  const CmsAssessmentEditorScreen({
    super.key,
    required this.assessmentId,
    this.courseId,
    this.currentRoute,
  });

  final String assessmentId;
  final String? courseId;
  final String? currentRoute;

  @override
  ConsumerState<CmsAssessmentEditorScreen> createState() =>
      _CmsAssessmentEditorScreenState();
}

class _CmsAssessmentEditorScreenState
    extends ConsumerState<CmsAssessmentEditorScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _passPercentController;
  late final TextEditingController _timeLimitController;
  late final TextEditingController _maxAttemptsController;

  bool _requiredForCertificate = true;
  String _status = 'draft';
  bool _isFormInitialized = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _passPercentController = TextEditingController(text: '70');
    _timeLimitController = TextEditingController(text: '30');
    _maxAttemptsController = TextEditingController(text: '3');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _passPercentController.dispose();
    _timeLimitController.dispose();
    _maxAttemptsController.dispose();
    super.dispose();
  }

  void _syncForm(CmsAssessmentDetail a) {
    if (_isFormInitialized) return;
    _isFormInitialized = true;
    _titleController.text = a.title;
    _descriptionController.text = a.description;
    _passPercentController.text = '${a.passingPercentage}';
    _timeLimitController.text = a.timeLimitSeconds != null
        ? '${a.timeLimitSeconds! ~/ 60}'
        : '';
    _maxAttemptsController.text = '${a.maxAttempts}';
    _requiredForCertificate = a.requiredForCertificate;
    _status = a.status;
  }

  @override
  Widget build(BuildContext context) {
    final params = (
      assessmentId: widget.assessmentId,
      courseId: widget.courseId,
    );
    final state = ref.watch(cmsAssessmentEditorControllerProvider(params));
    final notifier = ref.read(
      cmsAssessmentEditorControllerProvider(params).notifier,
    );
    final route =
        widget.currentRoute ?? '/admin/assessments/${widget.assessmentId}';
    final isMobile = MediaQuery.sizeOf(context).width < AppBreakpoints.medium;

    if (state.assessment != null) {
      _syncForm(state.assessment!);
    }

    final targetCourseId = state.assessment?.courseId.isNotEmpty == true
        ? state.assessment!.courseId
        : (widget.courseId ?? '');

    return Scaffold(
      backgroundColor: CmsTheme.canvasColor,
      body: Column(
        children: [
          CmsHeader(
            currentRoute: route,
            title: state.assessment == null || state.assessment?.id == 'new'
                ? 'Create New Assessment'
                : 'Quiz Builder: ${state.assessment!.title}',
            subtitle:
                'Assessment ID: ${widget.assessmentId} • Total Points: ${state.assessment?.totalPoints ?? 0}',
            showMenuButton: isMobile,
            onMenuTap: () => Scaffold.of(context).openDrawer(),
            actions: [
              OutlinedButton.icon(
                onPressed: () {
                  if (targetCourseId.isNotEmpty) {
                    context.go('/admin/courses/$targetCourseId');
                  } else {
                    context.go('/admin/courses');
                  }
                },
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Back to Course'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: CmsTheme.textSecondary,
                  side: const BorderSide(color: CmsTheme.borderColor),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: state.isSaving ? null : _saveAssessmentSettings,
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
                label: const Text('Save Settings'),
                style: FilledButton.styleFrom(
                  backgroundColor: CmsTheme.primaryAccent,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),

          // Feedback alerts
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

          Expanded(
            child: state.isLoading && state.assessment == null
                ? const CmsLoadingView(
                    message: 'Loading assessment questions...',
                  )
                : _buildEditorContent(context, state, notifier),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAssessmentSettings() async {
    final passPct = int.tryParse(_passPercentController.text.trim()) ?? 70;
    final timeMins = int.tryParse(_timeLimitController.text.trim());
    final maxAtt = int.tryParse(_maxAttemptsController.text.trim()) ?? 3;

    final params = (
      assessmentId: widget.assessmentId,
      courseId: widget.courseId,
    );
    final success = await ref
        .read(cmsAssessmentEditorControllerProvider(params).notifier)
        .saveAssessment(
          title: _titleController.text,
          description: _descriptionController.text,
          instructions: const [],
          passingPercentage: passPct,
          timeLimitSeconds: timeMins != null ? timeMins * 60 : null,
          maxAttempts: maxAtt,
          requiredForCertificate: _requiredForCertificate,
          protectionPolicy: 'blockCaptureWhereSupported',
          status: _status,
        );

    if (success && widget.assessmentId == 'new') {
      final newAss = ref
          .read(cmsAssessmentEditorControllerProvider(params))
          .assessment;
      if (newAss != null && newAss.id != 'new' && mounted) {
        context.go(
          '/admin/assessments/${newAss.id}?courseId=${newAss.courseId}',
        );
      }
    }
  }

  Widget _buildEditorContent(
    BuildContext context,
    CmsAssessmentEditorState state,
    CmsAssessmentEditorController notifier,
  ) {
    final a = state.assessment;
    if (a == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Assessment Settings Card
          CmsCard(
            title: 'Assessment Configuration & Pass Criteria',
            subtitle:
                'Passing threshold, attempt quotas, and certificate requirements',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Quiz Title *',
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
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'e.g. Flutter Architecture Final Exam',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Passing Score % *',
                            style: TextStyle(
                              color: CmsTheme.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _passPercentController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(
                              color: CmsTheme.textPrimary,
                              fontSize: 13,
                            ),
                            decoration: const InputDecoration(hintText: '75'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Time Limit (Mins)',
                            style: TextStyle(
                              color: CmsTheme.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _timeLimitController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(
                              color: CmsTheme.textPrimary,
                              fontSize: 13,
                            ),
                            decoration: const InputDecoration(hintText: '30'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Max Attempts',
                            style: TextStyle(
                              color: CmsTheme.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _maxAttemptsController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(
                              color: CmsTheme.textPrimary,
                              fontSize: 13,
                            ),
                            decoration: const InputDecoration(hintText: '3'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: CheckboxListTile(
                        title: const Text(
                          'Required for Course Certificate Eligibility',
                          style: TextStyle(
                            color: CmsTheme.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: const Text(
                          'Students must achieve passing score to earn verified certificate',
                          style: TextStyle(
                            color: CmsTheme.textMuted,
                            fontSize: 11,
                          ),
                        ),
                        value: _requiredForCertificate,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        activeColor: CmsTheme.primaryAccent,
                        onChanged: (val) => setState(
                          () => _requiredForCertificate = val ?? true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 200,
                      child: DropdownButtonFormField<String>(
                        initialValue: _status,
                        dropdownColor: CmsTheme.cardColor,
                        style: const TextStyle(
                          color: CmsTheme.textPrimary,
                          fontSize: 13,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Lifecycle Status',
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'draft',
                            child: Text('Draft (Hidden)'),
                          ),
                          DropdownMenuItem(
                            value: 'published',
                            child: Text('Published (Live)'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _status = val);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Questions List Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Assessment Questions',
                    style: TextStyle(
                      color: CmsTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${a.questions.length} questions • ${a.totalPoints} total points',
                    style: const TextStyle(
                      color: CmsTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              FilledButton.icon(
                onPressed: () async {
                  final data = await CmsQuestionDialog.show(context);
                  if (data != null) {
                    await notifier.addQuestion(data);
                  }
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Question'),
                style: FilledButton.styleFrom(
                  backgroundColor: CmsTheme.primaryAccent,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (a.questions.isEmpty)
            CmsCard(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.help_outline,
                        size: 48,
                        color: CmsTheme.textMuted,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No Questions in Assessment',
                        style: TextStyle(
                          color: CmsTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Click "Add Question" to create single-choice, multiple-choice, or true/false questions.',
                        style: TextStyle(
                          color: CmsTheme.textMuted,
                          fontSize: 12,
                        ),
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
              itemCount: a.questions.length,
              onReorder: (oldIdx, newIdx) =>
                  notifier.reorderQuestions(oldIdx, newIdx),
              itemBuilder: (context, qIdx) {
                final q = a.questions[qIdx];
                return _buildQuestionCard(context, notifier, q, qIdx);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(
    BuildContext context,
    CmsAssessmentEditorController notifier,
    CmsQuestionDetail q,
    int qIdx,
  ) {
    final correctOptId = q.gradingData['correctOptionId'] as String?;
    final correctTf = q.gradingData['correctValue'] as bool?;

    return Container(
      key: ValueKey(q.id),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: CmsTheme.cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CmsTheme.borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.drag_indicator,
                  size: 18,
                  color: CmsTheme.textMuted,
                ),
                const SizedBox(width: 8),
                Text(
                  'Q${qIdx + 1}',
                  style: const TextStyle(
                    color: CmsTheme.primaryAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 10),
                CmsBadge(
                  label: q.type == 'singleChoice'
                      ? 'Single Choice'
                      : q.type == 'multipleChoice'
                      ? 'Multiple Choice'
                      : 'True / False',
                  type: CmsBadgeType.info,
                ),
                const SizedBox(width: 8),
                CmsBadge(
                  label: '${q.points} pt${q.points > 1 ? "s" : ""}',
                  type: CmsBadgeType.neutral,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: CmsTheme.textMuted,
                  ),
                  tooltip: 'Edit Question',
                  onPressed: () async {
                    final data = await CmsQuestionDialog.show(
                      context,
                      initialQuestion: q,
                    );
                    if (data != null) {
                      await notifier.updateQuestion(q.id, data);
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 16,
                    color: CmsTheme.dangerText,
                  ),
                  tooltip: 'Delete Question',
                  onPressed: () async {
                    final confirm = await CmsConfirmDialog.show(
                      context,
                      title: 'Delete Question',
                      message:
                          'Are you sure you want to remove question Q${qIdx + 1}?',
                      confirmLabel: 'Delete Question',
                    );
                    if (confirm != null) {
                      await notifier.deleteQuestion(q.id);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Prompt
            Text(
              q.prompt,
              style: const TextStyle(
                color: CmsTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            // Options & Grading Key
            if (q.type == 'trueFalse') ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: correctTf == true
                          ? CmsTheme.successBg
                          : CmsTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: correctTf == true
                            ? CmsTheme.successColor
                            : CmsTheme.borderColor,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (correctTf == true) ...[
                          const Icon(
                            Icons.check,
                            size: 14,
                            color: CmsTheme.successText,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          'TRUE',
                          style: TextStyle(
                            color: correctTf == true
                                ? CmsTheme.successText
                                : CmsTheme.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: correctTf == false
                          ? CmsTheme.successBg
                          : CmsTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: correctTf == false
                            ? CmsTheme.successColor
                            : CmsTheme.borderColor,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (correctTf == false) ...[
                          const Icon(
                            Icons.check,
                            size: 14,
                            color: CmsTheme.successText,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          'FALSE',
                          style: TextStyle(
                            color: correctTf == false
                                ? CmsTheme.successText
                                : CmsTheme.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ] else ...[
              for (final opt in q.options) ...[
                Builder(
                  builder: (context) {
                    final isCorrect = opt.id == correctOptId;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isCorrect
                            ? CmsTheme.successBg
                            : CmsTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isCorrect
                              ? CmsTheme.successColor
                              : CmsTheme.borderColor,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isCorrect
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            size: 16,
                            color: isCorrect
                                ? CmsTheme.successColor
                                : CmsTheme.textMuted,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              opt.text,
                              style: TextStyle(
                                color: isCorrect
                                    ? CmsTheme.successText
                                    : CmsTheme.textPrimary,
                                fontSize: 13,
                                fontWeight: isCorrect
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                          if (isCorrect)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: CmsTheme.successColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'CORRECT ANSWER',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],

            if (q.explanation != null && q.explanation!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: CmsTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: CmsTheme.borderColor.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.lightbulb_outline,
                      size: 16,
                      color: Color(0xFFFBBF24),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Explanation: ${q.explanation}',
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
    );
  }
}
