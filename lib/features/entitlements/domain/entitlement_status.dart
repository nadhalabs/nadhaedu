enum EntitlementStatus {
  active,
  expired,
  revoked,
  pending,
  gracePeriod;

  bool get isUsable => this == active || this == gracePeriod;
}
