import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_platform/core/motion/app_motion.dart';
import 'package:learning_platform/core/widgets/content_states.dart';
import 'package:learning_platform/features/assessments/application/assessment_providers.dart';
import 'package:learning_platform/features/assessments/application/assessment_state.dart';
import 'package:learning_platform/features/assessments/presentation/widgets/assessment_intro_view.dart';
import 'package:learning_platform/features/assessments/presentation/widgets/assessment_result_view.dart';
import 'package:learning_platform/features/assessments/presentation/widgets/assessment_taking_view.dart';
import 'package:learning_platform/features/content_protection/domain/content_protection_policy.dart';
import 'package:learning_platform/features/content_protection/presentation/widgets/protected_content_gate.dart';

class AssessmentScreen extends ConsumerStatefulWidget {
  const AssessmentScreen({
    required this.assessmentId,
    this.onPassed,
    this.onContinue,
    this.isEmbedded = false,
    super.key,
  });

  final String assessmentId;
  final VoidCallback? onPassed;
  final VoidCallback? onContinue;
  final bool isEmbedded;

  @override
  ConsumerState<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends ConsumerState<AssessmentScreen> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onResume: () => ref
          .read(assessmentControllerProvider(widget.assessmentId).notifier)
          .resynchronizeTimer(),
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(assessmentControllerProvider(widget.assessmentId));
    final controller = ref.read(
      assessmentControllerProvider(widget.assessmentId).notifier,
    );

    ref.listen(assessmentControllerProvider(widget.assessmentId), (prev, next) {
      if (prev?.result?.isPassed != true && next.result?.isPassed == true) {
        widget.onPassed?.call();
      }
    });

    Widget body;
    switch (state.status) {
      case AssessmentLifecycle.loading:
        body = const LoadingView(label: 'Loading assessment');
      case AssessmentLifecycle.starting:
        body = const LoadingView(label: 'Getting your questions ready');
      case AssessmentLifecycle.intro:
        body = AssessmentIntroView(
          assessment: state.assessment!,
          attemptSummary: state.attemptSummary,
          controller: controller,
        );
      case AssessmentLifecycle.taking:
      case AssessmentLifecycle.submitting:
        body = ProtectedContentGate(
          policy: ContentProtectionPolicy.blockCaptureWhereSupported,
          child: Stack(
            children: [
              AssessmentTakingView(state: state, controller: controller),
              if (state.isSubmitting)
                Container(
                  color: Colors.black.withValues(alpha: 0.3),
                  child: const LoadingView(label: 'Evaluating your answers...'),
                ),
            ],
          ),
        );
      case AssessmentLifecycle.completed:
        body = AssessmentResultView(
          assessment: state.assessment!,
          result: state.result!,
          attemptSummary: state.attemptSummary,
          controller: controller,
          onContinue: widget.onContinue,
        );
      case AssessmentLifecycle.error:
        body = MessageView(
          icon: Icons.cloud_off_outlined,
          title: 'Let’s try that again',
          message: state.attemptId == null
              ? 'We couldn’t open this assessment just now.'
              : 'Your answers are saved for this session. Reconnect and send them again.',
          actionLabel: state.attemptId == null ? 'Retry' : 'Send saved answers',
          onAction: controller.retry,
        );
    }

    body = LearningSwitcher(
      child: KeyedSubtree(
        key: ValueKey(
          state.status == AssessmentLifecycle.submitting
              ? AssessmentLifecycle.taking
              : state.status,
        ),
        child: body,
      ),
    );
    if (widget.isEmbedded) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(title: Text(state.assessment?.title ?? 'Assessment')),
      body: body,
    );
  }
}
