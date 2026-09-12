import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:learning_platform/core/theme/app_tokens.dart';

enum LearningArtworkKind { code, geometry, space, science, ideas }

/// Original geometric course illustrations. No mascot, remote image or fake data.
class LearningArtwork extends StatelessWidget {
  const LearningArtwork({
    this.identity = '',
    this.title = '',
    this.onBlue = false,
    this.kind,
    super.key,
  });
  final String identity;
  final String title;
  final bool onBlue;
  final LearningArtworkKind? kind;

  LearningArtworkKind get resolvedKind {
    final topic = title.toLowerCase();
    if (RegExp(
      r'code|program|flutter|dart|web|computer|architect|development',
    ).hasMatch(topic)) {
      return LearningArtworkKind.code;
    }
    if (RegExp(
      r'math|number|geometry|design|art|data|analytics',
    ).hasMatch(topic)) {
      return LearningArtworkKind.geometry;
    }
    if (RegExp(r'science|chem|nature|biology').hasMatch(topic)) {
      return LearningArtworkKind.science;
    }
    if (RegExp(r'space|earth|world|physics').hasMatch(topic)) {
      return LearningArtworkKind.space;
    }
    if (RegExp(
      r'business|leadership|mindful|strategy|research',
    ).hasMatch(topic)) {
      return LearningArtworkKind.ideas;
    }
    return LearningArtworkKind.values[AppPalette.variant(identity)];
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(
      child: CustomPaint(
        painter: _LearningArtworkPainter(
          kind ?? resolvedKind,
          AppPalette.accent(identity),
          onBlue,
        ),
        child: const SizedBox.expand(),
      ),
    ),
  );
}

