import 'package:flutter_test/flutter_test.dart';
import 'package:nadha_cms/features/authentication/domain/learner_identity.dart';
import 'package:nadha_cms/features/cms/domain/cms_role.dart';

void main() {
  group('CmsRole & LearnerIdentity Permissions Tests', () {
    test('CmsRole correctly classifies staff and specific permissions', () {
      expect(CmsRole.superAdmin.isStaff, isTrue);
      expect(CmsRole.superAdmin.canManageContent, isTrue);
      expect(CmsRole.superAdmin.canManageUsers, isTrue);
      expect(CmsRole.superAdmin.canViewAuditLogs, isTrue);
      expect(CmsRole.superAdmin.canReconcileCommerce, isTrue);
      expect(CmsRole.admin.isStaff, isTrue);
      expect(CmsRole.admin.canManageContent, isTrue);
      expect(CmsRole.admin.canManageUsers, isTrue);
      expect(CmsRole.admin.canViewAuditLogs, isTrue);
      expect(CmsRole.admin.canReconcileCommerce, isTrue);

      expect(CmsRole.contentManager.isStaff, isTrue);
      expect(CmsRole.contentManager.canManageContent, isTrue);
      expect(CmsRole.contentManager.canManageUsers, isFalse);
      expect(CmsRole.contentManager.canViewAuditLogs, isFalse);
      expect(CmsRole.contentManager.canReconcileCommerce, isFalse);

      expect(CmsRole.support.isStaff, isTrue);
      expect(CmsRole.support.canManageContent, isFalse);
      expect(CmsRole.support.canManageUsers, isTrue);
      expect(CmsRole.support.canViewAuditLogs, isTrue);
      expect(CmsRole.support.canReconcileCommerce, isFalse);

      expect(CmsRole.learner.isStaff, isFalse);
      expect(CmsRole.learner.canManageContent, isFalse);
      expect(CmsRole.learner.canManageUsers, isFalse);
      expect(CmsRole.learner.canViewAuditLogs, isFalse);
      expect(CmsRole.learner.canReconcileCommerce, isFalse);
    });

    test('LearnerIdentity helper getters reflect assigned role', () {
      const ownerIdentity = LearnerIdentity(
        id: 'u-owner',
        email: 'owner@example.com',
        displayName: 'Owner',
        hasCompletedOnboarding: true,
        role: 'super_admin',
      );
      expect(ownerIdentity.isCmsUser, isTrue);
      expect(ownerIdentity.isSuperAdmin, isTrue);
      expect(ownerIdentity.isAdmin, isTrue);
      const adminIdentity = LearnerIdentity(
        id: 'u-admin',
        email: 'admin@example.com',
        displayName: 'Admin User',
        hasCompletedOnboarding: true,
        role: 'admin',
      );
      expect(adminIdentity.isCmsUser, isTrue);
      expect(adminIdentity.isAdmin, isTrue);
      expect(adminIdentity.isContentManager, isFalse);
      expect(adminIdentity.isSupport, isFalse);

      const cmIdentity = LearnerIdentity(
        id: 'u-cm',
        email: 'cm@example.com',
        displayName: 'CM User',
        hasCompletedOnboarding: true,
        role: 'content_manager',
      );
      expect(cmIdentity.isCmsUser, isTrue);
      expect(cmIdentity.isAdmin, isFalse);
      expect(cmIdentity.isContentManager, isTrue);
      expect(cmIdentity.isSupport, isFalse);

      const supIdentity = LearnerIdentity(
        id: 'u-sup',
        email: 'sup@example.com',
        displayName: 'Support User',
        hasCompletedOnboarding: true,
        role: 'support',
      );
      expect(supIdentity.isCmsUser, isTrue);
      expect(supIdentity.isAdmin, isFalse);
      expect(supIdentity.isContentManager, isFalse);
      expect(supIdentity.isSupport, isTrue);

      const learnerIdentity = LearnerIdentity(
        id: 'u-learner',
        email: 'learner@example.com',
        displayName: 'Student User',
        hasCompletedOnboarding: true,
        role: 'learner',
      );
      expect(learnerIdentity.isCmsUser, isFalse);
      expect(learnerIdentity.isAdmin, isFalse);
      expect(learnerIdentity.isContentManager, isFalse);
      expect(learnerIdentity.isSupport, isFalse);
    });
  });
}
