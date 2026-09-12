import 'package:flutter/material.dart';
import 'package:learning_platform/core/motion/app_motion.dart';
import 'package:learning_platform/core/theme/app_spacing.dart';
import 'package:learning_platform/core/theme/app_tokens.dart';
import 'package:learning_platform/features/assessments/application/assessment_controller.dart';
import 'package:learning_platform/features/assessments/domain/assessment_question.dart';
import 'package:learning_platform/features/assessments/domain/assessment_submission.dart';

class SingleChoiceQuestionWidget extends StatelessWidget {
  const SingleChoiceQuestionWidget({
    required this.question,
    required this.answer,
    required this.controller,
    super.key,
  });
  final SingleChoiceQuestion question;
  final SingleChoiceAnswer? answer;
  final AssessmentController controller;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final option in question.options)
        _AnswerOption(
          label: option.text,
          hint: option.hint,
          selected: answer?.selectedOptionId == option.id,
          onTap: () => controller.selectSingleChoice(question.id, option.id),
        ),
    ],
  );
}

class MultipleChoiceQuestionWidget extends StatelessWidget {
  const MultipleChoiceQuestionWidget({
    required this.question,
    required this.answer,
    required this.controller,
    super.key,
  });
  final MultipleChoiceQuestion question;
  final MultipleChoiceAnswer? answer;
  final AssessmentController controller;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Choose every answer that fits.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: AppSpacing.medium),
      for (final option in question.options)
        _AnswerOption(
          label: option.text,
          hint: option.hint,
          selected: answer?.selectedOptionIds.contains(option.id) ?? false,
          multiple: true,
          onTap: () => controller.toggleMultipleChoice(question.id, option.id),
        ),
    ],
  );
}

class _AnswerOption extends StatelessWidget {
  const _AnswerOption({
    required this.label,
    required this.selected,
    required this.onTap,
    this.hint,
    this.multiple = false,
  });
  final String label;
  final String? hint;
  final bool selected;
  final bool multiple;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.medium),
      child: Semantics(
        checked: selected,
        inMutuallyExclusiveGroup: !multiple,
        child: LearningLift(
          child: AnimatedContainer(
            duration: AppMotion.duration(context, AppMotion.micro),
            decoration: BoxDecoration(
              color: selected
                  ? colors.primaryContainer
                  : colors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppRadii.medium),
              border: Border.all(
                color: selected ? colors.primary : colors.outlineVariant,
                width: 2,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadii.medium),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.medium),
                  child: Row(
                    children: [
                      LearningSwitcher(
                        child: Icon(
                          selected
                              ? Icons.check_circle
                              : multiple
                              ? Icons.check_box_outline_blank
                              : Icons.circle_outlined,
                          key: ValueKey(selected),
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.medium),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (hint != null)
                              Text(
                                hint!,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TrueFalseQuestionWidget extends StatelessWidget {
  const TrueFalseQuestionWidget({
    required this.question,
    required this.answer,
    required this.controller,
    super.key,
  });

  final TrueFalseQuestion question;
  final TrueFalseAnswer? answer;
  final AssessmentController controller;

  @override
  Widget build(BuildContext context) {
    final selected = answer?.selectedValue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final value in [true, false])
          _AnswerOption(
            label: value ? 'True' : 'False',
            selected: selected == value,
            onTap: () => controller.setTrueFalse(question.id, value),
          ),
      ],
    );
  }
}

class TextResponseQuestionWidget extends StatefulWidget {
  const TextResponseQuestionWidget({
    required this.question,
    required this.answer,
    required this.controller,
    super.key,
  });

  final TextResponseQuestion question;
  final TextResponseAnswer? answer;
  final AssessmentController controller;

  @override
  State<TextResponseQuestionWidget> createState() =>
      _TextResponseQuestionWidgetState();
}

class _TextResponseQuestionWidgetState
    extends State<TextResponseQuestionWidget> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(
      text: widget.answer?.textContent ?? '',
    );
  }

  @override
  void didUpdateWidget(TextResponseQuestionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.question.id != widget.question.id) {
      _textController.text = widget.answer?.textContent ?? '';
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final words = _textController.text
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _textController,
          maxLines: 6,
          decoration: InputDecoration(
            hintText: widget.question.placeholder,
            border: const OutlineInputBorder(),
            helperText:
                'Minimum ${widget.question.minWords} words (currently $words)',
          ),
          onChanged: (val) =>
              widget.controller.setTextResponse(widget.question.id, val),
        ),
      ],
    );
  }
}
