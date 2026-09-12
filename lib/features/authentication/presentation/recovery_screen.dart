import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:learning_platform/core/routing/app_router.dart';
import 'package:learning_platform/core/theme/app_spacing.dart';
import 'package:learning_platform/features/authentication/application/auth_providers.dart';
import 'package:learning_platform/features/authentication/domain/auth_validators.dart';
import 'package:learning_platform/features/authentication/presentation/widgets/auth_feedback.dart';
import 'package:learning_platform/features/authentication/presentation/widgets/auth_scaffold.dart';

class RecoveryScreen extends ConsumerStatefulWidget {
  const RecoveryScreen({this.initialEmail, this.resetToken, super.key});
  final String? initialEmail;
  final String? resetToken;

  @override
  ConsumerState<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends ConsumerState<RecoveryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool get _hasLink => widget.resetToken?.isNotEmpty ?? false;
  @override
  void initState() {
    super.initState();
    _emailController.text = widget.initialEmail ?? '';
    _codeController.text = widget.resetToken ?? '';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final otpEnabled = ref.watch(authCapabilitiesProvider).otp;
    return AuthScaffold(
      title: 'Recover your account',
      subtitle: 'Let’s help you get back to learning.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthFeedback(failure: state.failure),
            if (state.recoveryRequested)
              Semantics(
                liveRegion: true,
                child: const Text(
                  'If this email is registered, check its inbox for a recovery link.',
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: AppSpacing.medium),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email address'),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              validator: AuthValidators.email,
              enabled: !state.isSubmitting,
            ),
            if (_hasLink || state.recoveryRequested && otpEnabled) ...[
              const SizedBox(height: AppSpacing.medium),
              if (!_hasLink)
                TextFormField(
                  controller: _codeController,
                  decoration: const InputDecoration(labelText: '6-digit code'),
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  validator: AuthValidators.otp,
                  enabled: !state.isSubmitting,
                ),
              const SizedBox(height: AppSpacing.medium),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'New password',
                  helperText: 'Use at least 12 characters.',
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword
                        ? 'Show new password'
                        : 'Hide new password',
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                  ),
                ),
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                validator: AuthValidators.password,
                enabled: !state.isSubmitting,
              ),
            ],
            const SizedBox(height: AppSpacing.large),
            ElevatedButton(
              onPressed: state.isSubmitting ? null : _submit,
              child: Text(
                (_hasLink || state.recoveryRequested && otpEnabled)
                    ? 'Reset password'
                    : 'Send recovery email',
              ),
            ),
            const SizedBox(height: AppSpacing.small),
            TextButton(
              onPressed: state.isSubmitting
                  ? null
                  : () => context.go(AppRoutes.login),
              child: const Text('Back to sign in'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final controller = ref.read(authControllerProvider.notifier);
    final state = ref.read(authControllerProvider);
    if (_hasLink ||
        state.recoveryRequested && ref.read(authCapabilitiesProvider).otp) {
      await controller.resetPassword(
        _emailController.text.trim(),
        _codeController.text.trim(),
        _passwordController.text,
      );
    } else {
      await controller.requestRecovery(_emailController.text.trim());
    }
  }
}
