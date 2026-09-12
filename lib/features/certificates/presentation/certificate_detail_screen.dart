import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_platform/core/theme/app_spacing.dart';
import 'package:learning_platform/core/theme/app_tokens.dart';
import 'package:learning_platform/core/widgets/content_states.dart';
import 'package:learning_platform/core/widgets/learning_feedback.dart';
import 'package:learning_platform/features/certificates/application/certificate_providers.dart';
import 'package:learning_platform/features/certificates/domain/certificate.dart';

class CertificateDetailScreen extends ConsumerWidget {
  const CertificateDetailScreen({required this.certificateId, super.key});

  final String certificateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final certAsync = ref.watch(certificateDetailProvider(certificateId));

    return Scaffold(
      appBar: AppBar(title: const Text('Certificate Details')),
      body: certAsync.when(
        loading: () => const LoadingView(label: 'Loading certificate'),
        error: (err, _) => ErrorView(
          onAction: () =>
              ref.invalidate(certificateDetailProvider(certificateId)),
        ),
        data: (cert) => _CertificateDetailBody(cert: cert),
      ),
    );
  }
}

class _CertificateDetailBody extends StatelessWidget {
  const _CertificateDetailBody({required this.cert});

  final Certificate cert;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRevoked = cert.isRevoked;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.large),
          children: [
            if (!isRevoked) ...[
              const LearningCelebration(
                title: 'You earned this.',
                message:
                    'A little curiosity, a lot of learning. This achievement is yours.',
                icon: Icons.workspace_premium_outlined,
              ),
              const SizedBox(height: AppSpacing.large),
            ],
            if (isRevoked) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.medium),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(AppRadii.small),
                  border: Border.all(color: theme.colorScheme.error),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: theme.colorScheme.error),
                    const SizedBox(width: AppSpacing.medium),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Certificate Revoked',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.error,
                            ),
                          ),
                          if (cert.revocationReason != null)
                            Text(
                              cert.revocationReason!,
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.colorScheme.onErrorContainer,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.large),
            ],
            // Certificate Canvas Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.large),
                side: BorderSide(
                  color: isRevoked
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.xLarge),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadii.large),
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.surface,
                      theme.colorScheme.surfaceContainerLowest,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.workspace_premium,
                      size: 56,
                      color: isRevoked
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                    ),
                    const SizedBox(height: AppSpacing.medium),
                    Text(
                      'CERTIFICATE OF COMPLETION',
                      style: theme.textTheme.titleMedium?.copyWith(
                        letterSpacing: 2,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.medium),
                    Text(
                      'This is proudly presented to',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.small),
                    Text(
                      cert.learnerName,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.medium),
                    Text(
                      'for successfully completing all curriculum requirements and passing assessments for',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.small),
                    Text(
                      cert.courseTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (cert.grade != null) ...[
                      const SizedBox(height: AppSpacing.small),
                      Chip(
                        label: Text(cert.grade!),
                        backgroundColor: theme.colorScheme.primaryContainer,
                      ),
                    ],
                    const Divider(height: AppSpacing.xLarge),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Date Issued',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                '${cert.issueDate.year}-${cert.issueDate.month.toString().padLeft(2, '0')}-${cert.issueDate.day.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.medium),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Issuing Body',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                cert.issuerName,
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.large),
            // Verification Card
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHigh,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.medium),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Official Credential Verification',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.small),
                    Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            'Identifier: ${cert.credentialId}',
                            style: const TextStyle(fontFamily: 'monospace'),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 20),
                          tooltip: 'Copy credential ID',
                          onPressed: () {
                            unawaited(
                              Clipboard.setData(
                                ClipboardData(text: cert.credentialId),
                              ),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Credential ID copied to clipboard.',
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.small),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.verified_outlined),
                        label: const Text('Verify Credential Online'),
                        onPressed: () =>
                            context.push('/verify/${cert.credentialId}'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
