import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nadha_cms/features/authentication/application/auth_providers.dart';
import 'package:nadha_cms/features/cms/presentation/theme/cms_theme.dart';

class CmsUnauthorizedScreen extends ConsumerWidget {
  const CmsUnauthorizedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).session?.identity;

    return Theme(
      data: CmsTheme.darkTheme,
      child: Scaffold(
        backgroundColor: CmsTheme.canvasColor,
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: CmsTheme.cardColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: CmsTheme.dangerColor.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: CmsTheme.dangerBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_person_outlined,
                    color: CmsTheme.dangerText,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Access Restricted',
                  style: TextStyle(
                    color: CmsTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your current account (${user?.email ?? "learner"}) does not possess administrative or staff privileges required to access the CMS operations portal.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: CmsTheme.textSecondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        await ref
                            .read(authControllerProvider.notifier)
                            .signOut();
                        if (!context.mounted) return;
                        context.go('/sign-in');
                      },
                      icon: const Icon(Icons.switch_account_outlined, size: 16),
                      label: const Text('Sign In as Admin'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
