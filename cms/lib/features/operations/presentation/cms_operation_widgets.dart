import 'package:flutter/material.dart';
import 'package:nadha_cms/features/cms/presentation/theme/cms_theme.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_card.dart';

List<Map<String, Object?>> operationItems(
  Map<String, Object?> data, [
  String key = 'items',
]) => (data[key] as List? ?? const [])
    .map((item) => Map<String, Object?>.from(item as Map))
    .toList();

class OperationFilters extends StatelessWidget {
  const OperationFilters({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) =>
      CmsCard(child: Wrap(spacing: 12, runSpacing: 12, children: children));
}

class OperationField extends StatelessWidget {
  const OperationField({
    super.key,
    required this.controller,
    required this.label,
    this.width = 260,
    this.onSubmitted,
  });
  final TextEditingController controller;
  final String label;
  final double width;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: TextField(
      controller: controller,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(labelText: label, isDense: true),
    ),
  );
}

class OperationSelect extends StatelessWidget {
  const OperationSelect({
    super.key,
    required this.value,
    required this.label,
    required this.values,
    required this.onChanged,
    this.width = 190,
  });
  final String value;
  final String label;
  final List<String> values;
  final ValueChanged<String?> onChanged;
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, isDense: true),
      items: values
          .map(
            (item) => DropdownMenuItem(
              value: item,
              child: Text(item.isEmpty ? 'All' : operationLabel(item)),
            ),
          )
          .toList(),
      onChanged: onChanged,
    ),
  );
}

class OperationRecord extends StatelessWidget {
  const OperationRecord({
    super.key,
    required this.item,
    this.actions = const [],
    this.onTap,
  });
  final Map<String, Object?> item;
  final List<Widget> actions;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Wrap(
                spacing: 22,
                runSpacing: 10,
                children: item.entries
                    .map(
                      (entry) => SizedBox(
                        width: 190,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              operationLabel(entry.key),
                              style: const TextStyle(
                                color: CmsTheme.textMuted,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${entry.value ?? '—'}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: CmsTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            if (actions.isNotEmpty)
              Wrap(spacing: 6, runSpacing: 6, children: actions),
          ],
        ),
      ),
    ),
  );
}

class OperationPagination extends StatelessWidget {
  const OperationPagination({
    super.key,
    required this.canPrevious,
    required this.canNext,
    required this.onPrevious,
    required this.onNext,
    this.label,
  });
  final bool canPrevious;
  final bool canNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final String? label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      if (label != null)
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Text(
            label!,
            style: const TextStyle(color: CmsTheme.textMuted),
          ),
        ),
      OutlinedButton.icon(
        onPressed: canPrevious ? onPrevious : null,
        icon: const Icon(Icons.chevron_left),
        label: const Text('Previous'),
      ),
      const SizedBox(width: 8),
      OutlinedButton.icon(
        onPressed: canNext ? onNext : null,
        icon: const Icon(Icons.chevron_right),
        label: const Text('Next'),
      ),
    ],
  );
}

String operationLabel(String value) => value
    .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
    .replaceAll('_', ' ')
    .trim()
    .split(' ')
    .map(
      (part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}',
    )
    .join(' ');
