import 'package:flutter/material.dart';
import 'package:nadha_cms/features/cms/domain/cms_assessment.dart';
import 'package:nadha_cms/features/cms/domain/cms_course_detail.dart';
import 'package:nadha_cms/features/cms/presentation/theme/cms_theme.dart';

class CmsSectionDialog extends StatefulWidget {
  const CmsSectionDialog({super.key, this.initialModule});

  final CmsModuleDetail? initialModule;

  static Future<Map<String, String>?> show(
    BuildContext context, {
    CmsModuleDetail? initialModule,
  }) {
    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) => CmsSectionDialog(initialModule: initialModule),
    );
  }

  @override
  State<CmsSectionDialog> createState() => _CmsSectionDialogState();
}

class _CmsSectionDialogState extends State<CmsSectionDialog> {
  late final TextEditingController _titleController;
  late String _policyKind;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.initialModule?.title ?? '',
    );
    _policyKind = widget.initialModule?.policyKind ?? 'inherit';
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initialModule != null;

    return AlertDialog(
      backgroundColor: CmsTheme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: CmsTheme.borderColor),
      ),
      title: Text(
        isEdit ? 'Edit Chapter' : 'Add Chapter',
        style: const TextStyle(
          color: CmsTheme.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Chapter Title',
                style: TextStyle(
                  color: CmsTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _titleController,
                style: const TextStyle(
                  color: CmsTheme.textPrimary,
                  fontSize: 13,
                ),
                decoration: const InputDecoration(hintText: 'e.g. Light'),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a chapter title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Access Policy Override',
                style: TextStyle(
                  color: CmsTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _policyKind,
                dropdownColor: CmsTheme.cardColor,
                style: const TextStyle(
                  color: CmsTheme.textPrimary,
                  fontSize: 13,
                ),
                decoration: const InputDecoration(isDense: true),
                items: const [
                  DropdownMenuItem(
                    value: 'inherit',
                    child: Text('Inherit from Course'),
                  ),
                  DropdownMenuItem(
                    value: 'free',
                    child: Text('Free (Publicly Accessible)'),
                  ),
                  DropdownMenuItem(
                    value: 'premium',
                    child: Text('Premium (Subscription/Purchase Required)'),
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
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(color: CmsTheme.textMuted),
          ),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.of(context).pop({
                'title': _titleController.text.trim(),
                'policyKind': _policyKind,
              });
            }
          },
          style: FilledButton.styleFrom(
            backgroundColor: CmsTheme.primaryAccent,
            foregroundColor: Colors.white,
          ),
          child: Text(isEdit ? 'Save Chapter' : 'Create Chapter'),
        ),
      ],
    );
  }
}

class CmsLessonDialog extends StatefulWidget {
  const CmsLessonDialog({super.key, this.initialLesson});

  final CmsLessonDetail? initialLesson;

  static Future<Map<String, Object?>?> show(
    BuildContext context, {
    CmsLessonDetail? initialLesson,
  }) {
    return showDialog<Map<String, Object?>>(
      context: context,
      builder: (context) => CmsLessonDialog(initialLesson: initialLesson),
    );
  }

  @override
  State<CmsLessonDialog> createState() => _CmsLessonDialogState();
}

