import 'package:flutter/foundation.dart';
import 'package:learning_platform/core/errors/app_failure.dart';
import 'package:learning_platform/features/notifications/domain/notification_item.dart';

@immutable
final class NotificationState {
  const NotificationState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.items = const [],
    this.unreadCount = 0,
    this.nextCursor,
    this.failure,
  });

  final bool isLoading;
  final bool isLoadingMore;
  final List<NotificationItem> items;
  final int unreadCount;
  final String? nextCursor;
  final AppFailure? failure;

  bool get hasMore => nextCursor != null;

  NotificationState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    List<NotificationItem>? items,
    int? unreadCount,
    String? nextCursor,
    bool clearCursor = false,
    AppFailure? failure,
    bool clearFailure = false,
  }) => NotificationState(
    isLoading: isLoading ?? this.isLoading,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    items: items ?? this.items,
    unreadCount: unreadCount ?? this.unreadCount,
    nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
    failure: clearFailure ? null : (failure ?? this.failure),
  );
}
