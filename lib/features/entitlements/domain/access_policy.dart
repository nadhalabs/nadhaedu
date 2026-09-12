enum AccessPolicyKind {
  /// Open to all users without requiring an entitlement.
  free,

  /// Requires an active entitlement (subscription, purchase, grant, etc.).
  premium,

  /// Free preview available to all users even if parent container is premium.
  preview,

  /// Inherits policy from parent container (CourseModule inherits from Course, Lesson from CourseModule).
  inherit,

  /// Resource exists but cannot currently be accessed by any entitlement.
  unavailable,
}

final class AccessPolicy {
  const AccessPolicy({
    required this.kind,
    this.requiredTier,
    this.requiredBundleId,
    this.timeLimitDuration,
    this.metadata = const {},
  });

  const AccessPolicy.free() : this(kind: AccessPolicyKind.free);

  const AccessPolicy.premium({String? requiredTier, String? requiredBundleId})
    : this(
        kind: AccessPolicyKind.premium,
        requiredTier: requiredTier,
        requiredBundleId: requiredBundleId,
      );

  const AccessPolicy.preview() : this(kind: AccessPolicyKind.preview);

  const AccessPolicy.inherit() : this(kind: AccessPolicyKind.inherit);

  const AccessPolicy.unavailable() : this(kind: AccessPolicyKind.unavailable);

  final AccessPolicyKind kind;
  final String? requiredTier;
  final String? requiredBundleId;
  final Duration? timeLimitDuration;
  final Map<String, Object?> metadata;

  bool get isFree => kind == AccessPolicyKind.free;
  bool get isPremium => kind == AccessPolicyKind.premium;
  bool get isPreview => kind == AccessPolicyKind.preview;
  bool get isInherited => kind == AccessPolicyKind.inherit;
  bool get isUnavailable => kind == AccessPolicyKind.unavailable;

  /// Resolves the effective access policy by evaluating hierarchy inheritance:
  /// Course Access Policy -> Section/Module Override -> Lesson/Resource Override.
  static AccessPolicy resolve({
    required AccessPolicy coursePolicy,
    AccessPolicy? modulePolicy,
    AccessPolicy? lessonPolicy,
  }) {
    if (lessonPolicy != null && !lessonPolicy.isInherited) {
      return lessonPolicy;
    }
    if (modulePolicy != null && !modulePolicy.isInherited) {
      return modulePolicy;
    }
    return coursePolicy;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccessPolicy &&
          runtimeType == other.runtimeType &&
          kind == other.kind &&
          requiredTier == other.requiredTier &&
          requiredBundleId == other.requiredBundleId &&
          timeLimitDuration == other.timeLimitDuration;

  @override
  int get hashCode =>
      Object.hash(kind, requiredTier, requiredBundleId, timeLimitDuration);
}
