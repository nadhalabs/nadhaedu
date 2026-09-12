import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_platform/core/routing/app_router.dart';
import 'package:learning_platform/features/notifications/application/notification_providers.dart';

class NotificationBadgeButton extends ConsumerWidget {
  const NotificationBadgeButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationsCountProvider);

    return Semantics(
      label: unreadCount > 0
          ? 'Notifications, $unreadCount unread'
          : 'Notifications, no unread',
      button: true,
      child: IconButton(
        tooltip: 'Notifications',
        icon: Badge(
          isLabelVisible: unreadCount > 0,
          label: Text(unreadCount > 99 ? '99+' : unreadCount.toString()),
          child: const Icon(Icons.notifications_outlined),
        ),
        onPressed: () => context.push(AppRoutes.notifications),
      ),
    );
  }
}
