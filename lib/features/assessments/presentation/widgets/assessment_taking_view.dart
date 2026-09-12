import 'dart:async';

import 'package:flutter/material.dart';
import 'package:learning_platform/core/motion/app_motion.dart';
import 'package:learning_platform/core/theme/app_spacing.dart';
import 'package:learning_platform/core/theme/app_tokens.dart';
import 'package:learning_platform/core/widgets/learning_feedback.dart';
import 'package:learning_platform/features/assessments/application/assessment_controller.dart';
import 'package:learning_platform/features/assessments/application/assessment_state.dart';
import 'package:learning_platform/features/assessments/domain/assessment_question.dart';
import 'package:learning_platform/features/assessments/domain/assessment_submission.dart';
import 'package:learning_platform/features/assessments/presentation/widgets/assessment_question_views.dart';

class AssessmentTakingView extends StatelessWidget {
  const AssessmentTakingView({
    required this.state,
    required this.controller,
    super.key,
  });

  final AssessmentSessionState state;
  final AssessmentController controller;

  @override
  Widget build(BuildContext context) {
    final question = state.currentQuestion;
    if (question == null) {
      return const Center(child: Text('No question available.'));
    }

    final theme = Theme.of(context);
    final questionIndex = state.currentQuestionIndex;
    final totalQuestions = state.totalQuestions;
    final isMarked = state.isQuestionMarked(question.id);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
        child: Column(
          children: [
            LearningProgress(
              value: state.answeredCount / state.totalQuestions,
              label: 'Questions answered',
            ),
            _TakingHeader(
              state: state,
              controller: controller,
              isMarked: isMarked,
              questionId: question.id,
            ),
            Expanded(
              child: LearningSwitcher(
                child: ListView(
                  key: ValueKey(question.id),
                  padding: const EdgeInsets.all(AppSpacing.large),
                  children: [
                    Wrap(
                      spacing: AppSpacing.small,
                      runSpacing: AppSpacing.small,
                      children: [
                        Chip(
                          label: Text(
                            'Question ${questionIndex + 1} of $totalQuestions',
                          ),
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHigh,
                        ),
                        const SizedBox(width: AppSpacing.small),
                        Chip(
                          label: Text(
                            '${question.points} ${question.points == 1 ? "point" : "points"}',
                          ),
                        ),
                        if (isMarked) ...[
                          const SizedBox(width: AppSpacing.small),
                          Chip(
                            avatar: const Icon(
                              Icons.flag,
                              size: 16,
                              color: Colors.amber,
                            ),
                            label: const Text('Marked for Review'),
                            backgroundColor: Colors.amber.withValues(
                              alpha: 0.2,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.medium),
                    Semantics(
                      header: true,
                      child: Text(
                        question.prompt,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.large),
                    switch (question) {
                      SingleChoiceQuestion() => SingleChoiceQuestionWidget(
                        question: question,
                        answer:
                            state.answers[question.id] as SingleChoiceAnswer?,
                        controller: controller,
                      ),
                      MultipleChoiceQuestion() => MultipleChoiceQuestionWidget(
                        question: question,
                        answer:
                            state.answers[question.id] as MultipleChoiceAnswer?,
                        controller: controller,
                      ),
                      TrueFalseQuestion() => TrueFalseQuestionWidget(
                        question: question,
                        answer: state.answers[question.id] as TrueFalseAnswer?,
                        controller: controller,
                      ),
                      TextResponseQuestion() => TextResponseQuestionWidget(
                        question: question,
                        answer:
                            state.answers[question.id] as TextResponseAnswer?,
                        controller: controller,
                      ),
                    },
                  ],
                ),
              ),
            ),
            _TakingBottomNav(state: state, controller: controller),
          ],
        ),
      ),
    );
  }
}

class _TakingHeader extends StatelessWidget {
  const _TakingHeader({
    required this.state,
    required this.controller,
    required this.isMarked,
    required this.questionId,
  });

  final AssessmentSessionState state;
  final AssessmentController controller;
  final bool isMarked;
  final String questionId;

  String _formatDuration(Duration? duration) {
    if (duration == null) return '';
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time = state.timeRemaining;
    final isLowTime = time != null && time.inSeconds <= 60;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.large,
        vertical: AppSpacing.small,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (time != null)
            Row(
              children: [
                Icon(
                  Icons.timer,
                  size: 20,
                  color: isLowTime
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.small),
                Semantics(
                  liveRegion: isLowTime,
                  label:
                      '${time.inMinutes} minutes ${time.inSeconds.remainder(60)} seconds remaining',
                  excludeSemantics: true,
                  child: Text(
                    _formatDuration(time),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isLowTime ? theme.colorScheme.error : null,
                    ),
                  ),
                ),
              ],
            )
          else
            const SizedBox.shrink(),
          IconButton.outlined(
            tooltip: isMarked
                ? 'Unmark review flag'
                : 'Mark question for review',
            icon: Icon(
              isMarked ? Icons.flag : Icons.outlined_flag,
              color: isMarked ? theme.colorScheme.primary : null,
            ),
            onPressed: () => controller.toggleMarkForReview(questionId),
          ),
        ],
      ),
    );
  }
}

