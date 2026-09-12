import 'package:flutter_test/flutter_test.dart';
import 'package:learning_platform/core/routing/app_destination.dart';
import 'package:learning_platform/features/notifications/data/notification_cache_store.dart';
import 'package:learning_platform/features/notifications/domain/notification_item.dart';

import '../../../helpers/memory_key_value_store.dart';

void main() {
  group('NotificationCacheStore', () {
    late MemoryKeyValueStore memoryStore;
    late NotificationCacheStore cacheStore;

    setUp(() {
      memoryStore = MemoryKeyValueStore();
      cacheStore = NotificationCacheStore(
        memoryStore,
        learnerId: 'learner_123',
      );
    });

    test('returns empty list when cache is empty', () async {
      final items = await cacheStore.loadCachedNotifications();
      expect(items, isEmpty);
    });

    test(
      'saves and loads cached notifications with learner isolation',
      () async {
        final items = [
          NotificationItem(
            id: 'notif_1',
            type: NotificationType.courseUpdate,
            title: 'Course Updated',
            body: 'New lesson available.',
            destination: const AppDestinationCourse('course_1'),
            priority: NotificationPriority.normal,
            createdAt: DateTime.utc(2026, 1, 1),
          ),
        ];

        await cacheStore.saveCachedNotifications(items);
        final loaded = await cacheStore.loadCachedNotifications();

        expect(loaded.length, 1);
        expect(loaded.first.id, 'notif_1');
        expect(loaded.first.title, 'Course Updated');

        // Learner isolation check
        final otherStore = NotificationCacheStore(
          memoryStore,
          learnerId: 'learner_456',
        );
        final otherItems = await otherStore.loadCachedNotifications();
        expect(otherItems, isEmpty);
      },
    );

    test('clears cache for learner', () async {
      final items = [
        NotificationItem(
          id: 'notif_1',
          type: NotificationType.courseUpdate,
          title: 'Course Updated',
          body: 'New lesson available.',
          destination: const AppDestinationCourse('course_1'),
          priority: NotificationPriority.normal,
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      ];

      await cacheStore.saveCachedNotifications(items);
      await cacheStore.clearCache();

      final loaded = await cacheStore.loadCachedNotifications();
      expect(loaded, isEmpty);
    });
  });
}
