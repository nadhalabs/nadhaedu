import 'package:learning_platform/core/routing/app_destination.dart';
import 'package:learning_platform/features/notifications/data/notification_data_source.dart';
import 'package:learning_platform/features/notifications/domain/notification_item.dart';
import 'package:learning_platform/features/notifications/domain/notification_preferences.dart';

final class FoundationNotificationDataSource implements NotificationDataSource {
  FoundationNotificationDataSource({List<NotificationItem>? initialItems})
    : _items = initialItems ?? _defaultFixtures();

  final List<NotificationItem> _items;
  NotificationPreferences _preferences = const NotificationPreferences();
  final Set<String> _registeredTokens = {};

  static List<NotificationItem> _defaultFixtures() {
    final now = DateTime.now();
    return [
      NotificationItem(
        id: 'notif-1',
        type: NotificationType.courseUpdate,
        title: 'New Lessons Available',
        body:
            'New interactive lessons were added to Advanced Flutter Architecture.',
        destination: AppDestination.course('course-1'),
        priority: NotificationPriority.normal,
        createdAt: now.subtract(const Duration(minutes: 25)),
      ),
      NotificationItem(
        id: 'notif-2',
        type: NotificationType.certificateIssued,
        title: 'Certificate Issued!',
        body: 'Your certificate for Flutter Foundations has been generated.',
        destination: AppDestination.certificate('cert-1'),
        priority: NotificationPriority.high,
        createdAt: now.subtract(const Duration(hours: 4)),
      ),
      NotificationItem(
        id: 'notif-3',
        type: NotificationType.learningReminder,
        title: 'Daily Streak Goal',
        body:
            'Keep up the momentum! You are 1 lesson away from achieving your weekly goal.',
        destination: AppDestination.myLearning,
        priority: NotificationPriority.normal,
        readAt: now.subtract(const Duration(days: 1)),
        createdAt: now.subtract(const Duration(days: 1, hours: 2)),
      ),
      NotificationItem(
        id: 'notif-4',
        type: NotificationType.paymentEvent,
        title: 'Subscription Active',
        body: 'Your Annual Pro learning plan is now active.',
        destination: AppDestination.subscription,
        priority: NotificationPriority.normal,
        readAt: now.subtract(const Duration(days: 3)),
        createdAt: now.subtract(const Duration(days: 3)),
      ),
    ];
  }

  @override
  Future<NotificationPage> getNotifications({
    String? cursor,
    int limit = 20,
    bool unreadOnly = false,
  }) async {
    var filtered = List<NotificationItem>.from(_items);
    if (unreadOnly) {
      filtered = filtered.where((n) => !n.isRead).toList();
    }
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final offset = int.tryParse(cursor ?? '0') ?? 0;
    final end = (offset + limit).clamp(0, filtered.length);
    final paged = offset < filtered.length
        ? filtered.sublist(offset, end)
        : <NotificationItem>[];
    final unreadCount = _items.where((n) => !n.isRead).length;
    final nextCursor = end < filtered.length ? end.toString() : null;

    return NotificationPage(
      items: paged,
      unreadCount: unreadCount,
      nextCursor: nextCursor,
    );
  }

  @override
  Future<NotificationItem> markAsRead(String notificationId) async {
    final index = _items.indexWhere((n) => n.id == notificationId);
    if (index >= 0) {
      final updated = _items[index].copyWith(readAt: DateTime.now());
      _items[index] = updated;
      return updated;
    }
    throw Exception('Notification not found');
  }

  @override
  Future<int> markAllAsRead() async {
    final now = DateTime.now();
    var count = 0;
    for (var i = 0; i < _items.length; i++) {
      if (!_items[i].isRead) {
        _items[i] = _items[i].copyWith(readAt: now);
        count++;
      }
    }
    return count;
  }

  @override
  Future<NotificationPreferences> getPreferences() async => _preferences;

  @override
  Future<NotificationPreferences> updatePreferences(
    NotificationPreferences preferences,
  ) async {
    _preferences = preferences;
    return _preferences;
  }

  @override
  Future<void> registerPushToken(
    String token,
    String platform, {
    String? deviceName,
  }) async {
    _registeredTokens.add(token);
  }

  @override
  Future<void> revokePushToken(String token) async {
    _registeredTokens.remove(token);
  }
}
