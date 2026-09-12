import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_platform/core/analytics/platform_analytics.dart';
import 'package:learning_platform/core/errors/result.dart';
import 'package:learning_platform/features/notifications/application/notification_state.dart';
import 'package:learning_platform/features/notifications/domain/notification_item.dart';
import 'package:learning_platform/features/notifications/domain/notification_repository.dart';

final class NotificationController extends StateNotifier<NotificationState> {
  NotificationController(this._repository, {PlatformAnalytics? analytics})
    : _analytics = analytics,
      super(const NotificationState()) {
    unawaited(loadNotifications());
  }

  final NotificationRepository _repository;
  final PlatformAnalytics? _analytics;

  Future<void> loadNotifications({bool refresh = false}) async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, clearFailure: true);

    final result = await _repository.getNotifications(limit: 20);
    switch (result) {
      case Success(value: final page):
        state = state.copyWith(
          isLoading: false,
          items: page.items,
          unreadCount: page.unreadCount,
          nextCursor: page.nextCursor,
          clearCursor: page.nextCursor == null,
        );
      case Failure(failure: final failure):
        state = state.copyWith(isLoading: false, failure: failure);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.nextCursor == null) {
      return;
    }
    state = state.copyWith(isLoadingMore: true);

    final result = await _repository.getNotifications(
      cursor: state.nextCursor,
      limit: 20,
    );
    switch (result) {
      case Success(value: final page):
        final combined = [...state.items, ...page.items];
        state = state.copyWith(
          isLoadingMore: false,
          items: combined,
          unreadCount: page.unreadCount,
          nextCursor: page.nextCursor,
          clearCursor: page.nextCursor == null,
        );
      case Failure(failure: final failure):
        state = state.copyWith(isLoadingMore: false, failure: failure);
    }
  }

  Future<void> markAsRead(String notificationId) async {
    final current = state.items;
    final index = current.indexWhere((n) => n.id == notificationId);
    if (index >= 0 && !current[index].isRead) {
      final updatedList = List<NotificationItem>.from(current);
      updatedList[index] = current[index].copyWith(readAt: DateTime.now());
      final newUnread = (state.unreadCount - 1).clamp(0, 9999);
      state = state.copyWith(items: updatedList, unreadCount: newUnread);

      unawaited(
        _analytics?.notificationMarkedRead(
              notificationId: notificationId,
              isBulk: false,
            ) ??
            Future.value(),
      );
      await _repository.markAsRead(notificationId);
    }
  }

  Future<void> markAllAsRead() async {
    if (state.unreadCount == 0) return;
    final now = DateTime.now();
    final updatedList = state.items
        .map((n) => n.isRead ? n : n.copyWith(readAt: now))
        .toList();
    state = state.copyWith(items: updatedList, unreadCount: 0);

    unawaited(
      _analytics?.notificationMarkedRead(notificationId: 'all', isBulk: true) ??
          Future.value(),
    );
    await _repository.markAllAsRead();
  }

  void addIncomingNotification(NotificationItem item) {
    unawaited(
      _analytics?.notificationReceived(
            notificationId: item.id,
            type: item.type.name,
            priority: item.priority.name,
          ) ??
          Future.value(),
    );
    final updated = [item, ...state.items];
    final unread = item.isRead ? state.unreadCount : state.unreadCount + 1;
    state = state.copyWith(items: updated, unreadCount: unread);
  }
}
