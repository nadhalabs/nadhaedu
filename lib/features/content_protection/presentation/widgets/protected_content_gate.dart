import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_platform/core/theme/app_spacing.dart';
import 'package:learning_platform/features/content_protection/application/content_protection_service.dart';
import 'package:learning_platform/features/content_protection/domain/content_protection_policy.dart';

/// Reusable gate that enforces screen and capture protection policies around protected content.
///
/// Handles:
/// 1. Reference-counted platform window security (Android FLAG_SECURE).
/// 2. Active capture/mirroring detection and non-accusatory content redaction (iOS / macOS / Web).
/// 3. App-switcher and background snapshot obscuration.
class ProtectedContentGate extends ConsumerStatefulWidget {
  const ProtectedContentGate({
    required this.child,
    this.policy = ContentProtectionPolicy.blockCaptureWhereSupported,
    this.onCaptureChanged,
    this.obscureOnBackground = true,
    this.customRedactedWidget,
    super.key,
  });

  /// The protected widget tree (e.g. video player, exam question, protected PDF).
  final Widget child;

  /// The server-authoritative content protection policy.
  final ContentProtectionPolicy policy;

  /// Optional callback invoked when screen capture state changes (e.g. to pause video).
  final ValueChanged<bool>? onCaptureChanged;

  /// Whether to obscure content with a privacy shield in the app switcher when backgrounded.
  final bool obscureOnBackground;

  /// Optional custom widget to display when capture is detected.
  final Widget? customRedactedWidget;

  @override
  ConsumerState<ProtectedContentGate> createState() =>
      _ProtectedContentGateState();
}

class _ProtectedContentGateState extends ConsumerState<ProtectedContentGate>
    with WidgetsBindingObserver {
  bool _isBackgrounded = false;
  ContentProtectionService? _protectionService;
  bool _acquired = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _protectionService = ref.read(contentProtectionServiceProvider.notifier);
    if (!_acquired && widget.policy != ContentProtectionPolicy.none) {
      _acquired = true;
      unawaited(_protectionService!.acquireProtection(widget.policy));
    }
  }

  @override
  void didUpdateWidget(ProtectedContentGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.policy != widget.policy) {
      unawaited(_reconfigure(oldWidget.policy, widget.policy));
    }
  }

  Future<void> _reconfigure(
    ContentProtectionPolicy oldPolicy,
    ContentProtectionPolicy newPolicy,
  ) async {
    final service = _protectionService;
    if (service == null) return;
    if (oldPolicy != ContentProtectionPolicy.none) {
      await service.releaseProtection();
    }
    if (newPolicy != ContentProtectionPolicy.none) {
      await service.acquireProtection(newPolicy);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_acquired && widget.policy != ContentProtectionPolicy.none) {
      unawaited(_protectionService?.releaseProtection());
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.obscureOnBackground) return;

    final shouldObscure =
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden;

    if (_isBackgrounded != shouldObscure && mounted) {
      setState(() => _isBackgrounded = shouldObscure);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.policy == ContentProtectionPolicy.none) {
      return widget.child;
    }

    final captureState = ref.watch(screenCaptureStateProvider);

    // Notify capture changes (e.g. pause playback)
    ref.listen(screenCaptureStateProvider, (previous, next) {
      if (previous?.isCaptured != next.isCaptured) {
        widget.onCaptureChanged?.call(next.isCaptured);
      }
    });

    if (_isBackgrounded && widget.obscureOnBackground) {
      return _AppSwitcherPrivacyShield();
    }

    if (captureState.isCaptured && widget.policy.requiresCaptureRedaction) {
      return widget.customRedactedWidget ?? const _CaptureRedactionView();
    }

    return widget.child;
  }
}

/// Neutral, non-accusatory message shown when screen capture/sharing is active.
class _CaptureRedactionView extends StatelessWidget {
  const _CaptureRedactionView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.large),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.screen_share_outlined,
            size: 56,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: AppSpacing.medium),
          Text(
            'Screen recording or sharing is active',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.small),
          Text(
            'Stop screen capture to continue this protected lesson.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Obscures task/overview thumbnails when the application is backgrounded.
class _AppSwitcherPrivacyShield extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surface,
      child: const Center(
        child: Icon(Icons.lock_outline, size: 48, color: Colors.grey),
      ),
    );
  }
}