class _LearningArtworkPainter extends CustomPainter {
  const _LearningArtworkPainter(this.kind, this.accent, this.onBlue);
  final LearningArtworkKind kind;
  final Color accent;
  final bool onBlue;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / 240, size.height / 170);
    canvas.save();
    canvas.translate(
      (size.width - 240 * scale) / 2,
      (size.height - 170 * scale) / 2,
    );
    canvas.scale(scale);
    final paint = Paint()..isAntiAlias = true;
    final line = onBlue ? Colors.white : AppPalette.ocean;
    canvas.drawCircle(
      const Offset(124, 85),
      64,
      paint
        ..color = (onBlue ? Colors.white : accent).withValues(
          alpha: onBlue ? 0.12 : 0.28,
        ),
    );
    canvas.drawCircle(
      const Offset(190, 37),
      15,
      paint..color = AppPalette.sunshine,
    );
    canvas.drawCircle(
      const Offset(41, 120),
      8,
      paint..color = AppPalette.coral,
    );
    canvas.drawCircle(
      const Offset(204, 124),
      5,
      paint..color = line.withValues(alpha: 0.65),
    );
    _sparkle(canvas, const Offset(49, 43), 10, line);
    _sparkle(canvas, const Offset(179, 142), 7, line.withValues(alpha: 0.75));
    switch (kind) {
      case LearningArtworkKind.code:
        canvas.save();
        canvas.translate(120, 85);
        canvas.rotate(-0.07);
        _panel(canvas, const Rect.fromLTWH(-65, -43, 130, 88), AppPalette.ink);
        _panel(canvas, const Rect.fromLTWH(-61, -47, 122, 85), Colors.white);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-61, -47, 122, 20),
            const Radius.circular(10),
          ),
          paint..color = AppPalette.blueWash,
        );
        for (var i = 0; i < 3; i++) {
          canvas.drawCircle(
            Offset(-48 + i * 9, -37),
            2.5,
            paint
              ..color = [
                AppPalette.coral,
                AppPalette.sunshine,
                AppPalette.mint,
              ][i],
          );
        }
        final strokes = Paint()
          ..color = AppPalette.ocean
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        canvas.drawPath(
          Path()
            ..moveTo(-22, -10)
            ..lineTo(-36, 3)
            ..lineTo(-22, 16),
          strokes,
        );
        canvas.drawPath(
          Path()
            ..moveTo(22, -10)
            ..lineTo(36, 3)
            ..lineTo(22, 16),
          strokes,
        );
        canvas.drawLine(
          const Offset(8, -16),
          const Offset(-7, 22),
          strokes..color = AppPalette.coral,
        );
        canvas.restore();
      case LearningArtworkKind.geometry:
        canvas.save();
        canvas.translate(100, 73);
        canvas.rotate(-0.15);
        _panel(canvas, const Rect.fromLTWH(-40, -38, 80, 80), AppPalette.ocean);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-25, -22, 50, 50),
            const Radius.circular(9),
          ),
          paint..color = AppPalette.sky,
        );
        canvas.restore();
        canvas.drawCircle(
          const Offset(151, 109),
          34,
          paint..color = AppPalette.sunshine,
        );
        canvas.drawCircle(
          const Offset(151, 109),
          15,
          paint..color = Colors.white,
        );
        canvas.drawPath(
          Path()
            ..moveTo(158, 28)
            ..lineTo(186, 74)
            ..lineTo(135, 74)
            ..close(),
          paint..color = AppPalette.coral,
        );
      case LearningArtworkKind.space:
        canvas.save();
        canvas.translate(121, 83);
        canvas.rotate(-0.36);
        canvas.drawCircle(Offset.zero, 40, paint..color = AppPalette.ocean);
        canvas.drawArc(
          const Rect.fromLTWH(-29, -32, 59, 57),
          -math.pi,
          math.pi,
          false,
          paint
            ..color = AppPalette.sky
            ..style = PaintingStyle.stroke
            ..strokeWidth = 12,
        );
        paint.style = PaintingStyle.fill;
        canvas.drawOval(
          const Rect.fromLTWH(-69, -15, 138, 31),
          paint
            ..color = AppPalette.sunshine
            ..style = PaintingStyle.stroke
            ..strokeWidth = 8,
        );
        paint.style = PaintingStyle.fill;
        canvas.restore();
      case LearningArtworkKind.science:
        final flask = Path()
          ..moveTo(107, 38)
          ..lineTo(132, 38)
          ..lineTo(132, 72)
          ..lineTo(162, 118)
          ..quadraticBezierTo(168, 134, 148, 134)
          ..lineTo(88, 134)
          ..quadraticBezierTo(70, 134, 79, 118)
          ..lineTo(107, 72)
          ..close();
        canvas.drawPath(flask, paint..color = Colors.white);
        canvas.save();
        canvas.clipPath(flask);
        canvas.drawRect(
          const Rect.fromLTWH(65, 95, 105, 48),
          paint..color = AppPalette.sky,
        );
        for (final point in [
          const Offset(105, 110),
          const Offset(135, 121),
          const Offset(124, 102),
        ]) {
          canvas.drawCircle(
            point,
            4,
            paint..color = Colors.white.withValues(alpha: 0.7),
          );
        }
        canvas.restore();
        canvas.drawPath(
          flask,
          paint
            ..color = AppPalette.ocean
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4,
        );
        paint.style = PaintingStyle.fill;
        canvas.drawCircle(
          const Offset(117, 21),
          6,
          paint..color = AppPalette.mint,
        );
        canvas.drawCircle(
          const Offset(144, 40),
          4,
          paint..color = AppPalette.coral,
        );
      case LearningArtworkKind.ideas:
        canvas.save();
        canvas.translate(119, 88);
        canvas.rotate(0.08);
        _panel(
          canvas,
          const Rect.fromLTWH(-52, -47, 105, 95),
          AppPalette.ocean,
        );
        _panel(canvas, const Rect.fromLTWH(-45, -54, 104, 94), Colors.white);
        canvas.drawLine(
          const Offset(7, -48),
          const Offset(7, 31),
          paint
            ..color = AppPalette.blueWash
            ..strokeWidth = 3,
        );
        for (var i = 0; i < 3; i++) {
          canvas.drawLine(
            Offset(-31, -18 + i * 13),
            Offset(-5, -18 + i * 13),
            paint
              ..color = AppPalette.sky
              ..strokeWidth = 4
              ..strokeCap = StrokeCap.round,
          );
          canvas.drawLine(
            Offset(21, -18 + i * 13),
            Offset(46, -18 + i * 13),
            paint,
          );
        }
        canvas.restore();
        _sparkle(canvas, const Offset(161, 43), 21, AppPalette.sunshine);
    }
    canvas.restore();
  }

  void _panel(Canvas canvas, Rect rect, Color color) => canvas.drawRRect(
    RRect.fromRectAndRadius(rect, const Radius.circular(12)),
    Paint()..color = color,
  );
  void _sparkle(Canvas canvas, Offset center, double radius, Color color) {
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..quadraticBezierTo(
        center.dx + radius * 0.2,
        center.dy - radius * 0.2,
        center.dx + radius,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx + radius * 0.2,
        center.dy + radius * 0.2,
        center.dx,
        center.dy + radius,
      )
      ..quadraticBezierTo(
        center.dx - radius * 0.2,
        center.dy + radius * 0.2,
        center.dx - radius,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx - radius * 0.2,
        center.dy - radius * 0.2,
        center.dx,
        center.dy - radius,
      )
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_LearningArtworkPainter oldDelegate) =>
      oldDelegate.kind != kind ||
      oldDelegate.accent != accent ||
      oldDelegate.onBlue != onBlue;
}