class _CmsLessonDialogState extends State<CmsLessonDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _durationMinutesController;
  late final TextEditingController _durationSecondsController;
  late final TextEditingController _contentRefController;
  late String _contentType;
  late bool _isPreview;
  late bool _isDownloadable;
  late String _protectionPolicy;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final l = widget.initialLesson;
    _titleController = TextEditingController(text: l?.title ?? '');
    final totalSeconds = l?.durationSeconds ?? 300;
    _durationMinutesController = TextEditingController(
      text: '${totalSeconds ~/ 60}',
    );
    _durationSecondsController = TextEditingController(
      text: '${totalSeconds % 60}',
    );
    _contentRefController = TextEditingController(text: l?.contentRef ?? '');
    _contentType = l?.contentType ?? 'video';
    _isPreview = l?.isPreview ?? false;
    _isDownloadable = l?.isDownloadable ?? true;
    _protectionPolicy = l?.protectionPolicy ?? 'blockCaptureWhereSupported';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _durationMinutesController.dispose();
    _durationSecondsController.dispose();
    _contentRefController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initialLesson != null;

    return AlertDialog(
      backgroundColor: CmsTheme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: CmsTheme.borderColor),
      ),
      title: Text(
        isEdit ? 'Edit Lesson' : 'Add Lesson to Chapter',
        style: const TextStyle(
          color: CmsTheme.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Lesson Title',
                  style: TextStyle(
                    color: CmsTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _titleController,
                  style: const TextStyle(
                    color: CmsTheme.textPrimary,
                    fontSize: 13,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'e.g. Dependency Injection with Riverpod',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter a lesson title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Duration (Minutes)',
                            style: TextStyle(
                              color: CmsTheme.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _durationMinutesController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(
                              color: CmsTheme.textPrimary,
                              fontSize: 13,
                            ),
                            decoration: const InputDecoration(hintText: '5'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Duration (Seconds)',
                            style: TextStyle(
                              color: CmsTheme.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _durationSecondsController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(
                              color: CmsTheme.textPrimary,
                              fontSize: 13,
                            ),
                            decoration: const InputDecoration(hintText: '0'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Legacy reference (optional for new lessons; use Content items after saving)',
                  style: TextStyle(
                    color: CmsTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _contentRefController,
                  style: const TextStyle(
                    color: CmsTheme.textPrimary,
                    fontSize: 13,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'e.g. vid_flutter_arch_01',
                  ),
                  validator: (val) {
                    if (isEdit && (val == null || val.trim().isEmpty)) {
                      return 'Content reference is required for playback validation';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _contentType,
                        dropdownColor: CmsTheme.cardColor,
                        style: const TextStyle(
                          color: CmsTheme.textPrimary,
                          fontSize: 13,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Content Type',
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'video',
                            child: Text('Video'),
                          ),
                          DropdownMenuItem(
                            value: 'article',
                            child: Text('Article / Doc'),
                          ),
                          DropdownMenuItem(
                            value: 'interactive',
                            child: Text('Interactive (legacy)'),
                          ),
                          DropdownMenuItem(
                            value: 'quiz',
                            child: Text('Quiz (legacy)'),
                          ),
                          DropdownMenuItem(
                            value: 'resource',
                            child: Text('Resource (legacy)'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _contentType = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _protectionPolicy,
                        dropdownColor: CmsTheme.cardColor,
                        style: const TextStyle(
                          color: CmsTheme.textPrimary,
                          fontSize: 13,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'DRM / Protection',
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'blockCaptureWhereSupported',
                            child: Text('Block Screen Capture'),
                          ),
                          DropdownMenuItem(
                            value: 'allowCapture',
                            child: Text('Allow Capture (Public)'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _protectionPolicy = val);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: const Text(
                    'Free Preview Lesson (Unauthenticated discovery)',
                    style: TextStyle(color: CmsTheme.textPrimary, fontSize: 13),
                  ),
                  value: _isPreview,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeColor: CmsTheme.primaryAccent,
                  onChanged: (val) => setState(() => _isPreview = val ?? false),
                ),
                CheckboxListTile(
                  title: const Text(
                    'Allow Offline Download for Learners',
                    style: TextStyle(color: CmsTheme.textPrimary, fontSize: 13),
                  ),
                  value: _isDownloadable,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeColor: CmsTheme.primaryAccent,
                  onChanged: (val) =>
                      setState(() => _isDownloadable = val ?? true),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(color: CmsTheme.textMuted),
          ),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              final mins =
                  int.tryParse(_durationMinutesController.text.trim()) ?? 0;
              final secs =
                  int.tryParse(_durationSecondsController.text.trim()) ?? 0;
              final totalSecs = (mins * 60) + secs;

              Navigator.of(context).pop({
                'title': _titleController.text.trim(),
                'durationSeconds': totalSecs > 0 ? totalSecs : 60,
                if (_contentRefController.text.trim().isNotEmpty)
                  'contentRef': _contentRefController.text.trim(),
                'contentType': _contentType,
                'isPreview': _isPreview,
                'isDownloadable': _isDownloadable,
                'protectionPolicy': _protectionPolicy,
                'policyKind': 'inherit',
              });
            }
          },
          style: FilledButton.styleFrom(
            backgroundColor: CmsTheme.primaryAccent,
            foregroundColor: Colors.white,
          ),
          child: Text(isEdit ? 'Save Lesson' : 'Add Lesson'),
        ),
      ],
    );
  }
}

class CmsQuestionDialog extends StatefulWidget {
  const CmsQuestionDialog({super.key, this.initialQuestion});

  final CmsQuestionDetail? initialQuestion;

  static Future<Map<String, Object?>?> show(
    BuildContext context, {
    CmsQuestionDetail? initialQuestion,
  }) {
    return showDialog<Map<String, Object?>>(
      context: context,
      builder: (context) => CmsQuestionDialog(initialQuestion: initialQuestion),
    );
  }

  @override
  State<CmsQuestionDialog> createState() => _CmsQuestionDialogState();
}

class _CmsQuestionDialogState extends State<CmsQuestionDialog> {
  late final TextEditingController _promptController;
  late final TextEditingController _pointsController;
  late final TextEditingController _explanationController;
  late String _type;
  late List<TextEditingController> _optionControllers;
  late String? _correctOptionId;
  late bool _correctTfValue;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final q = widget.initialQuestion;
    _promptController = TextEditingController(text: q?.prompt ?? '');
    _pointsController = TextEditingController(text: '${q?.points ?? 1}');
    _explanationController = TextEditingController(text: q?.explanation ?? '');
    _type = q?.type ?? 'singleChoice';

    if (q != null && q.options.isNotEmpty) {
      _optionControllers = q.options
          .map((o) => TextEditingController(text: o.text))
          .toList();
      _correctOptionId =
          q.gradingData['correctOptionId'] as String? ??
          (q.options.isNotEmpty ? 'opt-0' : null);
    } else {
      _optionControllers = [
        TextEditingController(text: 'Option A'),
        TextEditingController(text: 'Option B'),
        TextEditingController(text: 'Option C'),
        TextEditingController(text: 'Option D'),
      ];
      _correctOptionId = 'opt-0';
    }

    _correctTfValue = (q?.gradingData['correctValue'] as bool?) ?? true;
  }

  @override
  void dispose() {
    _promptController.dispose();
    _pointsController.dispose();
    _explanationController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    setState(() {
      _optionControllers.add(
        TextEditingController(text: 'Option ${_optionControllers.length + 1}'),
      );
    });
  }

  void _removeOption(int index) {
    if (_optionControllers.length <= 2) return;
    setState(() {
      final removed = _optionControllers.removeAt(index);
      removed.dispose();
      _correctOptionId = 'opt-0';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initialQuestion != null;

    return AlertDialog(
      backgroundColor: CmsTheme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: CmsTheme.borderColor),
      ),
      title: Text(
        isEdit ? 'Edit Assessment Question' : 'Add Assessment Question',
        style: const TextStyle(
          color: CmsTheme.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 540,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        initialValue: _type,
                        dropdownColor: CmsTheme.cardColor,
                        style: const TextStyle(
                          color: CmsTheme.textPrimary,
                          fontSize: 13,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Question Type',
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'singleChoice',
                            child: Text('Single Choice (Radio)'),
                          ),
                          DropdownMenuItem(
                            value: 'multipleChoice',
                            child: Text('Multiple Choice (Checkboxes)'),
                          ),
                          DropdownMenuItem(
                            value: 'trueFalse',
                            child: Text('True / False'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _type = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: _pointsController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          color: CmsTheme.textPrimary,
                          fontSize: 13,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Points',
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Question Prompt',
                  style: TextStyle(
                    color: CmsTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _promptController,
                  maxLines: 3,
                  style: const TextStyle(
                    color: CmsTheme.textPrimary,
                    fontSize: 13,
                  ),
                  decoration: const InputDecoration(
                    hintText:
                        'e.g. What is the difference between StateNotifier and Notifier?',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter a question prompt';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                if (_type == 'trueFalse') ...[
                  const Text(
                    'Correct Answer',
                    style: TextStyle(
                      color: CmsTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('TRUE'),
                        selected: _correctTfValue == true,
                        onSelected: (_) =>
                            setState(() => _correctTfValue = true),
                        selectedColor: CmsTheme.successBg,
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('FALSE'),
                        selected: _correctTfValue == false,
                        onSelected: (_) =>
                            setState(() => _correctTfValue = false),
                        selectedColor: CmsTheme.dangerBg,
                      ),
                    ],
                  ),
                ] else ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Answer Options & Correct Key',
                        style: TextStyle(
                          color: CmsTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _addOption,
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text(
                          'Add Option',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  for (var i = 0; i < _optionControllers.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Radio<String>(
                            value: 'opt-$i',
                            // RadioGroup migration would alter the surrounding
                            // dynamic form hierarchy; retain the tested behavior
                            // until that widget is migrated as a unit.
                            // ignore: deprecated_member_use
                            groupValue: _correctOptionId,
                            activeColor: CmsTheme.successColor,
                            // ignore: deprecated_member_use
                            onChanged: (val) =>
                                setState(() => _correctOptionId = val),
                          ),
                          Expanded(
                            child: TextFormField(
                              controller: _optionControllers[i],
                              style: const TextStyle(
                                color: CmsTheme.textPrimary,
                                fontSize: 13,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: 'Option ${i + 1}',
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Option cannot be empty';
                                }
                                return null;
                              },
                            ),
                          ),
                          if (_optionControllers.length > 2)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 16),
                              color: CmsTheme.dangerText,
                              onPressed: () => _removeOption(i),
                            ),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: 10),
                const Text(
                  'Explanation / Solution Notes (Shown during review)',
                  style: TextStyle(
                    color: CmsTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _explanationController,
                  maxLines: 2,
                  style: const TextStyle(
                    color: CmsTheme.textPrimary,
                    fontSize: 13,
                  ),
                  decoration: const InputDecoration(
                    hintText:
                        'Explanation of why the selected answer is correct...',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(color: CmsTheme.textMuted),
          ),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              final pts = int.tryParse(_pointsController.text.trim()) ?? 1;

              final optionsList = <Map<String, Object?>>[];
              final gradingData = <String, Object?>{};

              if (_type == 'trueFalse') {
                gradingData['correctValue'] = _correctTfValue;
              } else {
                for (var i = 0; i < _optionControllers.length; i++) {
                  final optId = 'opt-$i';
                  optionsList.add({
                    'id': optId,
                    'text': _optionControllers[i].text.trim(),
                    'position': i + 1,
                  });
                }
                gradingData['correctOptionId'] = _correctOptionId ?? 'opt-0';
              }

              Navigator.of(context).pop({
                'type': _type,
                'prompt': _promptController.text.trim(),
                'points': pts > 0 ? pts : 1,
                'explanation': _explanationController.text.trim(),
                'options': optionsList,
                'gradingData': gradingData,
                'settings': <String, Object?>{},
              });
            }
          },
          style: FilledButton.styleFrom(
            backgroundColor: CmsTheme.primaryAccent,
            foregroundColor: Colors.white,
          ),
          child: Text(isEdit ? 'Save Question' : 'Add Question'),
        ),
      ],
    );
  }
}
