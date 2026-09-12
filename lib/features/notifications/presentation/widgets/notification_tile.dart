import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_platform/core/routing/app_destination.dart';
import 'package:learning_platform/core/theme/app_spacing.dart';
import 'package:learning_platform/features/notifications/application/notification_providers.dart';
import 'package:learning_platform/features/notifications/domain/notification_item.dart';

class NotificationTile extends ConsumerWidget {
  const NotificationTile({required this.item, super.key});

  final NotificationItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final (icon, iconColor) = _getTypeVisuals(item.type, colorScheme);

    return Semantics(
      label:
          '${item.isRead ? "Read" : "Unread"} notification: ${item.title}. ${item.body}',
      button: true,
      child: Material(
        color: item.isRead
            ? Colors.transparent
            : colorScheme.primaryContainer.withValues(alpha: 0.15),
        child: InkWell(
          onTap: () {
            unawaited(
              ref
                  .read(notificationControllerProvider.notifier)
                  .markAsRead(item.id),
            );
            unawaited(
              ref
                  .read(platformAnalyticsProvider)
                  .notificationOpened(
                    notificationId: item.id,
                    type: item.type.name,
                    destinationType: item.destination.runtimeType.toString(),
                  ),
            );
            if (item.destination is! AppDestinationNone) {
              unawaited(context.push(item.destination.toLocation()));
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.medium,
              vertical: AppSpacing.medium,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: AppSpacing.medium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: item.isRead
                                    ? FontWeight.normal
                                    : FontWeight.bold,
                              ),
                            ),
                          ),
                          if (!item.isRead)
                            Container(
                              margin: const EdgeInsets.only(
                                left: AppSpacing.small,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'NEW',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onPrimary,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.body,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatTimestamp(item.createdAt),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  (IconData, Color) _getTypeVisuals(NotificationType type, ColorScheme scheme) {
    return switch (type) {
      NotificationType.courseUpdate => (Icons.school, Colors.blue),
      NotificationType.lessonReminder => (Icons.alarm, Colors.orange),
      NotificationType.liveClassReminder => (Icons.videocam, Colors.redAccent),
      NotificationType.learningReminder => (
        Icons.local_fire_department,
        Colors.amber,
      ),
      NotificationType.assessmentResult => (
        Icons.assignment_turned_in,
        Colors.teal,
      ),
      NotificationType.certificateIssued => (
        Icons.workspace_premium,
        Colors.amber.shade800,
      ),
      NotificationType.downloadCompleted => (Icons.download_done, Colors.green),
      NotificationType.paymentEvent => (Icons.receipt_long, Colors.purple),
      NotificationType.subscriptionEvent => (
        Icons.card_membership,
        Colors.indigo,
      ),
      NotificationType.systemAnnouncement => (Icons.campaign, Colors.blueGrey),
      NotificationType.securityEvent => (Icons.shield, scheme.error),
    };
  }

  String _formatTimestamp(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${time.month}/${time.day}/${time.year}';
  }
}
