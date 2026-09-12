import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_platform/core/theme/app_spacing.dart';
import 'package:learning_platform/core/widgets/content_states.dart';
import 'package:learning_platform/features/certificates/application/certificate_providers.dart';
import 'package:learning_platform/features/certificates/presentation/widgets/certificate_card.dart';

class CertificatesScreen extends ConsumerWidget {
  const CertificatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final certificatesAsync = ref.watch(learnerCertificatesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Certificates')),
      body: certificatesAsync.when(
        loading: () => const LoadingView(label: 'Loading certificates'),
        error: (err, _) => ErrorView(
          onAction: () => ref.invalidate(learnerCertificatesProvider),
        ),
        data: (certificates) {
          if (certificates.isEmpty) {
            return MessageView(
              icon: Icons.workspace_premium_outlined,
              title: 'No Certificates Yet',
              message:
                  'Every discovery starts with a first step. Finish a course and its assessments to earn your certificate.',
              actionLabel: 'Keep learning',
              onAction: () => context.go('/my-learning'),
            );
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSpacing.maxContentWidth,
              ),
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.large),
                children: [
                  Text(
                    'Look what you’ve learned',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.small),
                  Text(
                    'Your completed courses, collected in one place.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.large),
                  for (final cert in certificates)
                    CertificateCard(
                      certificate: cert,
                      onTap: () => context.push('/certificates/${cert.id}'),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
