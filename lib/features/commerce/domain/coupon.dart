import 'dart:math' as math;
import 'package:flutter/foundation.dart';

enum DiscountType {
  percentage,
  fixedAmount;

  String get displayName => switch (this) {
    DiscountType.percentage => 'Percentage Discount',
    DiscountType.fixedAmount => 'Fixed Amount Discount',
  };
}

@immutable
final class Coupon {
  const Coupon({
    required this.code,
    required this.discountType,
    required this.discountValue,
    this.validUntil,
    this.applicableProductIds = const {},
    this.description,
  });

  final String code;
  final DiscountType discountType;
  final int discountValue; // e.g. 20 for 20% or 1000 for $10.00
  final DateTime? validUntil;
  final Set<String> applicableProductIds;
  final String? description;

  bool isUsableAt(DateTime now, {String? productId}) {
    if (validUntil != null && now.isAfter(validUntil!)) {
      return false;
    }
    if (productId != null &&
        applicableProductIds.isNotEmpty &&
        !applicableProductIds.contains(productId)) {
      return false;
    }
    return true;
  }

  int calculateDiscountedPrice(int originalPriceCents) {
    if (originalPriceCents <= 0) return 0;
    return switch (discountType) {
      DiscountType.percentage => math.max(
        0,
        (originalPriceCents * (100 - discountValue) / 100).round(),
      ),
      DiscountType.fixedAmount => math.max(
        0,
        originalPriceCents - discountValue,
      ),
    };
  }

  int calculateSavings(int originalPriceCents) {
    return originalPriceCents - calculateDiscountedPrice(originalPriceCents);
  }
}
