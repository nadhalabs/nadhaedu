import 'package:flutter/foundation.dart';

@immutable
final class DeviceSession {
  const DeviceSession({
    required this.id,
    required this.deviceName,
    required this.platform,
    required this.lastActiveAt,
    required this.createdAt,
    this.isCurrent = false,
  });

  final String id;
  final String deviceName;
  final String platform;
  final DateTime lastActiveAt;
  final DateTime createdAt;
  final bool isCurrent;

  factory DeviceSession.fromJson(Map<String, dynamic> json) => DeviceSession(
    id: json['id'] as String,
    deviceName: (json['deviceName'] as String?) ?? 'Unknown Device',
    platform: (json['platform'] as String?) ?? 'web',
    lastActiveAt: json['lastActiveAt'] != null
        ? DateTime.parse(json['lastActiveAt'] as String)
        : DateTime.now(),
    createdAt: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'] as String)
        : DateTime.now(),
    isCurrent: (json['isCurrent'] as bool?) ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'deviceName': deviceName,
    'platform': platform,
    'lastActiveAt': lastActiveAt.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'isCurrent': isCurrent,
  };
}
