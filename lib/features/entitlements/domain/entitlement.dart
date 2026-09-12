import 'package:learning_platform/features/entitlements/domain/entitlement_source.dart';
import 'package:learning_platform/features/entitlements/domain/entitlement_status.dart';
import 'package:learning_platform/features/entitlements/domain/resource_type.dart';

final class Entitlement {
  const Entitlement({
    required this.id,
    required this.learnerId,
    required this.source,
    required this.status,
    required this.validFrom,
    this.targetType,
    this.targetId,
    this.categoryIds = const {},
    this.validUntil,
    this.metadata = const {},
  });

  final String id;
  final String learnerId;
  final EntitlementSource source;
  final EntitlementStatus status;
  final ResourceType? targetType;
  final String? targetId;
  final Set<String> categoryIds;
  final DateTime validFrom;
  final DateTime? validUntil;
  final Map<String, Object?> metadata;

  bool get isPerpetual => validUntil == null;

  bool isUsableAt(DateTime at) {
    if (!status.isUsable) return false;
    if (at.isBefore(validFrom)) return false;
    if (validUntil != null && !at.isBefore(validUntil!)) return false;
    return true;
  }

  bool isExpiredAt(DateTime at) {
    if (status == EntitlementStatus.expired) return true;
    if (validUntil != null && !at.isBefore(validUntil!)) return true;
    return false;
  }

  bool covers({
    required ResourceType resourceType,
    required String resourceId,
    Set<String>? itemCategoryIds,
    String? courseId,
  }) {
    // If targeted to a specific item
    if (targetId != null) {
      if (targetId == resourceId) {
        return targetType == null || targetType == resourceType;
      }
      // If entitlement is for the parent course and target is a child (module, lesson, quiz, resource, certificate)
      if (targetType == ResourceType.course &&
          courseId != null &&
          targetId == courseId) {
        return true;
      }
      return false;
    }

    // If targeted to specific categories
    if (categoryIds.isNotEmpty) {
      if (itemCategoryIds == null || itemCategoryIds.isEmpty) {
        return false;
      }
      return categoryIds.any(itemCategoryIds.contains);
    }

    // Global / All-access entitlement
    return true;
  }

  Entitlement copyWith({
    String? id,
    String? learnerId,
    EntitlementSource? source,
    EntitlementStatus? status,
    ResourceType? targetType,
    String? targetId,
    Set<String>? categoryIds,
    DateTime? validFrom,
    DateTime? validUntil,
    Map<String, Object?>? metadata,
  }) => Entitlement(
    id: id ?? this.id,
    learnerId: learnerId ?? this.learnerId,
    source: source ?? this.source,
    status: status ?? this.status,
    targetType: targetType ?? this.targetType,
    targetId: targetId ?? this.targetId,
    categoryIds: categoryIds ?? this.categoryIds,
    validFrom: validFrom ?? this.validFrom,
    validUntil: validUntil ?? this.validUntil,
    metadata: metadata ?? this.metadata,
  );
}
