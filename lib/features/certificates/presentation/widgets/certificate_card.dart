import 'package:flutter/material.dart';
import 'package:learning_platform/core/motion/app_motion.dart';
import 'package:learning_platform/core/theme/app_spacing.dart';
import 'package:learning_platform/core/theme/app_tokens.dart';
import 'package:learning_platform/features/certificates/domain/certificate.dart';

class CertificateCard extends StatelessWidget {
  const CertificateCard({
    required this.certificate,
    required this.onTap,
    super.key,
  });

  final Certificate certificate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRevoked = certificate.isRevoked;

    return LearningLift(
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.only(bottom: AppSpacing.medium),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          side: BorderSide(
            color: isRevoked
                ? theme.colorScheme.error
                : theme.colorScheme.outlineVariant,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.medium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.small),
                      decoration: BoxDecoration(
                        color: isRevoked
                            ? theme.colorScheme.errorContainer
                            : AppPalette.sunshine,
                        borderRadius: BorderRadius.circular(AppRadii.small),
                      ),
                      child: Icon(
                        isRevoked
                            ? Icons.warning_amber_rounded
                            : Icons.workspace_premium_outlined,
                        color: isRevoked
                            ? theme.colorScheme.error
                            : AppPalette.ink,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.medium),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            certificate.courseTitle,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Issued on ${certificate.issueDate.year}-${certificate.issueDate.month.toString().padLeft(2, '0')}-${certificate.issueDate.day.toString().padLeft(2, '0')}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isRevoked) const Icon(Icons.chevron_right),
                  ],
                ),
                if (isRevoked)
                  Chip(
                    label: const Text('Revoked'),
                    backgroundColor: theme.colorScheme.errorContainer,
                    labelStyle: TextStyle(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                const Divider(height: AppSpacing.large),
                Wrap(
                  spacing: AppSpacing.medium,
                  runSpacing: AppSpacing.small,
                  children: [
                    Text(
                      'ID: ${certificate.credentialId}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (certificate.grade != null)
                      Text(
                        certificate.grade!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
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
