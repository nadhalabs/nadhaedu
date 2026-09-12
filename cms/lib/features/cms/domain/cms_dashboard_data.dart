import 'package:flutter/foundation.dart';

@immutable
final class CmsDashboardMetrics {
  const CmsDashboardMetrics({
    required this.totalUsers,
    required this.totalLearners,
    required this.activeLearners,
    required this.totalCourses,
    required this.publishedCourses,
    required this.draftCourses,
    required this.archivedCourses,
    required this.totalEnrollments,
    required this.totalPurchases,
    required this.activeSubscriptions,
    required this.totalCertificatesIssued,
    required this.recentCompletions,
  });

  factory CmsDashboardMetrics.fromJson(Map<String, Object?> json) =>
      CmsDashboardMetrics(
        totalUsers: (json['totalUsers'] as num?)?.toInt() ?? 0,
        totalLearners: (json['totalLearners'] as num?)?.toInt() ?? 0,
        activeLearners: (json['activeLearners'] as num?)?.toInt() ?? 0,
        totalCourses: (json['totalCourses'] as num?)?.toInt() ?? 0,
        publishedCourses: (json['publishedCourses'] as num?)?.toInt() ?? 0,
        draftCourses: (json['draftCourses'] as num?)?.toInt() ?? 0,
        archivedCourses: (json['archivedCourses'] as num?)?.toInt() ?? 0,
        totalEnrollments: (json['totalEnrollments'] as num?)?.toInt() ?? 0,
        totalPurchases: (json['totalPurchases'] as num?)?.toInt() ?? 0,
        activeSubscriptions:
            (json['activeSubscriptions'] as num?)?.toInt() ?? 0,
        totalCertificatesIssued:
            (json['totalCertificatesIssued'] as num?)?.toInt() ?? 0,
        recentCompletions: (json['recentCompletions'] as num?)?.toInt() ?? 0,
      );

  final int totalUsers;
  final int totalLearners;
  final int activeLearners;
  final int totalCourses;
  final int publishedCourses;
  final int draftCourses;
  final int archivedCourses;
  final int totalEnrollments;
  final int totalPurchases;
  final int activeSubscriptions;
  final int totalCertificatesIssued;
  final int recentCompletions;
}

@immutable
final class CmsSystemReadinessWarning {
  const CmsSystemReadinessWarning({required this.code, required this.message});

  factory CmsSystemReadinessWarning.fromJson(Map<String, Object?> json) =>
      CmsSystemReadinessWarning(
        code: json['code'] as String? ?? 'WARNING',
        message: json['message'] as String? ?? '',
      );

  final String code;
  final String message;
}

@immutable
final class CmsSystemReadiness {
  const CmsSystemReadiness({
    required this.database,
    required this.cache,
    required this.migrationRevision,
    required this.isReady,
    required this.warnings,
  });

  factory CmsSystemReadiness.fromJson(Map<String, Object?> json) {
    final warningsList =
        (json['warnings'] as List<dynamic>?)
            ?.map(
              (w) => CmsSystemReadinessWarning.fromJson(
                Map<String, Object?>.from(w as Map),
              ),
            )
            .toList() ??
        const [];

    return CmsSystemReadiness(
      database: json['database'] as String? ?? 'unknown',
      cache: json['cache'] as String? ?? 'unknown',
      migrationRevision: json['migrationRevision'] as String? ?? 'unknown',
      isReady: json['isReady'] as bool? ?? false,
      warnings: warningsList,
    );
  }

  final String database;
  final String cache;
  final String migrationRevision;
  final bool isReady;
  final List<CmsSystemReadinessWarning> warnings;
}

@immutable
final class CmsRecentPurchase {
  const CmsRecentPurchase({
    required this.id,
    required this.orderId,
    required this.learnerId,
    this.learnerEmail,
    required this.productId,
    required this.productType,
    this.amountCents,
    this.currencyCode,
    required this.status,
    required this.purchasedAt,
  });

  factory CmsRecentPurchase.fromJson(Map<String, Object?> json) =>
      CmsRecentPurchase(
        id: json['id'] as String? ?? '',
        orderId: json['orderId'] as String? ?? '',
        learnerId: json['learnerId'] as String? ?? '',
        learnerEmail: json['learnerEmail'] as String?,
        productId: json['productId'] as String? ?? '',
        productType: json['productType'] as String? ?? 'course',
        amountCents: (json['amountCents'] as num?)?.toInt(),
        currencyCode: json['currencyCode'] as String? ?? 'USD',
        status: json['status'] as String? ?? 'completed',
        purchasedAt:
            DateTime.tryParse(json['purchasedAt'] as String? ?? '') ??
            DateTime.now(),
      );

  final String id;
  final String orderId;
  final String learnerId;
  final String? learnerEmail;
  final String productId;
  final String productType;
  final int? amountCents;
  final String? currencyCode;
  final String status;
  final DateTime purchasedAt;

  String get formattedPrice {
    if (amountCents == null) return 'Free';
    final dollars = (amountCents! / 100).toStringAsFixed(2);
    return '\$$dollars';
  }
}

@immutable
final class CmsRecentActivity {
  const CmsRecentActivity({
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
    required this.metadata,
  });

  factory CmsRecentActivity.fromJson(
    Map<String, Object?> json,
  ) => CmsRecentActivity(
    id: json['id'] as String? ?? '',
    actorId: json['actorId'] as String?,
    actorEmail: json['actorEmail'] as String?,
    actorName: json['actorName'] as String?,
    action: json['action'] as String? ?? '',
    targetEntity: json['targetEntity'] as String? ?? '',
    targetId: json['targetId'] as String? ?? '',
    timestamp:
        DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
    result: json['result'] as String? ?? 'success',
    reason: json['reason'] as String?,
    metadata: Map<String, Object?>.from((json['metadata'] as Map?) ?? const {}),
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
  final Map<String, Object?> metadata;
}

@immutable
final class CmsDashboardData {
  const CmsDashboardData({
    required this.metrics,
    required this.recentPurchases,
    required this.recentActivity,
    required this.systemReadiness,
  });

  factory CmsDashboardData.fromJson(Map<String, Object?> json) =>
      CmsDashboardData(
        metrics: CmsDashboardMetrics.fromJson(
          Map<String, Object?>.from(json['metrics'] as Map? ?? const {}),
        ),
        recentPurchases:
            (json['recentPurchases'] as List<dynamic>?)
                ?.map(
                  (p) => CmsRecentPurchase.fromJson(
                    Map<String, Object?>.from(p as Map),
                  ),
                )
                .toList() ??
            const [],
        recentActivity:
            (json['recentActivity'] as List<dynamic>?)
                ?.map(
                  (a) => CmsRecentActivity.fromJson(
                    Map<String, Object?>.from(a as Map),
                  ),
                )
                .toList() ??
            const [],
        systemReadiness: CmsSystemReadiness.fromJson(
          Map<String, Object?>.from(
            json['systemReadiness'] as Map? ?? const {},
          ),
        ),
      );

  final CmsDashboardMetrics metrics;
  final List<CmsRecentPurchase> recentPurchases;
  final List<CmsRecentActivity> recentActivity;
  final CmsSystemReadiness systemReadiness;
}
