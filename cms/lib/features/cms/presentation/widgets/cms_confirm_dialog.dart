import 'package:flutter/material.dart';
import 'package:nadha_cms/features/cms/presentation/theme/cms_theme.dart';

class CmsConfirmDialog extends StatefulWidget {
  const CmsConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.isDestructive = false,
    this.requireReason = false,
    this.reasonLabel = 'Reason (Optional)',
    this.reasonHint = 'Provide operational justification...',
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDestructive;
  final bool requireReason;
  final String reasonLabel;
  final String reasonHint;

  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
    bool requireReason = false,
    String reasonLabel = 'Reason (Optional)',
    String reasonHint = 'Provide operational justification...',
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => CmsConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDestructive: isDestructive,
        requireReason: requireReason,
        reasonLabel: reasonLabel,
        reasonHint: reasonHint,
      ),
    );
  }

  @override
  State<CmsConfirmDialog> createState() => _CmsConfirmDialogState();
}

class _CmsConfirmDialogState extends State<CmsConfirmDialog> {
  late final TextEditingController _reasonController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          if (widget.isDestructive) ...[
            const Icon(
              Icons.warning_amber_rounded,
              color: CmsTheme.dangerColor,
              size: 20,
            ),
            const SizedBox(width: 8),
          ],
          Text(
            widget.title,
            style: const TextStyle(
              color: CmsTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.message,
              style: const TextStyle(
                color: CmsTheme.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            ...[
              const SizedBox(height: 16),
              Text(
                widget.reasonLabel,
                style: const TextStyle(
                  color: CmsTheme.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _reasonController,
                maxLines: 2,
                style: const TextStyle(
                  color: CmsTheme.textPrimary,
                  fontSize: 13,
                ),
                decoration: InputDecoration(hintText: widget.reasonHint),
              ),
              if (_error != null) ...[
                const SizedBox(height: 6),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: CmsTheme.dangerText,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(widget.cancelLabel),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.isDestructive
                ? CmsTheme.dangerColor
                : CmsTheme.primaryAccent,
            foregroundColor: widget.isDestructive
                ? Colors.white
                : const Color(0xFF0B0F19),
          ),
          onPressed: () {
            if (widget.requireReason &&
                _reasonController.text.trim().length < 8) {
              setState(
                () => _error = 'A reason of at least 8 characters is required.',
              );
              return;
            }
            Navigator.of(context).pop(_reasonController.text.trim());
          },
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
