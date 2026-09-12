import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:learning_platform/core/motion/app_motion.dart';
import 'package:learning_platform/core/theme/app_spacing.dart';
import 'package:learning_platform/core/theme/app_tokens.dart';
import 'package:learning_platform/core/widgets/learning_artwork.dart';

class LearningProgress extends StatelessWidget {
  const LearningProgress({
    required this.value,
    this.label = 'Learning progress',
    this.color,
    this.trackColor,
    super.key,
  });
  final double value;
  final String label;
  final Color? color;
  final Color? trackColor;
  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    value: '${(value.clamp(0, 1) * 100).round()}%',
    child: ExcludeSemantics(
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: value.clamp(0, 1)),
        duration: AppMotion.duration(context, AppMotion.standard),
        curve: AppMotion.curve,
        builder: (context, value, _) => LinearProgressIndicator(
          value: value,
          color: color,
          backgroundColor: trackColor,
        ),
      ),
    ),
  );
}

/// Shared illustration hook for onboarding and quieter empty states.
class LearningEmblem extends StatelessWidget {
  const LearningEmblem({
    this.size = AppIcons.illustration,
    this.variant = 0,
    super.key,
  });
  final double size;
  final int variant;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: LearningArtwork(
      identity: '$variant',
      kind: LearningArtworkKind.ideas,
    ),
  );
}

/// A finite badge reveal reserved for accepted learning milestones.
class LearningCelebration extends StatelessWidget {
  const LearningCelebration({
    required this.title,
    required this.message,
    this.icon = Icons.auto_awesome,
    super.key,
  });
  final String title;
  final String message;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: AppMotion.reduced(context) ? 1 : 0, end: 1),
      duration: AppMotion.duration(context, AppMotion.celebration),
      curve: AppMotion.curve,
      builder: (context, value, child) => Stack(
        alignment: Alignment.center,
        children: [
          Transform.scale(scale: 0.94 + value * 0.06, child: child),
          if (!AppMotion.reduced(context))
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _CelebrationPainter(
                    value,
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.large),
        decoration: BoxDecoration(
          color: AppPalette.softSurface(context, AppPalette.sunshine),
          borderRadius: BorderRadius.circular(AppRadii.large),
          border: Border.all(color: AppPalette.sunshine.withValues(alpha: 0.5)),
          boxShadow: AppShadows.surface,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.medium),
              decoration: const BoxDecoration(
                color: AppPalette.sunshine,
                shape: BoxShape.circle,
                boxShadow: AppShadows.floating,
              ),
              child: Icon(icon, size: AppIcons.feature, color: AppPalette.ink),
            ),
            const SizedBox(height: AppSpacing.small),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.small),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CelebrationPainter extends CustomPainter {
  const _CelebrationPainter(this.progress, this.color);
  final double progress;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: (1 - progress) * 0.5);
    for (var i = 0; i < 12; i++) {
      final angle = i * math.pi / 6;
      canvas.drawCircle(
        Offset(
          size.width / 2 + math.cos(angle) * size.width * progress / 2,
          size.height / 2 + math.sin(angle) * size.height * progress / 2,
        ),
        3,
        paint
          ..color = AppPalette
              .artworkAccents[i % AppPalette.artworkAccents.length]
              .withValues(alpha: (1 - progress) * 0.85),
      );
    }
  }

  @override
  bool shouldRepaint(_CelebrationPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

/// Awaited action with immediate disabled/loading feedback and safe failure UI.
class LearningAction extends StatefulWidget {
  const LearningAction({
    required this.label,
    required this.onPressed,
    this.icon = Icons.arrow_forward_rounded,
    this.busyLabel = 'Just a moment…',
    super.key,
  });
  final String label;
  final String busyLabel;
  final IconData icon;
  final Future<void> Function()? onPressed;
  @override
  State<LearningAction> createState() => _LearningActionState();
}

class _LearningActionState extends State<LearningAction> {
  bool _busy = false;
  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: _busy || widget.onPressed == null
        ? null
        : () async {
            setState(() => _busy = true);
            try {
              await widget.onPressed!();
            } on Object {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('That didn’t save. Please try again.'),
                  ),
                );
              }
            } finally {
              if (mounted) setState(() => _busy = false);
            }
          },
    icon: _busy
        ? const SizedBox.square(
            dimension: AppIcons.small,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(widget.icon),
    label: Text(_busy ? widget.busyLabel : widget.label),
  );
}