class _TakingBottomNav extends StatelessWidget {
  const _TakingBottomNav({required this.state, required this.controller});

  final AssessmentSessionState state;
  final AssessmentController controller;

  void _showSubmitDialog(BuildContext context) {
    final total = state.totalQuestions;
    final answered = state.answeredCount;
    final unanswered = total - answered;

    unawaited(
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Submit Assessment?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('You have answered $answered of $total questions.'),
              if (unanswered > 0) ...[
                const SizedBox(height: AppSpacing.small),
                Text(
                  'There are $unanswered questions you haven’t answered yet.',
                  style: TextStyle(
                    color: Theme.of(ctx).colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              if (state.markedForReview.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.small),
                Text(
                  'You have ${state.markedForReview.length} questions flagged for review.',
                  style: TextStyle(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Keep Working'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                unawaited(controller.submit());
              },
              child: const Text('Submit Now'),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuestionGridSheet(BuildContext context) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => FractionallySizedBox(
          heightFactor: 0.6,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.large),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Jump to a question',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.medium),
                Wrap(
                  spacing: AppSpacing.medium,
                  runSpacing: AppSpacing.small,
                  children: [
                    _legendItem(
                      ctx,
                      'Answered',
                      Theme.of(ctx).colorScheme.primaryContainer,
                    ),
                    _legendItem(
                      ctx,
                      'Current',
                      Theme.of(ctx).colorScheme.primary,
                    ),
                    _legendItem(ctx, 'Flagged', AppPalette.sunshine),
                    _legendItem(
                      ctx,
                      'Unanswered',
                      Theme.of(ctx).colorScheme.surfaceContainerHighest,
                    ),
                  ],
                ),
                const Divider(height: AppSpacing.large),
                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          mainAxisSpacing: AppSpacing.small,
                          crossAxisSpacing: AppSpacing.small,
                          childAspectRatio: 1.2,
                        ),
                    itemCount: state.totalQuestions,
                    itemBuilder: (ctx, index) {
                      final q = state.assessment!.questions[index];
                      final isCurrent = index == state.currentQuestionIndex;
                      final isAnswered = state.isQuestionAnswered(q.id);
                      final isFlagged = state.isQuestionMarked(q.id);

                      Color bg = Theme.of(
                        ctx,
                      ).colorScheme.surfaceContainerHighest;
                      if (isCurrent) {
                        bg = Theme.of(ctx).colorScheme.primary;
                      } else if (isFlagged) {
                        bg = AppPalette.sunshine;
                      } else if (isAnswered) {
                        bg = Theme.of(ctx).colorScheme.primaryContainer;
                      }

                      final status = isCurrent
                          ? 'current'
                          : isFlagged
                          ? 'flagged'
                          : isAnswered
                          ? 'answered'
                          : 'unanswered';
                      return Semantics(
                        button: true,
                        label: 'Question ${index + 1}, $status',
                        excludeSemantics: true,
                        child: InkWell(
                          onTap: () {
                            controller.goToQuestion(index);
                            Navigator.of(ctx).pop();
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: bg,
                              borderRadius: BorderRadius.circular(8),
                              border: isCurrent
                                  ? Border.all(color: Colors.white, width: 2)
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isCurrent ? Colors.white : null,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _legendItem(BuildContext context, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.medium),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: AppSpacing.small,
          runSpacing: AppSpacing.small,
          children: [
            OutlinedButton.icon(
              onPressed: state.isSubmitting || state.isFirstQuestion
                  ? null
                  : controller.previousQuestion,
              icon: const Icon(Icons.chevron_left),
              label: const Text('Previous'),
            ),
            TextButton.icon(
              onPressed: () => _showQuestionGridSheet(context),
              icon: const Icon(Icons.grid_view, size: 18),
              label: Text(
                '${state.answeredCount}/${state.totalQuestions} Answered',
              ),
            ),
            if (state.isLastQuestion)
              FilledButton.icon(
                onPressed: state.isSubmitting
                    ? null
                    : () => _showSubmitDialog(context),
                icon: const Icon(Icons.check),
                label: const Text('Submit'),
              )
            else
              FilledButton.icon(
                onPressed: state.isSubmitting ? null : controller.nextQuestion,
                icon: const Icon(Icons.chevron_right),
                label: const Text('Next'),
              ),
          ],
        ),
      ),
    );
  }
}
