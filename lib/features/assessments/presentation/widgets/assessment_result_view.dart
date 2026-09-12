import 'package:flutter/material.dart';
import 'package:learning_platform/core/theme/app_spacing.dart';
import 'package:learning_platform/core/theme/app_tokens.dart';
import 'package:learning_platform/core/widgets/learning_feedback.dart';
import 'package:learning_platform/features/assessments/application/assessment_controller.dart';
import 'package:learning_platform/features/assessments/domain/assessment.dart';
import 'package:learning_platform/features/assessments/domain/assessment_attempt.dart';
import 'package:learning_platform/features/assessments/domain/assessment_result.dart';

class AssessmentResultView extends StatelessWidget {
  const AssessmentResultView({
    required this.assessment,
    required this.result,
    required this.attemptSummary,
    required this.controller,
    this.onContinue,
    super.key,
  });

  final Assessment assessment;
  final AssessmentResult result;
  final AssessmentAttemptSummary? attemptSummary;
  final AssessmentController controller;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPassed = result.isPassed;
    final canAttempt = attemptSummary?.canAttempt ?? false;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.large),
          children: [
            if (isPassed) ...[
              const LearningCelebration(
                title: 'Look how far you’ve come!',
                message:
                    'Your assessment is complete. Keep that curiosity growing.',
              ),
              const SizedBox(height: AppSpacing.large),
            ],
            Container(
              padding: const EdgeInsets.all(AppSpacing.large),
              decoration: BoxDecoration(
                color: isPassed
                    ? theme.colorScheme.primary.withValues(alpha: 0.15)
                    : AppPalette.softSurface(context, AppPalette.coral),
                borderRadius: BorderRadius.circular(AppRadii.large),
                border: Border.all(
                  color: isPassed
                      ? theme.colorScheme.primary
                      : (theme.brightness == Brightness.dark
                            ? AppPalette.coral
                            : AppPalette.review),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    isPassed
                        ? Icons.check_circle
                        : Icons.lightbulb_outline_rounded,
                    size: 64,
                    color: isPassed
                        ? theme.colorScheme.primary
                        : (theme.brightness == Brightness.dark
                              ? AppPalette.coral
                              : AppPalette.review),
                  ),
                  const SizedBox(height: AppSpacing.medium),
                  Semantics(
                    header: true,
                    child: Text(
                      isPassed ? 'Assessment Passed!' : 'Assessment Not Passed',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isPassed
                            ? theme.colorScheme.primary
                            : (theme.brightness == Brightness.dark
                                  ? AppPalette.coral
                                  : AppPalette.review),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.small),
                  Text(
                    result.feedbackSummary,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.large),
                  Wrap(
                    alignment: WrapAlignment.spaceEvenly,
                    spacing: AppSpacing.large,
                    runSpacing: AppSpacing.medium,
                    children: [
                      _ResultMetric(
                        label: 'Score',
                        value: '${result.percentage.round()}%',
                        subtext: '${result.earnedScore}/${result.maxScore} pts',
                      ),
                      _ResultMetric(
                        label: 'Passing Required',
                        value: '${result.passingPercentage}%',
                        subtext: 'Minimum',
                      ),
                      _ResultMetric(
                        label: 'Time Taken',
                        value:
                            '${result.durationTaken.inMinutes}m ${result.durationTaken.inSeconds.remainder(60)}s',
                        subtext: 'Duration',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xLarge),
            Text(
              'Question Review & Explanations',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.medium),
            for (var i = 0; i < result.questionResults.length; i++) ...[
              _QuestionResultCard(
                index: i + 1,
                question: assessment.questions.firstWhere(
                  (q) => q.id == result.questionResults[i].questionId,
                ),
                questionResult: result.questionResults[i],
              ),
              const SizedBox(height: AppSpacing.medium),
            ],
            const SizedBox(height: AppSpacing.large),
            Wrap(
              spacing: AppSpacing.medium,
              runSpacing: AppSpacing.small,
              children: [
                if (canAttempt && !isPassed)
                  OutlinedButton.icon(
                    onPressed: controller.retake,
                    icon: const Icon(Icons.replay),
                    label: const Text('Try Again'),
                  ),
                FilledButton.icon(
                  onPressed: onContinue,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(
                    isPassed ? 'Continue Learning' : 'Return to Course',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultMetric extends StatelessWidget {
  const _ResultMetric({
    required this.label,
    required this.value,
    required this.subtext,
  });

  final String label;
  final String value;
  final String subtext;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        Text(
          subtext,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _QuestionResultCard extends StatelessWidget {
  const _QuestionResultCard({
    required this.index,
    required this.question,
    required this.questionResult,
  });

  final int index;
  final dynamic question;
  final QuestionResult questionResult;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCorrect = questionResult.isCorrect;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.medium),
        side: BorderSide(
          color: isCorrect
              ? theme.colorScheme.primary.withValues(alpha: 0.5)
              : (theme.brightness == Brightness.dark
                        ? AppPalette.coral
                        : AppPalette.review)
                    .withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AppSpacing.small,
              runSpacing: AppSpacing.small,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(
                  isCorrect
                      ? Icons.check_circle
                      : Icons.lightbulb_outline_rounded,
                  color: isCorrect
                      ? theme.colorScheme.primary
                      : (theme.brightness == Brightness.dark
                            ? AppPalette.coral
                            : AppPalette.review),
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.small),
                Text(
                  'Question $index',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${questionResult.earnedPoints}/${questionResult.maxPoints} pts',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isCorrect
                        ? theme.colorScheme.primary
                        : (theme.brightness == Brightness.dark
                              ? AppPalette.coral
                              : AppPalette.review),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.small),
            Text(
              question.prompt,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AppSpacing.small),
            if (questionResult.feedback != null)
              Text(
                'Feedback: ${questionResult.feedback}',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            if (questionResult.explanation != null) ...[
              const SizedBox(height: AppSpacing.small),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.small),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppRadii.small),
                ),
                child: Text(
                  'Explanation: ${questionResult.explanation}',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
