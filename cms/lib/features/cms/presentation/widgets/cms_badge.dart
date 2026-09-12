import 'package:flutter/material.dart';
import 'package:nadha_cms/features/cms/presentation/theme/cms_theme.dart';

enum CmsBadgeType {
  published,
  draft,
  archived,
  unavailable,
  active,
  inactive,
  admin,
  contentManager,
  support,
  learner,
  success,
  warning,
  danger,
  info,
  neutral,
}

class CmsBadge extends StatelessWidget {
  const CmsBadge({
    super.key,
    required this.label,
    this.type = CmsBadgeType.neutral,
    this.icon,
  });

  factory CmsBadge.forStatus(String status) {
    return switch (status.toLowerCase()) {
      'published' || 'completed' || 'issued' => const CmsBadge(
        label: 'Published',
        type: CmsBadgeType.published,
        icon: Icons.check_circle_outline,
      ),
      'draft' || 'pending' || 'trialing' => const CmsBadge(
        label: 'Draft',
        type: CmsBadgeType.draft,
        icon: Icons.edit_note_outlined,
      ),
      'archived' || 'expired' || 'cancelled' => const CmsBadge(
        label: 'Archived',
        type: CmsBadgeType.archived,
        icon: Icons.archive_outlined,
      ),
      'unavailable' || 'revoked' || 'failed' => const CmsBadge(
        label: 'Revoked',
        type: CmsBadgeType.unavailable,
        icon: Icons.cancel_outlined,
      ),
      _ => CmsBadge(label: status.toUpperCase(), type: CmsBadgeType.neutral),
    };
  }

  factory CmsBadge.forRole(String role) {
    return switch (role.toLowerCase()) {
      'admin' => const CmsBadge(
        label: 'Admin',
        type: CmsBadgeType.admin,
        icon: Icons.shield_outlined,
      ),
      'content_manager' => const CmsBadge(
        label: 'Content Manager',
        type: CmsBadgeType.contentManager,
        icon: Icons.auto_stories_outlined,
      ),
      'support' => const CmsBadge(
        label: 'Support',
        type: CmsBadgeType.support,
        icon: Icons.support_agent_outlined,
      ),
      _ => const CmsBadge(
        label: 'Learner',
        type: CmsBadgeType.learner,
        icon: Icons.person_outline,
      ),
    };
  }

  final String label;
  final CmsBadgeType type;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = _getColors(type);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color, Color) _getColors(CmsBadgeType type) {
    return switch (type) {
      CmsBadgeType.published || CmsBadgeType.active || CmsBadgeType.success => (
        CmsTheme.successBg,
        CmsTheme.successText,
        CmsTheme.successColor.withValues(alpha: 0.4),
      ),
      CmsBadgeType.draft || CmsBadgeType.warning => (
        CmsTheme.warningBg,
        CmsTheme.warningText,
        CmsTheme.warningColor.withValues(alpha: 0.4),
      ),
      CmsBadgeType.archived || CmsBadgeType.inactive || CmsBadgeType.neutral =>
        (const Color(0xFF1E293B), CmsTheme.textSecondary, CmsTheme.borderColor),
      CmsBadgeType.unavailable || CmsBadgeType.danger => (
        CmsTheme.dangerBg,
        CmsTheme.dangerText,
        CmsTheme.dangerColor.withValues(alpha: 0.4),
      ),
      CmsBadgeType.admin => (
        const Color(0xFF312E81),
        const Color(0xFFA5B4FC),
        const Color(0xFF6366F1).withValues(alpha: 0.5),
      ),
      CmsBadgeType.contentManager => (
        const Color(0xFF064E3B),
        const Color(0xFF6EE7B7),
        const Color(0xFF10B981).withValues(alpha: 0.5),
      ),
      CmsBadgeType.support => (
        const Color(0xFF0C4A6E),
        const Color(0xFF7DD3FC),
        const Color(0xFF0EA5E9).withValues(alpha: 0.5),
      ),
      CmsBadgeType.learner => (
        const Color(0xFF1E293B),
        CmsTheme.textMuted,
        CmsTheme.borderColor,
      ),
      CmsBadgeType.info => (
        CmsTheme.infoBg,
        CmsTheme.infoText,
        CmsTheme.infoColor.withValues(alpha: 0.4),
      ),
    };
  }
}
