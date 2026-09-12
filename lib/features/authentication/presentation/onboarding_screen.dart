import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_platform/core/theme/app_spacing.dart';
import 'package:learning_platform/features/academic/academic_profile.dart';
import 'package:learning_platform/features/academic/academic_profile_screen.dart';
import 'package:learning_platform/features/authentication/application/auth_providers.dart';
import 'package:learning_platform/features/authentication/domain/auth_validators.dart';
import 'package:learning_platform/features/authentication/presentation/widgets/auth_feedback.dart';
import 'package:learning_platform/features/authentication/presentation/widgets/auth_scaffold.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: ref.read(authControllerProvider).session?.identity.displayName,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    return AuthScaffold(
      title: 'Your next discovery starts here',
      subtitle:
          'What should we call you? A first name or nickname is all you need.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthFeedback(failure: state.failure),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Display name'),
              keyboardType: TextInputType.name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.name],
              validator: AuthValidators.displayName,
              enabled: !state.isSubmitting,
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: AppSpacing.large),
            AcademicProfileForm(
              saveLabel: 'Continue',
              validateBeforeSave: () =>
                  _formKey.currentState?.validate() ?? false,
              onSaved: _submit,
            ),
            const SizedBox(height: AppSpacing.small),
            TextButton(
              onPressed: state.isSubmitting
                  ? null
                  : ref.read(authControllerProvider.notifier).signOut,
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (ref.read(academicProfileProvider).valueOrNull == null) return;
    await ref
        .read(authControllerProvider.notifier)
        .completeOnboarding(_nameController.text.trim());
  }
}
