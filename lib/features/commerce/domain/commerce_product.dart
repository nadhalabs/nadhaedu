import 'package:flutter/foundation.dart';
import 'package:learning_platform/features/commerce/domain/subscription.dart';

@immutable
final class IntroductoryOffer {
  const IntroductoryOffer({
    required this.id,
    required this.priceCents,
    required this.formattedPrice,
    required this.durationDays,
    this.cyclesCount = 1,
  });

  final String id;
  final int priceCents;
  final String formattedPrice;
  final int durationDays;
  final int cyclesCount;
}

@immutable
final class SubscriptionPlan {
  const SubscriptionPlan({
    required this.id,
    required this.tier,
    required this.billingInterval,
    required this.name,
    required this.description,
    required this.priceCents,
    required this.formattedPrice,
    required this.currencyCode,
    this.trialDays = 0,
    this.introductoryOffer,
    this.benefits = const [],
    this.isPopular = false,
    this.isRecommended = false,
    this.savingsPercent = 0,
    this.storeProductId,
  });

  final String id;
  final SubscriptionTier tier;
  final BillingInterval billingInterval;
  final String name;
  final String description;
  final int priceCents;
  final String formattedPrice;
  final String currencyCode;
  final int trialDays;
  final IntroductoryOffer? introductoryOffer;
  final List<String> benefits;
  final bool isPopular;
  final bool isRecommended;
  final int savingsPercent;
  final String? storeProductId;

  bool get hasTrial => trialDays > 0;
  bool get hasIntroductoryOffer => introductoryOffer != null;
  bool get hasSavings => savingsPercent > 0;
}

@immutable
final class CourseProduct {
  const CourseProduct({
    required this.id,
    required this.courseId,
    required this.title,
    required this.description,
    required this.priceCents,
    required this.formattedPrice,
    required this.currencyCode,
    this.originalPriceCents,
    this.discountPercent = 0,
    this.features = const [],
    this.storeProductId,
  });

  final String id;
  final String courseId;
  final String title;
  final String description;
  final int priceCents;
  final String formattedPrice;
  final String currencyCode;
  final int? originalPriceCents;
  final int discountPercent;
  final List<String> features;
  final String? storeProductId;

  bool get hasDiscount => discountPercent > 0 && originalPriceCents != null;
}

@immutable
final class BundleProduct {
  const BundleProduct({
    required this.id,
    required this.bundleId,
    required this.title,
    required this.description,
    required this.courseIds,
    required this.priceCents,
    required this.formattedPrice,
    required this.currencyCode,
    this.originalPriceCents,
    this.discountPercent = 0,
    this.features = const [],
    this.storeProductId,
  });

  final String id;
  final String bundleId;
  final String title;
  final String description;
  final List<String> courseIds;
  final int priceCents;
  final String formattedPrice;
  final String currencyCode;
  final int? originalPriceCents;
  final int discountPercent;
  final List<String> features;
  final String? storeProductId;

  int get courseCount => courseIds.length;
  bool get hasDiscount => discountPercent > 0 && originalPriceCents != null;
}
