import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_platform/core/theme/app_spacing.dart';
import 'package:learning_platform/core/widgets/content_states.dart';
import 'package:learning_platform/features/profile/application/profile_providers.dart';
import 'package:learning_platform/features/profile/domain/device_session.dart';

class SessionManagementScreen extends ConsumerWidget {
  const SessionManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sessionManagementControllerProvider);
    final notifier = ref.read(sessionManagementControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Devices & Sessions'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: notifier.loadSessions,
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (state.isLoading && state.sessions.isEmpty) {
            return const LoadingView(label: 'Loading active sessions');
          }
          if (state.failure != null && state.sessions.isEmpty) {
            return ErrorView(onAction: notifier.loadSessions);
          }
          if (state.sessions.isEmpty) {
            return const MessageView(
              icon: Icons.devices_outlined,
              title: 'No active sessions',
              message: 'There are no other active sessions for your account.',
            );
          }

          final otherSessionsCount = state.sessions
              .where((s) => !s.isCurrent)
              .length;

          return RefreshIndicator(
            onRefresh: notifier.loadSessions,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.medium),
              children: [
                if (otherSessionsCount > 0) ...[
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.logout),
                    label: Text(
                      'Sign out of $otherSessionsCount other devices',
                    ),
                    onPressed: state.isRevoking
                        ? null
                        : () => _confirmRevokeOthers(context, ref),
                  ),
                  const SizedBox(height: AppSpacing.medium),
                ],
                for (final session in state.sessions)
                  _DeviceSessionCard(session: session),
              ],
            ),
          );
        },
      ),
    );
  }

  void _confirmRevokeOthers(BuildContext context, WidgetRef ref) {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Revoke Other Sessions?'),
          content: const Text(
            'This will immediately sign out all other devices logged into your account.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final success = await ref
                    .read(sessionManagementControllerProvider.notifier)
                    .revokeOtherSessions();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? 'Other sessions revoked successfully.'
                            : 'Failed to revoke other sessions.',
                      ),
                    ),
                  );
                }
              },
              child: const Text('Sign out others'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceSessionCard extends ConsumerWidget {
  const _DeviceSessionCard({required this.session});
  final DeviceSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final platformIcon = switch (session.platform.toLowerCase()) {
      'android' => Icons.android,
      'ios' => Icons.phone_iphone,
      'macos' || 'windows' || 'linux' => Icons.laptop,
      _ => Icons.public,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.small),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: session.isCurrent
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          child: Icon(
            platformIcon,
            color: session.isCurrent
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurfaceVariant,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                session.deviceName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (session.isCurrent)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'THIS DEVICE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade900,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(
          'Last active: ${_formatTimestamp(session.lastActiveAt)} • Signed in: ${_formatDate(session.createdAt)}',
        ),
        trailing: session.isCurrent
            ? null
            : IconButton(
                tooltip: 'Revoke session',
                icon: const Icon(Icons.close),
                onPressed: () => _confirmRevoke(context, ref, session.id),
              ),
      ),
    );
  }

  void _confirmRevoke(BuildContext context, WidgetRef ref, String sessionId) {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Revoke Session?'),
          content: const Text(
            'This device will be immediately signed out of your account.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await ref
                    .read(sessionManagementControllerProvider.notifier)
                    .revokeSession(sessionId);
              },
              child: const Text('Revoke'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 2) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${time.month}/${time.day}';
  }

  String _formatDate(DateTime time) {
    return '${time.month}/${time.day}/${time.year}';
  }
}
