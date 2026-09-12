import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_platform/core/routing/app_router.dart';
import 'package:learning_platform/core/theme/app_spacing.dart';
import 'package:learning_platform/core/widgets/content_states.dart';
import 'package:learning_platform/features/notifications/application/notification_providers.dart';
import 'package:learning_platform/features/notifications/domain/notification_item.dart';
import 'package:learning_platform/features/notifications/presentation/widgets/notification_tile.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (state.unreadCount > 0)
            TextButton(
              onPressed: () => ref
                  .read(notificationControllerProvider.notifier)
                  .markAllAsRead(),
              child: const Text('Mark all as read'),
            ),
          IconButton(
            tooltip: 'Notification Preferences',
            icon: const Icon(Icons.tune),
            onPressed: () => context.push(AppRoutes.notificationPreferences),
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (state.isLoading && state.items.isEmpty) {
            return const LoadingView(label: 'Loading notifications');
          }
          if (state.failure != null && state.items.isEmpty) {
            return ErrorView(
              onAction: () => ref
                  .read(notificationControllerProvider.notifier)
                  .loadNotifications(refresh: true),
            );
          }
          if (state.items.isEmpty) {
            return const MessageView(
              icon: Icons.notifications_none_outlined,
              title: 'No notifications',
              message:
                  'You are all caught up! Updates and reminders will appear here.',
            );
          }

          final groups = _groupByDate(state.items);

          return RefreshIndicator(
            onRefresh: () => ref
                .read(notificationControllerProvider.notifier)
                .loadNotifications(refresh: true),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: groups.length + (state.hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= groups.length) {
                  if (!state.isLoadingMore) {
                    unawaited(
                      ref
                          .read(notificationControllerProvider.notifier)
                          .loadMore(),
                    );
                  }
                  return const Padding(
                    padding: EdgeInsets.all(AppSpacing.medium),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final group = groups[index];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.medium,
                        AppSpacing.medium,
                        AppSpacing.medium,
                        AppSpacing.small,
                      ),
                      child: Text(
                        group.title,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.medium,
                        vertical: 4,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          for (int i = 0; i < group.items.length; i++) ...[
                            NotificationTile(item: group.items[i]),
                            if (i < group.items.length - 1)
                              const Divider(height: 1, indent: 64),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  List<_NotificationGroup> _groupByDate(List<NotificationItem> items) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final todayItems = <NotificationItem>[];
    final yesterdayItems = <NotificationItem>[];
    final earlierItems = <NotificationItem>[];

    for (final item in items) {
      final itemDate = DateTime(
        item.createdAt.year,
        item.createdAt.month,
        item.createdAt.day,
      );
      if (itemDate == today) {
        todayItems.add(item);
      } else if (itemDate == yesterday) {
        yesterdayItems.add(item);
      } else {
        earlierItems.add(item);
      }
    }

    final result = <_NotificationGroup>[];
    if (todayItems.isNotEmpty) {
      result.add(_NotificationGroup('Today', todayItems));
    }
    if (yesterdayItems.isNotEmpty) {
      result.add(_NotificationGroup('Yesterday', yesterdayItems));
    }
    if (earlierItems.isNotEmpty) {
      result.add(_NotificationGroup('Earlier', earlierItems));
    }
    return result;
  }
}

final class _NotificationGroup {
  const _NotificationGroup(this.title, this.items);
  final String title;
  final List<NotificationItem> items;
}
