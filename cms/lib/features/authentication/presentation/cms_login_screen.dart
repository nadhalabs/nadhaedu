import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nadha_cms/features/authentication/application/auth_providers.dart';
import 'package:nadha_cms/features/cms/presentation/theme/cms_theme.dart';

class CmsLoginScreen extends ConsumerStatefulWidget {
  const CmsLoginScreen({super.key});
  @override
  ConsumerState<CmsLoginScreen> createState() => _CmsLoginScreenState();
}

class _CmsLoginScreenState extends ConsumerState<CmsLoginScreen> {
  final formKey = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  bool obscure = true;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: CmsTheme.cardColor,
              border: Border.all(color: CmsTheme.borderColor),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.admin_panel_settings,
                    color: CmsTheme.primaryAccent,
                    size: 42,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'NADHA EDU',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'CMS • Sign in with an authorized staff account.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: CmsTheme.textSecondary),
                  ),
                  if (state.failure != null) ...[
                    const SizedBox(height: 20),
                    Text(
                      state.failure!.message,
                      style: const TextStyle(color: CmsTheme.dangerText),
                    ),
                  ],
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: email,
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                    ),
                    autofillHints: const [AutofillHints.username],
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter your email address.'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: password,
                    obscureText: obscure,
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: 'Password',
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => obscure = !obscure),
                        icon: Icon(
                          obscure ? Icons.visibility : Icons.visibility_off,
                        ),
                      ),
                    ),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Enter your password.'
                        : null,
                    onFieldSubmitted: (_) => submit(),
                  ),
                  const SizedBox(height: 22),
                  ElevatedButton(
                    onPressed: state.isSubmitting ? null : submit,
                    child: state.isSubmitting
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Sign in'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> submit() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    await ref
        .read(authControllerProvider.notifier)
        .signIn(email.text.trim(), password.text);
  }
}
