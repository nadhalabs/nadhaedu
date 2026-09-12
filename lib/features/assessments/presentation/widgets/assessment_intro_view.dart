import 'package:flutter/material.dart';
import 'package:learning_platform/core/theme/app_spacing.dart';
import 'package:learning_platform/core/theme/app_tokens.dart';
import 'package:learning_platform/features/assessments/application/assessment_controller.dart';
import 'package:learning_platform/features/assessments/domain/assessment.dart';
import 'package:learning_platform/features/assessments/domain/assessment_attempt.dart';

class AssessmentIntroView extends StatelessWidget {
  const AssessmentIntroView({
    required this.assessment,
    required this.attemptSummary,
    required this.controller,
    super.key,
  });

  final Assessment assessment;
  final AssessmentAttemptSummary? attemptSummary;
  final AssessmentController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canAttempt = attemptSummary?.canAttempt ?? true;
    final hasPassed = attemptSummary?.hasPassed ?? false;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.large),
          children: [
            Semantics(
              header: true,
              child: Text(
                assessment.title,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.small),
            Text(
              assessment.description,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.large),
            Card(
              elevation: 0,
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.medium),
                child: Column(
                  children: [
                    _InfoRow(
                      icon: Icons.quiz_outlined,
                      label: 'Questions',
                      value:
                          '${assessment.questionCount} questions (${assessment.totalPoints} points)',
                    ),
                    const Divider(height: AppSpacing.medium),
                    _InfoRow(
                      icon: Icons.timer_outlined,
                      label: 'Time Limit',
                      value: assessment.isTimed
                          ? '${assessment.timeLimit!.inMinutes} minutes'
                          : 'No time limit',
                    ),
                    const Divider(height: AppSpacing.medium),
                    _InfoRow(
                      icon: Icons.check_circle_outline,
                      label: 'Passing Score',
                      value: '${assessment.passingScorePercentage}%',
                    ),
                    const Divider(height: AppSpacing.medium),
                    _InfoRow(
                      icon: Icons.replay_outlined,
                      label: 'Attempts Allowed',
                      value:
                          '${attemptSummary?.remainingAttempts ?? assessment.maxAttempts} of ${assessment.maxAttempts} remaining',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.large),
            if (assessment.instructions.isNotEmpty) ...[
              Text(
                'Instructions',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.small),
              for (final instruction in assessment.instructions)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.small),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.fiber_manual_record,
                        size: 10,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: AppSpacing.small),
                      Expanded(child: Text(instruction)),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.large),
            ],
            if (attemptSummary != null &&
                attemptSummary!.attempts.isNotEmpty) ...[
              Text(
                'Previous Attempts',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.small),
              for (final attempt in attemptSummary!.attempts)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    attempt.isPassed ? Icons.check_circle : Icons.cancel,
                    color: attempt.isPassed
                        ? theme.colorScheme.primary
                        : (theme.brightness == Brightness.dark
                              ? AppPalette.coral
                              : AppPalette.review),
                  ),
                  title: Text(
                    'Attempt ${attempt.attemptNumber}: ${attempt.percentage.round()}% (${attempt.score}/${attempt.maxScore} pts)',
                  ),
                  subtitle: Text(
                    attempt.isPassed ? 'Passed' : 'Did not pass',
                    style: TextStyle(
                      color: attempt.isPassed
                          ? theme.colorScheme.primary
                          : (theme.brightness == Brightness.dark
                                ? AppPalette.coral
                                : AppPalette.review),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.large),
            ],
            ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppSpacing.touchTarget,
              ),
              child: FilledButton.icon(
                onPressed: canAttempt ? controller.startAssessment : null,
                icon: Icon(hasPassed ? Icons.replay : Icons.play_arrow),
                label: Text(
                  !canAttempt
                      ? 'No Attempts Remaining'
                      : hasPassed
                      ? 'Retake Assessment'
                      : attemptSummary?.attempts.isNotEmpty ?? false
                      ? 'Retry Assessment'
                      : 'Start Assessment',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: AppSpacing.small),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.xSmall),
              Text(value, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      ],
    );
  }
}
