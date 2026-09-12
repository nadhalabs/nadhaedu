import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_platform/core/theme/app_spacing.dart';
import 'package:learning_platform/core/widgets/content_states.dart';
import 'package:learning_platform/features/certificates/application/certificate_providers.dart';
import 'package:learning_platform/features/certificates/domain/certificate.dart';

class CertificateVerificationScreen extends ConsumerWidget {
  const CertificateVerificationScreen({required this.credentialId, super.key});

  final String credentialId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final verificationAsync = ref.watch(
      credentialVerificationProvider(credentialId),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Credential Verification')),
      body: verificationAsync.when(
        loading: () =>
            const LoadingView(label: 'Verifying credential authenticity...'),
        error: (err, _) => ErrorView(
          onAction: () =>
              ref.invalidate(credentialVerificationProvider(credentialId)),
        ),
        data: (info) => _VerificationBody(info: info),
      ),
    );
  }
}

class _VerificationBody extends StatelessWidget {
  const _VerificationBody({required this.info});

  final CertificateVerificationInfo info;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isValid = info.isValid;
    final cert = info.certificate;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.large),
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.large),
              decoration: BoxDecoration(
                color: isValid
                    ? Colors.green.withValues(alpha: 0.15)
                    : theme.colorScheme.errorContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isValid ? Colors.green : theme.colorScheme.error,
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    isValid ? Icons.verified_user : Icons.gpp_bad,
                    size: 64,
                    color: isValid ? Colors.green : theme.colorScheme.error,
                  ),
                  const SizedBox(height: AppSpacing.medium),
                  Semantics(
                    header: true,
                    child: Text(
                      isValid
                          ? 'Valid & Authenticated Credential'
                          : 'Invalid or Revoked Credential',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isValid
                            ? Colors.green.shade800
                            : theme.colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.small),
                  Text(
                    info.message ?? '',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.large),
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHigh,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.medium),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Record Details',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(height: AppSpacing.medium),
                    _RecordRow(
                      label: 'Credential ID',
                      value: info.credentialId,
                    ),
                    if (cert != null) ...[
                      const Divider(height: AppSpacing.medium),
                      _RecordRow(label: 'Recipient', value: cert.learnerName),
                      const Divider(height: AppSpacing.medium),
                      _RecordRow(label: 'Course', value: cert.courseTitle),
                      const Divider(height: AppSpacing.medium),
                      _RecordRow(
                        label: 'Issued Date',
                        value:
                            '${cert.issueDate.year}-${cert.issueDate.month.toString().padLeft(2, '0')}-${cert.issueDate.day.toString().padLeft(2, '0')}',
                      ),
                      const Divider(height: AppSpacing.medium),
                      _RecordRow(
                        label: 'Issuing Institution',
                        value: cert.issuerName,
                      ),
                      const Divider(height: AppSpacing.medium),
                      _RecordRow(
                        label: 'Status',
                        value: switch (cert.status) {
                          CertificateStatus.issued => 'Active / Verified',
                          CertificateStatus.revoked => 'Revoked',
                          CertificateStatus.unavailable => 'Unavailable',
                          CertificateStatus.pendingEligibility => 'Pending',
                        },
                      ),
                    ],
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

class _RecordRow extends StatelessWidget {
  const _RecordRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
