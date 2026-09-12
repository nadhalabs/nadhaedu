import 'dart:convert';
import 'package:learning_platform/core/persistence/key_value_store.dart';
import 'package:learning_platform/features/notifications/domain/notification_item.dart';

final class NotificationCacheStore {
  NotificationCacheStore(this._store, {required this.learnerId});
  final KeyValueStore _store;
  final String learnerId;

  String get _cacheKey => 'notifications_cache_$learnerId';

  Future<List<NotificationItem>> loadCachedNotifications() async {
    final raw = await _store.readString(_cacheKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } on Object {
      return const [];
    }
  }

  Future<void> saveCachedNotifications(List<NotificationItem> items) async {
    // Keep max 50 recent items in offline cache
    final bounded = items.take(50).toList();
    final raw = jsonEncode(bounded.map((e) => e.toJson()).toList());
    await _store.writeString(_cacheKey, raw);
  }

  Future<void> clearCache() async {
    await _store.remove(_cacheKey);
  }
}
