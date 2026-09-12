import 'package:flutter/foundation.dart';

@immutable
final class CmsAuditLogItem {
  const CmsAuditLogItem({
    required this.id,
    this.actorId,
    this.actorEmail,
    this.actorName,
    required this.action,
    required this.targetEntity,
    required this.targetId,
    required this.timestamp,
    required this.result,
    this.reason,
    required this.data,
  });

  factory CmsAuditLogItem.fromJson(Map<String, Object?> json) =>
      CmsAuditLogItem(
        id: json['id'] as String? ?? '',
        actorId: json['actorId'] as String?,
        actorEmail: json['actorEmail'] as String?,
        actorName: json['actorName'] as String?,
        action: json['action'] as String? ?? '',
        targetEntity: json['targetEntity'] as String? ?? '',
        targetId: json['targetId'] as String? ?? '',
        timestamp:
            DateTime.tryParse(json['timestamp'] as String? ?? '') ??
            DateTime.now(),
        result: json['result'] as String? ?? 'success',
        reason: json['reason'] as String?,
        data: Map<String, Object?>.from((json['data'] as Map?) ?? const {}),
      );

  final String id;
  final String? actorId;
  final String? actorEmail;
  final String? actorName;
  final String action;
  final String targetEntity;
  final String targetId;
  final DateTime timestamp;
  final String result;
  final String? reason;
  final Map<String, Object?> data;
}
