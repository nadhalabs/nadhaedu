import 'package:flutter/foundation.dart';
import 'package:learning_platform/core/routing/app_destination.dart';

enum NotificationType {
  courseUpdate,
  lessonReminder,
  liveClassReminder,
  learningReminder,
  assessmentResult,
  certificateIssued,
  downloadCompleted,
  paymentEvent,
  subscriptionEvent,
  systemAnnouncement,
  securityEvent;

  static NotificationType fromString(String raw) {
    for (final val in NotificationType.values) {
      if (val.name.toLowerCase() == raw.toLowerCase() ||
          val.toString().split('.').last.toLowerCase() == raw.toLowerCase()) {
        return val;
      }
    }
    return NotificationType.systemAnnouncement;
  }
}

enum NotificationPriority {
  low,
  normal,
  high,
  urgent;

  static NotificationPriority fromString(String raw) {
    for (final val in NotificationPriority.values) {
      if (val.name.toLowerCase() == raw.toLowerCase()) {
        return val;
      }
    }
    return NotificationPriority.normal;
  }
}

@immutable
final class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.destination,
    required this.priority,
    required this.createdAt,
    this.imageUrl,
    this.metadata = const {},
    this.readAt,
    this.expiresAt,
  });

  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final AppDestination destination;
  final NotificationPriority priority;
  final String? imageUrl;
  final Map<String, Object?> metadata;
  final DateTime? readAt;
  final DateTime? expiresAt;
  final DateTime createdAt;

  bool get isRead => readAt != null;

  NotificationItem copyWith({DateTime? readAt}) => NotificationItem(
    id: id,
    type: type,
    title: title,
    body: body,
    destination: destination,
    priority: priority,
    imageUrl: imageUrl,
    metadata: metadata,
    readAt: readAt ?? this.readAt,
    expiresAt: expiresAt,
    createdAt: createdAt,
  );

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    final destinationType = (json['destinationType'] as String?) ?? 'none';
    final payload = (json['destinationPayload'] as Map<String, dynamic>?) ?? {};

    final AppDestination destination = switch (destinationType.toLowerCase()) {
      'course' => AppDestination.course(payload['courseId']?.toString() ?? ''),
      'lesson' => AppDestination.lesson(
        payload['courseId']?.toString() ?? '',
        payload['lessonId']?.toString() ?? '',
      ),
      'certificate' => AppDestination.certificate(
        payload['certificateId']?.toString() ?? '',
      ),
      'assessment' => AppDestination.assessment(
        payload['assessmentId']?.toString() ?? '',
      ),
      'downloads' => const AppDestinationDownloads(),
      'subscription' => const AppDestinationSubscription(),
      'profile' => const AppDestinationProfile(),
      'search' => AppDestination.search(payload['query']?.toString()),
      'notifications' => const AppDestinationNotifications(),
      _ => const AppDestinationNone(),
    };

    return NotificationItem(
      id: json['id'] as String,
      type: NotificationType.fromString(
        (json['type'] as String?) ?? 'systemAnnouncement',
      ),
      title: (json['title'] as String?) ?? '',
      body: (json['body'] as String?) ?? '',
      destination: destination,
      priority: NotificationPriority.fromString(
        (json['priority'] as String?) ?? 'normal',
      ),
      imageUrl: json['imageUrl'] as String?,
      metadata:
          (json['metadata'] as Map<String, dynamic>?)
              ?.cast<String, Object?>() ??
          const {},
      readAt: json['readAt'] != null
          ? DateTime.tryParse(json['readAt'] as String)
          : null,
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'] as String)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'title': title,
    'body': body,
    'destinationType': destination.runtimeType.toString(),
    'destinationLocation': destination.toLocation(),
    'priority': priority.name,
    'imageUrl': imageUrl,
    'metadata': metadata,
    'readAt': readAt?.toIso8601String(),
    'expiresAt': expiresAt?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          readAt == other.readAt;

  @override
  int get hashCode => id.hashCode ^ readAt.hashCode;
}

final class NotificationPage {
  const NotificationPage({
    required this.items,
    required this.unreadCount,
    this.nextCursor,
  });

  final List<NotificationItem> items;
  final int unreadCount;
  final String? nextCursor;

  bool get hasMore => nextCursor != null;
}
