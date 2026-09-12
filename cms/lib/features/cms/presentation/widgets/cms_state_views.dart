import 'package:flutter/material.dart';
import 'package:nadha_cms/features/cms/presentation/theme/cms_theme.dart';

class CmsLoadingView extends StatelessWidget {
  const CmsLoadingView({
    super.key,
    this.message = 'Loading operational data...',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: CmsTheme.primaryAccent,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(color: CmsTheme.textMuted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class CmsErrorView extends StatelessWidget {
  const CmsErrorView({
    super.key,
    required this.message,
    this.onRetry,
    this.title = 'Unable to Load Data',
  });

  final String message;
  final VoidCallback? onRetry;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: CmsTheme.cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: CmsTheme.dangerColor.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CmsTheme.dangerBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                color: CmsTheme.dangerText,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: CmsTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: CmsTheme.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry Request'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class CmsEmptyView extends StatelessWidget {
  const CmsEmptyView({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String title;
  final String? message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: CmsTheme.textMuted),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: CmsTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: CmsTheme.textMuted, fontSize: 13),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
