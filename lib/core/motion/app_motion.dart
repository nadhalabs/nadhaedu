import 'package:flutter/material.dart';

/// Finite, frame-driven motion: no loops or fixed refresh-rate assumptions.
abstract final class AppMotion {
  static const micro = Duration(milliseconds: 160);
  static const standard = Duration(milliseconds: 240);
  static const navigation = Duration(milliseconds: 300);
  static const celebration = Duration(milliseconds: 800);
  static const curve = Curves.easeOutCubic;

  static bool reduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context) ||
      MediaQuery.accessibleNavigationOf(context);
  static Duration duration(BuildContext context, Duration value) =>
      reduced(context) ? Duration.zero : value;

  static Widget transition(
    BuildContext context,
    Animation<double> animation,
    Widget child,
  ) {
    if (reduced(context)) return child;
    final curved = animation.drive(CurveTween(curve: curve));
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: curved.drive(
          Tween(begin: const Offset(0, 0.025), end: Offset.zero),
        ),
        child: child,
      ),
    );
  }
}

/// Runs once per identity. The child is kept outside the animated builder.
class LearningEntrance extends StatelessWidget {
  const LearningEntrance({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduced(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.standard,
      curve: AppMotion.curve,
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - value)),
          child: child,
        ),
      ),
    );
  }
}

/// Removes outgoing controls immediately so rapid taps can't reach stale content.
class LearningSwitcher extends StatelessWidget {
  const LearningSwitcher({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: AppMotion.duration(context, AppMotion.standard),
    switchInCurve: AppMotion.curve,
    layoutBuilder: (current, previous) => current ?? const SizedBox.shrink(),
    transitionBuilder: (child, animation) =>
        AppMotion.transition(context, animation, child),
    child: child,
  );
}

/// Pointer feedback layered over existing controls; activation stays with them.
class LearningLift extends StatefulWidget {
  const LearningLift({required this.child, this.enabled = true, super.key});
  final Widget child;
  final bool enabled;
  @override
  State<LearningLift> createState() => _LearningLiftState();
}

class _LearningLiftState extends State<LearningLift> {
  bool _hovered = false;
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final reduced = AppMotion.reduced(context) || !widget.enabled;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: Listener(
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: AppMotion.duration(context, AppMotion.micro),
          curve: AppMotion.curve,
          transformAlignment: Alignment.center,
          transform: Matrix4.identity()
            ..translateByDouble(
              0,
              !reduced && _hovered && !_pressed ? -2 : 0,
              0,
              1,
            )
            ..scaleByDouble(
              !reduced && _pressed ? 0.985 : 1,
              !reduced && _pressed ? 0.985 : 1,
              1,
              1,
            ),
          child: widget.child,
        ),
      ),
    );
  }
}
