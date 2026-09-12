enum CmsRole {
  superAdmin('super_admin', 'Super Administrator'),
  admin('admin', 'Administrator'),
  contentManager('content_manager', 'Content Manager'),
  support('support', 'Support Staff'),
  learner('learner', 'Learner');

  const CmsRole(this.value, this.label);

  final String value;
  final String label;

  static CmsRole fromValue(String value) {
    for (final role in CmsRole.values) {
      if (role.value == value) return role;
    }
    return CmsRole.learner;
  }

  bool get isStaff =>
      this == CmsRole.admin ||
      this == CmsRole.superAdmin ||
      this == CmsRole.contentManager ||
      this == CmsRole.support;

  bool get canManageContent =>
      this == CmsRole.superAdmin ||
      this == CmsRole.admin ||
      this == CmsRole.contentManager;

  bool get canManageUsers =>
      this == CmsRole.superAdmin ||
      this == CmsRole.admin ||
      this == CmsRole.support;

  bool get canViewAuditLogs =>
      this == CmsRole.superAdmin ||
      this == CmsRole.admin ||
      this == CmsRole.support;

  bool get canReconcileCommerce =>
      this == CmsRole.superAdmin || this == CmsRole.admin;
}
